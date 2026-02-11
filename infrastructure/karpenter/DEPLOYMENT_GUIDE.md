# Karpenter 배포 가이드

Karpenter를 프로덕션 환경에 배포하는 완전한 가이드입니다.

## 개요

Karpenter는 Kubernetes 클러스터의 노드를 자동으로 프로비저닝하고 관리하는 오픈소스 오토스케일러입니다.

### 주요 기능
- **빠른 스케일링**: Cluster Autoscaler보다 10배 빠른 노드 프로비저닝
- **비용 최적화**: Spot 인스턴스 우선 사용으로 최대 90% 비용 절감
- **유연한 인스턴스 선택**: 워크로드에 맞는 최적의 인스턴스 자동 선택
- **Spot 인터럽션 처리**: SQS + EventBridge로 안전한 Graceful Shutdown

## 아키텍처

### 노드 전략

#### 기본 노드 (Managed Node Group)
```
목적: 클러스터 안정성 보장
용량: ON_DEMAND
워크로드:
  - Karpenter 자체
  - CoreDNS, kube-proxy 등 시스템 컴포넌트
  - ArgoCD, External Secrets Operator 등 인프라 서비스
  - Prometheus, Grafana 등 모니터링 스택

Dev: t3.medium x 2개 고정
Prod: t3.medium x 3개 고정 (Multi-AZ)
```

#### 오토스케일링 노드 (Karpenter)
```
목적: 비용 최적화 및 탄력적 확장
용량: SPOT 우선 (Prod는 ON_DEMAND 폴백)
워크로드:
  - 무상태 마이크로서비스 (Users, Stores, Order 등)
  - 배치 작업
  - 임시 워크로드

Dev: t3.medium, SPOT, 0-10개
Prod: t3.medium/t3.large, SPOT 우선, 0-20개
```

## 사전 준비

### 1. Terraform으로 인프라 생성 완료
- EKS 클러스터
- Karpenter Helm 차트 설치
- Karpenter IAM 역할
- SQS 큐 (Spot 인터럽션용)
- EventBridge 규칙

### 2. kubectl 설정
```bash
aws eks update-kubeconfig \
  --region ap-northeast-2 \
  --name goorm-popcorn-prod
```

### 3. Karpenter 설치 확인
```bash
kubectl get deployment -n karpenter
kubectl get pods -n karpenter
```

예상 출력:
```
NAME                                    READY   STATUS    RESTARTS   AGE
karpenter-7d8f9c5b6d-xxxxx             1/1     Running   0          5m
karpenter-cert-controller-xxxxx        1/1     Running   0          5m
karpenter-webhook-xxxxx                1/1     Running   0          5m
```

## 배포 단계

### 1단계: EC2NodeClass 및 NodePool 적용

#### 자동 설치 (권장)
```bash
cd popcorn_deploy/infrastructure/karpenter

# Prod 환경
./install-karpenter-resources.sh prod

# Dev 환경
./install-karpenter-resources.sh dev
```

#### 수동 설치
```bash
# EC2NodeClass 적용
kubectl apply -f ec2nodeclass-prod.yaml

# NodePool 적용
kubectl apply -f nodepool-prod.yaml
```

### 2단계: 리소스 확인

```bash
# EC2NodeClass 확인
kubectl get ec2nodeclass
kubectl describe ec2nodeclass default

# NodePool 확인
kubectl get nodepool
kubectl describe nodepool default
```

예상 출력:
```
NAME      AGE
default   30s

NAME      NODECLASS   NODES   READY   AGE
default   default     0       True    30s
```

### 3단계: 테스트 워크로드 배포

```bash
# 테스트 워크로드 배포
kubectl apply -f test-workload.yaml

# Pod 상태 확인
kubectl get pods -w

# 노드 프로비저닝 확인
kubectl get nodes -l karpenter.sh/capacity-type=spot
```

### 4단계: Karpenter 로그 모니터링

```bash
# 실시간 로그 확인
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter -f

# 최근 100줄 확인
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=100
```

## 워크로드 스케줄링

### Karpenter 노드에 배포 (권장)

무상태 마이크로서비스는 Karpenter 노드에 배포:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: popcorn-users
spec:
  template:
    spec:
      # Spot 인스턴스 허용
      tolerations:
      - key: karpenter.sh/spot
        operator: Exists
        effect: NoSchedule
      
      # Karpenter 노드 선호
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: karpenter.sh/capacity-type
                operator: In
                values:
                - spot
```

### 기본 노드에 배포 (시스템 컴포넌트)

중요한 인프라 서비스는 기본 노드에 배포:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argocd-server
spec:
  template:
    spec:
      # Managed Node Group 지정
      nodeSelector:
        eks.amazonaws.com/nodegroup: goorm-popcorn-prod
      
      # Spot 노드 회피
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: karpenter.sh/capacity-type
                operator: DoesNotExist
```

## Helm 차트 통합

### Umbrella 차트 values.yaml

```yaml
# values-prod.yaml
global:
  karpenter:
    enabled: true
    spotToleration: true

users:
  nodeSelector:
    karpenter.sh/capacity-type: spot
  tolerations:
  - key: karpenter.sh/spot
    operator: Exists
    effect: NoSchedule

order:
  nodeSelector:
    karpenter.sh/capacity-type: spot
  tolerations:
  - key: karpenter.sh/spot
    operator: Exists
    effect: NoSchedule

# 인프라 서비스는 기본 노드에
argocd:
  nodeSelector:
    eks.amazonaws.com/nodegroup: goorm-popcorn-prod
```

## 모니터링

### Karpenter 메트릭

```bash
# Prometheus 메트릭 확인
kubectl port-forward -n karpenter svc/karpenter 8080:8080

# 브라우저에서 http://localhost:8080/metrics 접속
```

주요 메트릭:
- `karpenter_nodes_total` - 총 노드 수
- `karpenter_nodes_allocatable` - 할당 가능한 리소스
- `karpenter_pods_state` - Pod 상태별 개수
- `karpenter_interruption_received_messages` - Spot 인터럽션 메시지 수
- `karpenter_disruption_budgets_allowed_disruptions` - 허용된 중단 수

### CloudWatch 대시보드

```bash
# CloudWatch 대시보드 URL
echo "https://ap-northeast-2.console.aws.amazon.com/cloudwatch/home?region=ap-northeast-2#dashboards:name=Karpenter-goorm-popcorn-prod"
```

### 노드 상태 확인

```bash
# 모든 노드 확인
kubectl get nodes -L karpenter.sh/capacity-type,node-type

# Karpenter 노드만 확인
kubectl get nodes -l karpenter.sh/capacity-type=spot

# 노드 리소스 사용량
kubectl top nodes
```

## 비용 최적화

### Spot 인스턴스 전략

#### Dev 환경
```yaml
# 100% Spot (비용 최소화)
requirements:
  - key: karpenter.sh/capacity-type
    operator: In
    values: ["spot"]
```

#### Prod 환경
```yaml
# Spot 우선, ON_DEMAND 폴백 (안정성 + 비용 절감)
requirements:
  - key: karpenter.sh/capacity-type
    operator: In
    values: ["spot", "on-demand"]
```

### 인스턴스 다양화

여러 인스턴스 타입을 허용하여 Spot 가용성 향상:

```yaml
requirements:
  - key: karpenter.k8s.aws/instance-family
    operator: In
    values: ["t3", "t3a"]  # t3a 추가로 선택지 확대
  
  - key: karpenter.k8s.aws/instance-size
    operator: In
    values: ["medium", "large", "xlarge"]
```

### Consolidation (통합)

유휴 리소스를 줄이기 위해 노드 통합:

```yaml
disruption:
  consolidationPolicy: WhenUnderutilized
  consolidateAfter: 30s  # Dev는 빠르게
```

## Spot 인터럽션 처리

### 동작 방식

1. **AWS EventBridge**: Spot 인터럽션 이벤트 감지
2. **SQS 큐**: 이벤트를 큐에 저장
3. **Karpenter**: 큐에서 메시지 읽기
4. **Graceful Shutdown**: 2분 전 알림으로 Pod 안전하게 종료
5. **노드 교체**: 새 노드 프로비저닝

### 확인 방법

```bash
# SQS 큐 확인
aws sqs get-queue-attributes \
  --queue-url https://sqs.ap-northeast-2.amazonaws.com/375896310755/goorm-popcorn-prod-karpenter \
  --attribute-names All

# EventBridge 규칙 확인
aws events list-rules --name-prefix goorm-popcorn-prod-karpenter

# Karpenter 로그에서 인터럽션 확인
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter | grep interruption
```

## 문제 해결

### NodePool이 노드를 생성하지 않음

1. **NodePool 상태 확인**
```bash
kubectl describe nodepool default
```

2. **EC2NodeClass 상태 확인**
```bash
kubectl describe ec2nodeclass default
```

3. **Karpenter 로그 확인**
```bash
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=100
```

4. **IAM 역할 확인**
```bash
aws iam get-role --role-name KarpenterNodeRole-goorm-popcorn-prod
```

5. **서브넷 태그 확인**
```bash
aws ec2 describe-subnets \
  --filters "Name=tag:karpenter.sh/discovery,Values=goorm-popcorn-prod"
```

### Pod가 Pending 상태로 남음

1. **Pod 이벤트 확인**
```bash
kubectl describe pod <pod-name>
```

2. **NodePool 제약 확인**
```bash
kubectl get nodepool default -o yaml
```

3. **리소스 제한 확인**
```bash
# NodePool의 limits 확인
kubectl get nodepool default -o jsonpath='{.spec.limits}'
```

### Spot 인터럽션 처리 안됨

1. **SQS 큐 메시지 확인**
```bash
aws sqs receive-message \
  --queue-url https://sqs.ap-northeast-2.amazonaws.com/375896310755/goorm-popcorn-prod-karpenter
```

2. **EventBridge 규칙 활성화 확인**
```bash
aws events describe-rule --name goorm-popcorn-prod-karpenter-spot-interruption
```

3. **Karpenter 설정 확인**
```bash
kubectl get deployment -n karpenter karpenter -o yaml | grep interruptionQueue
```

### 노드가 너무 많이 생성됨

1. **NodePool limits 확인**
```bash
kubectl get nodepool default -o jsonpath='{.spec.limits}'
```

2. **Consolidation 설정 확인**
```bash
kubectl get nodepool default -o jsonpath='{.spec.disruption}'
```

3. **Pod 리소스 요청 확인**
```bash
kubectl describe pod <pod-name> | grep -A 5 "Requests:"
```

## 보안 고려사항

### IMDSv2 강제
```yaml
metadataOptions:
  httpTokens: required  # IMDSv2만 허용
```

### EBS 암호화
```yaml
blockDeviceMappings:
  - deviceName: /dev/xvda
    ebs:
      encrypted: true  # 볼륨 암호화
```

### 최소 권한 IAM 역할
- EC2 인스턴스 생성/종료 권한만 부여
- Secrets Manager 접근 불필요

## 성능 튜닝

### Kubelet 설정

```yaml
kubelet:
  maxPods: 110  # 노드당 최대 Pod 수
  systemReserved:
    cpu: 200m
    memory: 200Mi
  kubeReserved:
    cpu: 200m
    memory: 200Mi
```

### 이미지 GC

```yaml
kubelet:
  imageGCHighThresholdPercent: 85
  imageGCLowThresholdPercent: 80
```

### Eviction 정책

```yaml
kubelet:
  evictionHard:
    memory.available: 5%
    nodefs.available: 10%
  evictionSoft:
    memory.available: 10%
    nodefs.available: 15%
```

## 업그레이드

### Karpenter 버전 업그레이드

```bash
# Terraform에서 버전 변경
cd popcorn-terraform-feature/modules/eks
# helm.tf에서 karpenter 버전 업데이트

# Terraform apply
cd ../../envs/prod
terraform apply
```

### NodePool 업데이트

```bash
# NodePool 수정
kubectl edit nodepool default

# 또는 파일 수정 후 적용
kubectl apply -f nodepool-prod.yaml
```

## 다음 단계

1. 각 마이크로서비스 Helm 차트에 Karpenter 설정 추가
2. Spot 인터럽션 테스트
3. 비용 모니터링 대시보드 구성
4. 알람 설정 (노드 프로비저닝 실패, Spot 인터럽션 등)
5. 정기적인 NodePool 설정 검토

## 참고 자료

- [Karpenter 공식 문서](https://karpenter.sh/)
- [AWS Karpenter 모범 사례](https://aws.github.io/aws-eks-best-practices/karpenter/)
- [Spot 인스턴스 가이드](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-spot-instances.html)
