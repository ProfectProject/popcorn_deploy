# ArgoCD

GitOps를 위한 Kubernetes 배포 자동화 도구

## 개요

ArgoCD는 Kubernetes를 위한 선언적 GitOps 지속적 배포 도구입니다.

## Helm Repository

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
```

## 네임스페이스

```bash
kubectl create namespace argocd
```

## 설치 명령어

```bash
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --values values.yaml \
  --values values-prod.yaml
```

## 접속 정보

### ArgoCD UI
```bash
# 포트 포워딩
kubectl port-forward -n argocd svc/argocd-server 8080:443

# 브라우저에서 접속
open https://localhost:8080
```

### 초기 비밀번호
```bash
# admin 계정 초기 비밀번호 확인
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

### CLI 로그인
```bash
# ArgoCD CLI 설치
brew install argocd

# 로그인
argocd login localhost:8080
```

## Application 관리

### Application 생성
```bash
# Popcorn MSA 개발 환경
kubectl apply -f ../../applications/dev/application.yaml

# Popcorn MSA 운영 환경
kubectl apply -f ../../applications/prod/application.yaml
```

### Application 상태 확인
```bash
argocd app list
argocd app get popcorn-dev
argocd app sync popcorn-dev
```

## 주요 기능

### 1. 자동 동기화
- Git 저장소 변경 시 자동 배포
- Self-Healing: 수동 변경 시 자동 복구

### 2. 배포 전략
- Rolling Update
- Blue-Green Deployment
- Canary Deployment

### 3. 롤백
- 이전 버전으로 즉시 롤백
- Git 히스토리 기반 버전 관리

### 4. 멀티 클러스터
- 여러 Kubernetes 클러스터 관리
- 환경별 배포 관리

## 보안

### SSO 통합
- GitHub OAuth
- Google OAuth
- LDAP/Active Directory

### RBAC
- 프로젝트별 권한 관리
- 사용자/그룹별 접근 제어

## 모니터링

- Prometheus 메트릭 수출
- Grafana 대시보드 연동
- 배포 히스토리 추적
- 알림 설정 (Slack, Email 등)

## 참고 자료

- [ArgoCD 공식 문서](https://argo-cd.readthedocs.io/)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
