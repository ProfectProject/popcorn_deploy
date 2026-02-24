# Karpenter 설치 및 설정 가이드

## 개요

Karpenter는 Kubernetes 클러스터의 자동 스케일링을 담당하는 오픈소스 프로젝트입니다.
기본 노드(t3.large 3개)는 시스템 워크로드용으로 고정하고, 애플리케이션 워크로드는 Karpenter가 Spot 인스턴스로 자동 프로비저닝합니다.

## 아키텍처

```
┌─────────────────────────────────────────────────────────┐
│ EKS 클러스터: goorm-popcorn-prod                          │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ [기본 노드 그룹] (고정)                                      │ 
│ ├─ t3.large × 3 (ON_DEMAND)                             │
│ ├─ 용도: 시스템 워크로드                                     │
│ │   ├─ CoreDNS                                          │
│ │   ├─ AWS Load Balancer Controller                     │
│ │   ├─ Karpenter                                        │
│ │   ├─ ArgoCD                                           │
│ │   └─ 기타 인프라 서비스                                   │
│ └─ 총 리소스: 6 vCPU, 24GB 메모리                           │
│                                                         │
│ [Karpenter 관리 노드] (동적)                               │
│ ├─ t3.medium/large/xlarge (SPOT 우선)                    │
│ ├─ 용도: 애플리케이션 워크로드                                 │
│ │   ├─ Gateway                                          │
│ │   ├─ Users, Stores, Order                             │
│ │   ├─ Payment, CheckIns                                │
│ │   └─ OrderQuery                                       │
│ └─ 자동 스케일링: 0 ~ 20 vCPU                              │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## 사전 요구사항

1. **Terraform으로 인프라 배포 완료**
   - EKS 클러스터 생성
   - Karpenter IAM 역할 생성
   - SQS 큐 및 EventBridge 규칙 생성

2. **kubectl 설정**
   ```bash
   aws eks update-kubeconfig --name goorm-popcorn-prod --region ap-northeast-2
   ```

3. **Helm 설치 확인**
   ```bash
   helm version
   ```

## 설치 순서

### 1단계: Terraform 적용

```bash
cd popcorn-terraform-feature/envs/prod

# 변경사항 확인
terraform plan

# 적용
terraform apply

# 출력 확인
terraform output
```

**예상 변경사항**:
- EKS 노드 그룹: t3.medium → t3.large
- Karpenter Helm 차트 설치
- Karpenter IAM 역할 생성
- SQS 큐 생성
- EventBridge 규칙 생성

### 2단계: Karpenter 설치 확인

```bash
# Karpenter Pod 확인
kubectl get pods -n karpenter

# 예상 출력:
# NAME                         READY   STATUS    RESTARTS   AGE
# karpenter-5d8f9c7b6d-xxxxx   1/1     Running   0          2m
# karpenter-5d8f9c7b6d-yyyyy   1/1     Running   0          2m

# Karpenter 로그 확인
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter -f
```

### 3단계: NodePool 및 EC2NodeClass 배포

```bash
cd popcorn_deploy/infrastructure/karpenter

# EC2NodeClass 배포
kubectl apply -f ec2nodeclass.yaml

# NodePool 배포
kubectl apply -f nodepool.yaml

# 확인
kubectl get nodepool
kubectl get ec2nodeclass
```

### 4단계: 테스트 배포

```bash
# 테스트 Deployment 생성
kubectl create deployment test-karpenter \
  --image=nginx:latest \
  --replicas=5 \
  -n default

# Pod 스케줄링 확인
kubectl get pods -n default -w

# 새 노드 생성 확인 (1-2분 소요)
kubectl get nodes -w

# Karpenter 이벤트 확인
kubectl get events -n karpenter --sort-by='.lastTimestamp'
```

### 5단계: 정리

```bash
# 테스트 Deployment 삭제
kubectl delete deployment test-karpenter -n default

# 노드 자동 축소 확인 (30초 후)
kubectl get nodes -w
```

## NodePool 설정 설명

### default NodePool

**용도**: 일반 애플리케이션 워크로드

**특징**:
- Spot 우선, On-Demand 대체
- t3.medium/large/xlarge 지원
- 최대 20 vCPU, 40GB 메모리
- 자동 통합 (Consolidation)

**적용 대상**:
- Gateway, Users, Stores
- Order, Payment, CheckIns
- OrderQuery

### spot-only NodePool

**용도**: 배치 작업, 중단 가능한 워크로드

**특징**:
- Spot 전용
- Taint 적용 (workload-type=batch)
- 최대 10 vCPU, 20GB 메모리

**적용 대상**:
- 배치 작업
- 데이터 처리
- 테스트 환경

## 애플리케이션 배포 시 설정

### Spot 인스턴스 사용 (권장)

```yaml
# Deployment 예시
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gateway
spec:
  replicas: 2
  template:
    spec:
      # Karpenter가 관리하는 노드에 배포
      nodeSelector:
        workload-type: application
      
      # Spot 중단 대비
      tolerations:
        - key: karpenter.sh/disruption
          operator: Exists
      
      # Pod Disruption Budget 설정
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: gateway
```

### On-Demand 인스턴스 강제 (중요 서비스)

```yaml
# Deployment 예시
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment
spec:
  template:
    spec:
      nodeSelector:
        karpenter.sh/capacity-type: on-demand
```

### 기본 노드 사용 (시스템 서비스)

```yaml
# Deployment 예시
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argocd-server
  namespace: argocd
spec:
  template:
    spec:
      # 기본 노드 그룹에 배포
      nodeSelector:
        eks.amazonaws.com/nodegroup: goorm-popcorn-prod-nodes
```

## 비용 최적화

### 예상 비용 (월간)

**기본 노드 (고정)**:
- t3.large × 3 = $182/월

**Karpenter 노드 (변동)**:
- Spot 인스턴스 평균 70% 할인
- 예상 사용량: t3.medium × 2 (평균)
- 비용: $27/월 (Spot 가격 기준)

**총 예상 비용**: $209/월

**기존 대비 절감**:
- t3.medium 5노드: $152/월
- t3.large 4노드: $243/월
- **절감액**: 없음 (안정성 향상)

### 비용 모니터링

```bash
# Karpenter 노드 비용 확인
kubectl get nodes -l karpenter.sh/nodepool \
  -o custom-columns=NAME:.metadata.name,\
INSTANCE-TYPE:.metadata.labels.node\\.kubernetes\\.io/instance-type,\
CAPACITY-TYPE:.metadata.labels.karpenter\\.sh/capacity-type,\
ZONE:.metadata.labels.topology\\.kubernetes\\.io/zone
```

## 모니터링

### Karpenter 메트릭

```bash
# Prometheus 메트릭 확인
kubectl port-forward -n karpenter svc/karpenter 8080:8080

# 브라우저에서 접속
open http://localhost:8080/metrics
```

### 주요 메트릭

- `karpenter_nodes_created`: 생성된 노드 수
- `karpenter_nodes_terminated`: 종료된 노드 수
- `karpenter_pods_startup_duration_seconds`: Pod 시작 시간
- `karpenter_interruption_actions_performed`: Spot 중단 처리 횟수

### CloudWatch 대시보드

Terraform으로 자동 생성된 대시보드:
- EKS 클러스터 메트릭
- 노드 리소스 사용률
- Karpenter 이벤트

## 트러블슈팅

### 노드가 생성되지 않음

```bash
# Karpenter 로그 확인
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=100

# 일반적인 원인:
# 1. IAM 권한 부족
# 2. 서브넷 태그 누락
# 3. 보안 그룹 설정 오류
```

### Spot 중단 처리

```bash
# Spot 중단 이벤트 확인
kubectl get events -n karpenter | grep interruption

# Pod 재스케줄링 확인
kubectl get pods --all-namespaces -o wide | grep Terminating
```

### 노드가 축소되지 않음

```bash
# NodePool 설정 확인
kubectl describe nodepool default

# Pod가 노드를 점유하고 있는지 확인
kubectl describe node <node-name> | grep -A 10 "Non-terminated Pods"
```

## 참고 자료

- [Karpenter 공식 문서](https://karpenter.sh/)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Spot Instance Best Practices](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/spot-best-practices.html)
