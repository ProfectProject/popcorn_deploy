# Karpenter 설정

Karpenter는 Kubernetes 클러스터의 노드 오토스케일링을 담당합니다.

## 개요

Karpenter는 Terraform에서 Helm 차트로 설치되며, 이 디렉터리는 NodePool과 EC2NodeClass 매니페스트를 관리합니다.

## 빠른 시작

```bash
# 1. 클러스터 연결
aws eks update-kubeconfig --region ap-northeast-2 --name goorm-popcorn-prod

# 2. Karpenter 리소스 설치
./install-karpenter-resources.sh prod

# 3. 테스트 워크로드 배포
kubectl apply -f test-workload.yaml

# 4. 노드 프로비저닝 확인
kubectl get nodes -l karpenter.sh/capacity-type=spot -w
```

자세한 내용은 [QUICKSTART.md](./QUICKSTART.md)를 참조하세요.

## 아키텍처

### 기본 노드 (Managed Node Group)
- **목적**: 클러스터 안정성 보장
- **용량 타입**: ON_DEMAND
- **워크로드**: 시스템 컴포넌트, Karpenter 자체, 인프라 서비스
- **Dev**: t3.medium x 2개 고정
- **Prod**: t3.medium x 3개 고정 (Multi-AZ)

### 오토스케일링 노드 (Karpenter)
- **목적**: 비용 최적화 및 탄력적 확장
- **용량 타입**: SPOT 우선 (Prod는 ON_DEMAND 폴백)
- **워크로드**: 무상태 마이크로서비스, 배치 작업
- **Dev**: t3.medium, SPOT, 0-10개
- **Prod**: t3.medium/t3.large, SPOT 우선, 0-20개

## 파일 구조

```
karpenter/
├── README.md                           # 이 파일
├── QUICKSTART.md                       # 빠른 시작 가이드
├── DEPLOYMENT_GUIDE.md                 # 상세 배포 가이드
├── install-karpenter-resources.sh      # 설치 스크립트
├── nodepool-dev.yaml                   # Dev 환경 NodePool
├── nodepool-prod.yaml                  # Prod 환경 NodePool
├── ec2nodeclass-dev.yaml               # Dev 환경 EC2NodeClass
├── ec2nodeclass-prod.yaml              # Prod 환경 EC2NodeClass
├── test-workload.yaml                  # 테스트 워크로드
├── example-microservice.yaml           # 마이크로서비스 예제
└── helm-values-example.yaml            # Helm values 예제
```

## 배포 방법

### 1. Terraform으로 Karpenter 설치 (이미 완료)

```bash
cd popcorn-terraform-feature/envs/prod
terraform apply
```

생성되는 리소스:
- Karpenter Helm 차트
- Karpenter IAM 역할
- SQS 큐 (Spot 인터럽션용)
- EventBridge 규칙

### 2. NodePool 및 EC2NodeClass 적용

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

### 3. 확인

```bash
# NodePool 확인
kubectl get nodepools

# EC2NodeClass 확인
kubectl get ec2nodeclasses

# Karpenter 로그 확인
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter -f
```

## 주요 기능

### Spot 인터럽션 처리
- **SQS 큐**: Spot 인터럽션 알림 수신
- **EventBridge**: AWS 이벤트를 SQS로 전달
- **Graceful Shutdown**: 2분 전 알림으로 Pod 안전하게 종료

### 인스턴스 선택
- **다양한 타입**: Karpenter가 워크로드에 맞는 인스턴스 자동 선택
- **가용 영역**: Multi-AZ 분산 배치
- **비용 최적화**: 가장 저렴한 인스턴스 우선 선택

### 리소스 제한
- **최대 노드 수**: Dev 10개, Prod 20개
- **TTL**: 유휴 노드 자동 제거 (30초)
- **Consolidation**: 리소스 효율적 재배치

## 워크로드 스케줄링

### Karpenter 노드에 배포 (무상태 마이크로서비스)
```yaml
spec:
  tolerations:
  - key: karpenter.sh/spot
    operator: Exists
    effect: NoSchedule
  
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
```yaml
spec:
  nodeSelector:
    eks.amazonaws.com/nodegroup: goorm-popcorn-prod
  
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: karpenter.sh/capacity-type
            operator: DoesNotExist
```

## 모니터링

### 메트릭
- `karpenter_nodes_total`: 총 노드 수
- `karpenter_pods_state`: Pod 상태
- `karpenter_interruption_received_messages`: 인터럽션 메시지 수

### 로그
```bash
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=100 -f
```

### 노드 상태
```bash
# 모든 노드
kubectl get nodes -L karpenter.sh/capacity-type,node-type

# Karpenter 노드만
kubectl get nodes -l karpenter.sh/capacity-type=spot

# 리소스 사용량
kubectl top nodes
```

## 문제 해결

### NodePool이 노드를 생성하지 않음
1. NodePool 상태 확인: `kubectl describe nodepool default`
2. EC2NodeClass 상태 확인: `kubectl describe ec2nodeclass default`
3. Karpenter 로그 확인: `kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter`
4. IAM 역할 확인: Karpenter 역할에 필요한 권한이 있는지 확인

### Spot 인터럽션 처리 안됨
1. SQS 큐 확인: AWS 콘솔에서 메시지 수신 여부 확인
2. EventBridge 규칙 확인: 규칙이 활성화되어 있는지 확인
3. Karpenter 설정 확인: `interruptionQueue` 설정 확인

### Pod가 Pending 상태로 남음
1. Pod 이벤트 확인: `kubectl describe pod <pod-name>`
2. NodePool 제약 확인: `kubectl get nodepool default -o yaml`
3. 리소스 제한 확인: NodePool의 `limits` 확인

## 비용 최적화

### Spot 인스턴스 전략
- **Dev**: 100% Spot (최대 비용 절감)
- **Prod**: Spot 우선, ON_DEMAND 폴백 (안정성 + 비용 절감)

### 예상 비용 절감
- Spot 인스턴스: 최대 90% 절감
- Consolidation: 추가 10-20% 절감
- 유휴 노드 제거: 추가 5-10% 절감

## 참고 자료

- [Karpenter 공식 문서](https://karpenter.sh/)
- [AWS Karpenter 모범 사례](https://aws.github.io/aws-eks-best-practices/karpenter/)
- [Spot 인스턴스 가이드](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-spot-instances.html)
- [상세 배포 가이드](./DEPLOYMENT_GUIDE.md)
- [빠른 시작 가이드](./QUICKSTART.md)
