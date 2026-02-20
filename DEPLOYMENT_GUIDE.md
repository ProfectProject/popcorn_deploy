# Popcorn MSA Deployment Guide

## 사전 준비사항

### 1. 필수 도구 설치
```bash
# Helm 3.x 설치
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# kubectl 설치 및 EKS 클러스터 연결
aws eks update-kubeconfig --region ap-northeast-2 --name popcorn-eks-cluster

# ArgoCD CLI 설치 (선택사항)
brew install argocd
```

### 2. ECR 인증
```bash
# ECR 로그인
aws ecr get-login-password --region ap-northeast-2 | \
  docker login --username AWS --password-stdin \
  375896310755.dkr.ecr.ap-northeast-2.amazonaws.com
```

### 3. Namespace 생성
```bash
# 개발 환경
kubectl create namespace popcorn-dev

# 운영 환경
kubectl create namespace popcorn-prod
```

## Helm Chart 구조

```
helm/
├── charts/                    # 개별 서비스 차트
│   ├── common/               # 공통 라이브러리
│   ├── gateway/              # API Gateway
│   ├── users/                # User Service
│   ├── stores/               # Store Service
│   ├── order/                # Order Service
│   ├── payment/              # Payment Service
│   ├── orderQuery/           # Order Query Service
│   └── checkIns/             # CheckIn Service
└── popcorn-umbrella/         # Umbrella Chart
    ├── Chart.yaml
    ├── values.yaml           # 기본값
    ├── values-dev.yaml       # 개발 환경
    └── values-prod.yaml      # 운영 환경
```

## 배포 방법

### 방법 1: Helm CLI 직접 배포

#### 개발 환경 배포
```bash
# Chart dependencies(.tgz) 동기화
./helm/scripts/sync-umbrella-deps.sh

# 배포 (dry-run으로 먼저 확인)
helm upgrade --install popcorn-dev ./helm/popcorn-umbrella \
  --namespace popcorn-dev \
  --values ./helm/popcorn-umbrella/values.yaml \
  --values ./helm/popcorn-umbrella/values-dev.yaml \
  --dry-run --debug

# 실제 배포
helm upgrade --install popcorn-dev ./helm/popcorn-umbrella \
  --namespace popcorn-dev \
  --values ./helm/popcorn-umbrella/values.yaml \
  --values ./helm/popcorn-umbrella/values-dev.yaml
```

#### 운영 환경 배포
```bash
# 특정 이미지 태그로 배포
helm upgrade --install popcorn-prod . \
  --namespace popcorn-prod \
  --values values.yaml \
  --values values-prod.yaml \
  --set global.imageTag=v1.0.0
```

#### 개별 서비스만 업데이트
```bash
# users 서비스만 업데이트
helm upgrade --install popcorn-dev . \
  --namespace popcorn-dev \
  --values values-dev.yaml \
  --set users.image.tag=v1.0.1
```

### 방법 2: ArgoCD를 통한 GitOps 배포

#### ArgoCD 설치
```bash
# ArgoCD 설치
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# ArgoCD 서버 접속
kubectl port-forward svc/argocd-server -n argocd 8080:80

# 초기 비밀번호 확인
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

#### Application 생성
```bash
# 개발 환경
kubectl apply -f applications/dev/application.yaml

# 운영 환경
kubectl apply -f applications/prod/application.yaml
```

#### ArgoCD UI에서 확인
```bash
# ArgoCD UI 접속
open http://localhost:8080

# 또는 CLI로 확인
argocd app list
argocd app get popcorn-dev
argocd app sync popcorn-dev
```

## 배포 확인

### Pod 상태 확인
```bash
# 모든 Pod 확인
kubectl get pods -n popcorn-dev

# 특정 서비스 로그 확인
kubectl logs -f deployment/gateway -n popcorn-dev

# 서비스 상태 확인
kubectl get svc -n popcorn-dev
```

### Health Check
```bash
# Gateway health check
kubectl port-forward svc/gateway -n popcorn-dev 8080:8080
curl http://localhost:8080/actuator/health

# 각 서비스 health check
for service in gateway users stores order payment orderquery checkins; do
  echo "Checking $service..."
  kubectl exec -it deployment/$service -n popcorn-dev -- \
    curl -s http://localhost:8080/actuator/health | jq .
done
```

### Ingress 확인
```bash
# Ingress 상태 확인
kubectl get ingress -n popcorn-prod

# ALB 주소 확인
kubectl get ingress gateway -n popcorn-prod -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## 롤백

### Helm 롤백
```bash
# 릴리스 히스토리 확인
helm history popcorn-dev -n popcorn-dev

# 이전 버전으로 롤백
helm rollback popcorn-dev 1 -n popcorn-dev
```

### ArgoCD 롤백
```bash
# ArgoCD UI에서 History 탭에서 이전 버전 선택 후 Sync
# 또는 CLI로
argocd app rollback popcorn-dev <revision>
```

## 환경별 설정 커스터마이징

### 데이터베이스 연결 정보 변경
```yaml
# values-prod.yaml
global:
  database:
    host: popcorn-db-prod.cluster-xxx.ap-northeast-2.rds.amazonaws.com
    port: 5432
    name: popcorn
```

### 리소스 조정
```yaml
# values-prod.yaml
gateway:
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 2000m
      memory: 2Gi
```

### 오토스케일링 설정
```yaml
# values-prod.yaml
gateway:
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 20
    targetCPUUtilizationPercentage: 70
```

## 트러블슈팅

### Pod가 시작되지 않는 경우
```bash
# Pod 상세 정보 확인
kubectl describe pod <pod-name> -n popcorn-dev

# 이벤트 확인
kubectl get events -n popcorn-dev --sort-by='.lastTimestamp'

# 로그 확인
kubectl logs <pod-name> -n popcorn-dev --previous
```

### ImagePullBackOff 에러
```bash
# ECR 인증 확인
kubectl get secret -n popcorn-dev

# ECR 접근 권한 확인 (IRSA)
kubectl describe sa gateway -n popcorn-dev
```

### Health Check 실패
```bash
# Readiness probe 확인
kubectl describe pod <pod-name> -n popcorn-dev | grep -A 10 Readiness

# 직접 health check 엔드포인트 호출
kubectl exec -it <pod-name> -n popcorn-dev -- \
  curl http://localhost:8080/actuator/health
```

### 서비스 간 통신 문제
```bash
# DNS 확인
kubectl exec -it <pod-name> -n popcorn-dev -- nslookup users

# 네트워크 정책 확인
kubectl get networkpolicies -n popcorn-dev

# 서비스 엔드포인트 확인
kubectl get endpoints -n popcorn-dev
```

## 모니터링

### Prometheus 메트릭 확인
```bash
# 메트릭 엔드포인트 확인
kubectl port-forward svc/gateway -n popcorn-dev 8080:8080
curl http://localhost:8080/actuator/prometheus
```

### Grafana 대시보드
```bash
# Grafana 접속
kubectl port-forward svc/grafana -n monitoring 3000:3000
open http://localhost:3000
```

## 보안

### Secret 관리
```bash
# Secret 생성
kubectl create secret generic db-credentials \
  --from-literal=username=popcorn \
  --from-literal=password=<password> \
  -n popcorn-prod

# External Secrets Operator 사용 (권장)
# AWS Secrets Manager와 자동 동기화
```

### RBAC 설정
```bash
# ServiceAccount 권한 확인
kubectl auth can-i list pods --as=system:serviceaccount:popcorn-dev:gateway
```

## CI/CD 통합

### GitHub Actions에서 배포
```yaml
# .github/workflows/deploy.yaml
- name: Deploy to EKS
  run: |
    ./helm/scripts/sync-umbrella-deps.sh
    helm upgrade --install popcorn-prod ./helm/popcorn-umbrella \
      --namespace popcorn-prod \
      --values values-prod.yaml \
      --set global.imageTag=${{ github.sha }}
```

### ArgoCD Image Updater
```bash
# 자동 이미지 업데이트 설정
kubectl apply -f argocd/image-updater.yaml
```

## 참고 자료

- [Helm 공식 문서](https://helm.sh/docs/)
- [ArgoCD 공식 문서](https://argo-cd.readthedocs.io/)
- [Kubernetes 공식 문서](https://kubernetes.io/docs/)
- [AWS EKS 모범 사례](https://aws.github.io/aws-eks-best-practices/)
