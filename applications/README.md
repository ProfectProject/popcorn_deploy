# ArgoCD Applications

이 디렉터리는 ArgoCD Application CRD 정의를 포함합니다.

## 디렉터리 구조

```
applications/
├── dev/
│   ├── application.yaml      # 애플리케이션(Application) 배포
│   ├── infrastructure-kafka.yaml # Kafka 스택(Kafka + Kafka UI) 배포
│   ├── infrastructure-lgtm.yaml  # LGTM 모니터링 스택 배포
│   └── kafka-connect.yaml    # Kafka Connect 배포
└── prod/
    ├── application.yaml      # 애플리케이션(Application) 배포
    ├── infrastructure-kafka.yaml # Kafka 스택(Kafka + Kafka UI) 배포
    ├── infrastructure-lgtm.yaml  # LGTM 모니터링 스택 배포
    └── kafka-connect.yaml    # Kafka Connect 배포
```

## 용도

ArgoCD Application은 Git 저장소의 Helm Chart를 Kubernetes 클러스터에 배포하는 방법을 정의합니다.

## 디렉터리 구분

### `/applications` (이 디렉터리)
- **용도**: ArgoCD Application CRD 정의
- **내용**: Kubernetes 리소스 (Application)
- **목적**: 애플리케이션 배포 설정

### `/infrastructure/argocd`
- **용도**: ArgoCD 자체를 설치하기 위한 Helm values
- **내용**: Helm values 파일
- **목적**: ArgoCD 설치 및 구성

## 사용 방법

### 1. ArgoCD 설치 (먼저 수행)
```bash
cd infrastructure/scripts
./install-argocd.sh prod
```

### 2. Application 생성
```bash
# 개발 환경
kubectl apply -f applications/dev/application.yaml
kubectl apply -f applications/dev/infrastructure-kafka.yaml
kubectl apply -f applications/dev/infrastructure-lgtm.yaml
kubectl apply -f applications/dev/kafka-connect.yaml

# 운영 환경
kubectl apply -f applications/prod/application.yaml
kubectl apply -f applications/prod/infrastructure-kafka.yaml
kubectl apply -f applications/prod/infrastructure-lgtm.yaml
kubectl apply -f applications/prod/kafka-connect.yaml
```

### 3. 상태 확인
```bash
# ArgoCD CLI
argocd app list
argocd app get popcorn-dev
argocd app sync popcorn-dev

# kubectl
kubectl get applications -n argocd
kubectl describe application popcorn-dev -n argocd
```

## Application 구조

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: popcorn-dev
  namespace: argocd
spec:
  project: default
  
  # Git 저장소 설정
  source:
    repoURL: https://github.com/your-org/popcorn_deploy.git
    targetRevision: HEAD
    path: helm/popcorn-umbrella
    helm:
      valueFiles:
        - values.yaml
        - values-dev.yaml
  
  # 배포 대상
  destination:
    server: https://kubernetes.default.svc
    namespace: popcorn-dev
  
  # 동기화 정책
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## 환경별 차이점

### 개발 환경 (dev)
- **자동 동기화**: 활성화 (prune: true, selfHeal: true)
- **네임스페이스**: popcorn-dev
- **Values**: values-dev.yaml

### 운영 환경 (prod)
- **자동 동기화**: 비활성화 (수동 승인)
- **네임스페이스**: popcorn-prod
- **Values**: values-prod.yaml

## 주의사항

1. **Git 저장소 URL**: `repoURL`을 실제 저장소 주소로 변경해야 합니다.
2. **운영 환경**: 자동 동기화를 비활성화하여 수동으로 배포를 승인합니다.
3. **네임스페이스**: Application이 생성되면 자동으로 네임스페이스가 생성됩니다.

## 트러블슈팅

### Application이 OutOfSync 상태
```bash
# 수동 동기화
argocd app sync popcorn-dev

# 또는 kubectl
kubectl patch application popcorn-dev -n argocd \
  --type merge \
  --patch '{"operation":{"initiatedBy":{"username":"admin"},"sync":{}}}'
```

### Application이 생성되지 않음
```bash
# ArgoCD가 설치되어 있는지 확인
kubectl get pods -n argocd

# CRD 확인
kubectl get crd applications.argoproj.io
```

### Git 저장소 접근 오류
```bash
# ArgoCD에 Git 저장소 추가
argocd repo add https://github.com/your-org/popcorn_deploy.git

# Private 저장소인 경우
argocd repo add https://github.com/your-org/popcorn_deploy.git \
  --username <username> \
  --password <token>
```

## 참고 자료

- [ArgoCD Application CRD](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#applications)
- [ArgoCD Sync Options](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/)
