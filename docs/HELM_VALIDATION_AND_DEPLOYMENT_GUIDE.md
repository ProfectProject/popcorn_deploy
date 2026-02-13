# Helm 차트 검증 및 배포 가이드

**작성일**: 2025-02-13  
**대상**: DevOps 엔지니어, 개발자  
**난이도**: 중급

## 목차

1. [개요](#개요)
2. [사전 요구사항](#사전-요구사항)
3. [로컬 검증](#로컬-검증)
4. [개발 환경 배포](#개발-환경-배포)
5. [프로덕션 환경 배포](#프로덕션-환경-배포)
6. [문제 해결](#문제-해결)
7. [모범 사례](#모범-사례)

---

## 개요

이 문서는 Popcorn MSA 프로젝트의 Helm 차트를 검증하고 Kubernetes 클러스터에 배포하는 전체 프로세스를 설명합니다.

### 배포 아키텍처

```
로컬 개발 → Helm 검증 → 개발 환경 배포 → 프로덕션 배포
    ↓           ↓              ↓                ↓
  Lint      Template       ArgoCD Sync      ArgoCD Sync
  Test      Render         (dev)            (prod)
```

---

## 사전 요구사항

### 필수 도구

```bash
# Helm 설치 확인
helm version
# Version: v3.12.0 이상 권장

# kubectl 설치 확인
kubectl version --client
# Client Version: v1.28.0 이상 권장

# AWS CLI 설치 확인 (EKS 사용 시)
aws --version
# aws-cli/2.13.0 이상 권장
```

### 클러스터 접근 권한

```bash
# EKS 클러스터 kubeconfig 설정
aws eks update-kubeconfig \
  --region ap-northeast-2 \
  --name popcorn-dev-cluster \
  --profile your-profile

# 클러스터 접근 확인
kubectl cluster-info
kubectl get nodes
```

### 네임스페이스 준비

```bash
# 개발 환경 네임스페이스
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -

# 프로덕션 환경 네임스페이스
kubectl create namespace prod --dry-run=client -o yaml | kubectl apply -f -

# 테스트용 네임스페이스
kubectl create namespace helm-test --dry-run=client -o yaml | kubectl apply -f -
```

---

## 로컬 검증

배포 전 로컬에서 Helm 차트를 철저히 검증합니다.

### 1단계: 의존성 업데이트

```bash
cd popcorn_deploy/helm/popcorn-umbrella

# 모든 서비스 차트의 의존성 업데이트
for service in gateway users stores order payment checkins order-query; do
  echo "Updating dependencies for $service..."
  helm dependency update ../charts/$service
done

# Umbrella 차트 의존성 업데이트
helm dependency update
```

**예상 결과**:
```
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "stable" chart repository
Update Complete. ⎈Happy Helming!⎈
Saving 1 charts
Deleting outdated charts
```

### 2단계: Helm Lint 실행

```bash
# Umbrella 차트 Lint
helm lint .

# 개별 서비스 차트 Lint
for service in gateway users stores order payment checkins order-query; do
  echo "Linting $service..."
  helm lint ../charts/$service
done
```

**통과 기준**:
```
==> Linting .
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed
```

**일반적인 경고**:
- `icon is recommended`: 차트 아이콘 미설정 (무시 가능)
- `Chart.yaml: dependencies are not in Chart.yaml`: 의존성 업데이트 필요

### 3단계: 템플릿 렌더링 검증

```bash
# 기본 값으로 템플릿 렌더링
helm template test . --debug > /tmp/rendered-manifests.yaml

# 렌더링 결과 확인
cat /tmp/rendered-manifests.yaml | head -50

# 특정 서비스만 렌더링
helm template test . --debug \
  --set gateway.enabled=true \
  --set users.enabled=false \
  --set stores.enabled=false \
  --set order.enabled=false \
  --set payment.enabled=false \
  --set orderQuery.enabled=false \
  --set checkIns.enabled=false
```

**검증 포인트**:
- ✅ YAML 문법 오류 없음
- ✅ 모든 변수가 올바르게 치환됨
- ✅ Kubernetes 리소스 이름이 RFC 1123 규칙 준수 (소문자, 숫자, `-`, `.`만 사용)
- ✅ ConfigMap 키가 유효함 (영숫자, `-`, `_`, `.`만 사용)

### 4단계: 환경별 값 검증

```bash
# 개발 환경 값으로 렌더링
helm template test . \
  --values values-dev.yaml \
  --debug > /tmp/dev-manifests.yaml

# 프로덕션 환경 값으로 렌더링
helm template test . \
  --values values-prod.yaml \
  --debug > /tmp/prod-manifests.yaml

# 차이점 비교
diff /tmp/dev-manifests.yaml /tmp/prod-manifests.yaml | head -100
```

### 5단계: Dry-run 배포 테스트

```bash
# 실제 배포 없이 검증 (클러스터 접근 필요)
helm install popcorn-test . \
  --namespace helm-test \
  --values values-dev.yaml \
  --dry-run \
  --debug
```

**통과 기준**:
```
NAME: popcorn-test
LAST DEPLOYED: ...
NAMESPACE: helm-test
STATUS: pending-install
REVISION: 1
TEST SUITE: None
```

### 6단계: Kubernetes 리소스 검증

```bash
# kubeval로 Kubernetes 스키마 검증 (선택사항)
helm template test . | kubeval --strict

# kubeconform으로 검증 (선택사항)
helm template test . | kubeconform -strict -summary
```

---

## 개발 환경 배포

### 방법 1: Helm 직접 배포 (테스트용)

```bash
cd popcorn_deploy/helm/popcorn-umbrella

# 배포 전 현재 릴리스 확인
helm list -n dev

# 신규 배포
helm install popcorn . \
  --namespace dev \
  --values values-dev.yaml \
  --create-namespace \
  --wait \
  --timeout 10m

# 업그레이드 배포
helm upgrade popcorn . \
  --namespace dev \
  --values values-dev.yaml \
  --wait \
  --timeout 10m

# 설치 또는 업그레이드 (권장)
helm upgrade --install popcorn . \
  --namespace dev \
  --values values-dev.yaml \
  --create-namespace \
  --wait \
  --timeout 10m
```

**배포 옵션 설명**:
- `--wait`: 모든 Pod가 Ready 상태가 될 때까지 대기
- `--timeout 10m`: 최대 대기 시간 10분
- `--create-namespace`: 네임스페이스가 없으면 생성
- `--atomic`: 실패 시 자동 롤백

### 방법 2: ArgoCD를 통한 GitOps 배포 (권장)

```bash
# ArgoCD Application 생성
kubectl apply -f applications/dev/application.yaml

# 동기화 상태 확인
argocd app get popcorn-dev

# 수동 동기화 트리거
argocd app sync popcorn-dev

# 자동 동기화 활성화
argocd app set popcorn-dev --sync-policy automated
```

### 배포 확인

```bash
# 릴리스 상태 확인
helm status popcorn -n dev

# Pod 상태 확인
kubectl get pods -n dev -w

# 서비스 확인
kubectl get svc -n dev

# Ingress/ALB 확인
kubectl get ingress -n dev

# 로그 확인
kubectl logs -n dev -l app.kubernetes.io/name=gateway --tail=100 -f
```

### 배포 검증

```bash
# 헬스체크 엔드포인트 테스트
kubectl port-forward -n dev svc/popcorn-gateway 8080:8080

# 다른 터미널에서
curl http://localhost:8080/actuator/health

# 예상 응답
{
  "status": "UP",
  "components": {
    "diskSpace": {"status": "UP"},
    "ping": {"status": "UP"}
  }
}
```

---

## 프로덕션 환경 배포

### 사전 체크리스트

배포 전 반드시 확인:

- [ ] 개발 환경에서 충분히 테스트 완료
- [ ] 데이터베이스 마이그레이션 완료
- [ ] Secrets 설정 완료 (AWS Secrets Manager)
- [ ] 모니터링 대시보드 준비
- [ ] 롤백 계획 수립
- [ ] 배포 시간대 확인 (트래픽 적은 시간)
- [ ] 관련 팀원에게 배포 공지

### 단계별 배포 프로세스

#### 1단계: 프로덕션 값 검증

```bash
cd popcorn_deploy/helm/popcorn-umbrella

# 프로덕션 템플릿 렌더링 검증
helm template popcorn . \
  --values values-prod.yaml \
  --debug > /tmp/prod-deployment.yaml

# 주요 설정 확인
grep -A 5 "replicas:" /tmp/prod-deployment.yaml
grep -A 5 "resources:" /tmp/prod-deployment.yaml
grep -A 5 "image:" /tmp/prod-deployment.yaml
```

#### 2단계: Dry-run 배포

```bash
# 실제 배포 없이 검증
helm upgrade --install popcorn . \
  --namespace prod \
  --values values-prod.yaml \
  --dry-run \
  --debug
```

#### 3단계: 실제 배포 (ArgoCD 권장)

```bash
# ArgoCD Application 생성
kubectl apply -f applications/prod/application.yaml

# 동기화 전 차이점 확인
argocd app diff popcorn-prod

# 수동 동기화 (단계별 확인)
argocd app sync popcorn-prod --prune=false

# 동기화 진행 상황 모니터링
argocd app wait popcorn-prod --health
```

#### 4단계: 배포 모니터링

```bash
# Pod 롤아웃 상태 확인
kubectl rollout status deployment/popcorn-gateway -n prod
kubectl rollout status deployment/popcorn-users -n prod
kubectl rollout status deployment/popcorn-stores -n prod
kubectl rollout status deployment/popcorn-order -n prod
kubectl rollout status deployment/popcorn-payment -n prod
kubectl rollout status deployment/popcorn-order-query -n prod
kubectl rollout status deployment/popcorn-checkins -n prod

# 전체 Pod 상태 확인
kubectl get pods -n prod -o wide

# 이벤트 확인
kubectl get events -n prod --sort-by='.lastTimestamp' | tail -20
```

#### 5단계: 헬스체크 및 스모크 테스트

```bash
# ALB 엔드포인트 확인
ALB_URL=$(kubectl get ingress -n prod popcorn-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# 헬스체크
curl -s https://$ALB_URL/actuator/health | jq

# 주요 API 테스트
curl -s https://$ALB_URL/api/users/health
curl -s https://$ALB_URL/api/stores/health
curl -s https://$ALB_URL/api/orders/health
```

#### 6단계: 모니터링 확인

```bash
# CloudWatch 대시보드 확인
# - CPU/메모리 사용률
# - 요청 수 및 응답 시간
# - 에러율

# Grafana 대시보드 확인
# - 애플리케이션 메트릭
# - 비즈니스 메트릭

# 로그 확인
kubectl logs -n prod -l app.kubernetes.io/name=gateway --tail=100
```

### 롤백 절차

문제 발생 시 즉시 롤백:

```bash
# Helm 롤백
helm rollback popcorn -n prod

# 특정 리비전으로 롤백
helm history popcorn -n prod
helm rollback popcorn 3 -n prod

# ArgoCD 롤백
argocd app rollback popcorn-prod

# Kubernetes 롤백
kubectl rollout undo deployment/popcorn-gateway -n prod
```

---

## 문제 해결

### 일반적인 문제

#### 1. ImagePullBackOff

**증상**:
```bash
kubectl get pods -n dev
NAME                              READY   STATUS             RESTARTS   AGE
popcorn-gateway-xxx               0/1     ImagePullBackOff   0          2m
```

**원인**: ECR 이미지가 없거나 권한 문제

**해결**:
```bash
# 이미지 태그 확인
kubectl describe pod popcorn-gateway-xxx -n dev | grep Image

# ECR 이미지 존재 확인
aws ecr describe-images \
  --repository-name popcorn/gateway \
  --image-ids imageTag=latest

# ECR 로그인 확인
aws ecr get-login-password --region ap-northeast-2 | \
  docker login --username AWS --password-stdin \
  123456789012.dkr.ecr.ap-northeast-2.amazonaws.com

# ServiceAccount IAM 역할 확인
kubectl describe sa popcorn-gateway -n dev
```

#### 2. CrashLoopBackOff

**증상**:
```bash
kubectl get pods -n dev
NAME                              READY   STATUS             RESTARTS   AGE
popcorn-gateway-xxx               0/1     CrashLoopBackOff   5          5m
```

**원인**: 애플리케이션 시작 실패

**해결**:
```bash
# 로그 확인
kubectl logs popcorn-gateway-xxx -n dev --previous

# 일반적인 원인:
# - 데이터베이스 연결 실패
# - 환경 변수 누락
# - 메모리 부족
# - 포트 충돌

# ConfigMap 확인
kubectl get configmap popcorn-gateway-config -n dev -o yaml

# Secret 확인
kubectl get secret popcorn-gateway-secret -n dev -o yaml
```

#### 3. Pending 상태

**증상**:
```bash
kubectl get pods -n dev
NAME                              READY   STATUS    RESTARTS   AGE
popcorn-gateway-xxx               0/1     Pending   0          10m
```

**원인**: 리소스 부족 또는 스케줄링 실패

**해결**:
```bash
# Pod 이벤트 확인
kubectl describe pod popcorn-gateway-xxx -n dev

# 노드 리소스 확인
kubectl top nodes
kubectl describe nodes

# PVC 상태 확인 (스토리지 사용 시)
kubectl get pvc -n dev
```

#### 4. Service 연결 실패

**증상**: Pod는 정상이지만 서비스 간 통신 실패

**해결**:
```bash
# Service 확인
kubectl get svc -n dev
kubectl describe svc popcorn-gateway -n dev

# Endpoint 확인
kubectl get endpoints popcorn-gateway -n dev

# DNS 테스트
kubectl run -it --rm debug --image=busybox --restart=Never -n dev -- sh
nslookup popcorn-gateway
wget -O- http://popcorn-gateway:8080/actuator/health

# NetworkPolicy 확인
kubectl get networkpolicy -n dev
```

### 디버깅 도구

```bash
# 임시 디버그 Pod 실행
kubectl run -it --rm debug \
  --image=nicolaka/netshoot \
  --restart=Never \
  -n dev -- bash

# Pod 내부 접속
kubectl exec -it popcorn-gateway-xxx -n dev -- bash

# 포트 포워딩
kubectl port-forward -n dev svc/popcorn-gateway 8080:8080

# 리소스 사용량 확인
kubectl top pods -n dev
kubectl top nodes
```

---

## 모범 사례

### 1. 버전 관리

```yaml
# Chart.yaml
version: 1.2.3  # 차트 버전 (SemVer)
appVersion: "v1.2.3"  # 애플리케이션 버전

# values.yaml
image:
  tag: "v1.2.3"  # 명시적 태그 사용 (latest 금지)
```

### 2. 리소스 제한 설정

```yaml
# values-prod.yaml
resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    cpu: 1000m
    memory: 1Gi
```

### 3. 헬스체크 설정

```yaml
# values.yaml
livenessProbe:
  httpGet:
    path: /actuator/health/liveness
    port: 8080
  initialDelaySeconds: 60
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /actuator/health/readiness
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 5
```

### 4. 롤링 업데이트 전략

```yaml
# values-prod.yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0  # 무중단 배포
```

### 5. HPA 설정

```yaml
# values-prod.yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80
```

### 6. 보안 설정

```yaml
# values.yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: true
```

### 7. 배포 자동화

```yaml
# .github/workflows/deploy-dev.yml
name: Deploy to Dev
on:
  push:
    branches: [develop]
    paths:
      - 'helm/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Update Helm dependencies
        run: |
          cd helm/popcorn-umbrella
          helm dependency update
      
      - name: Lint Helm chart
        run: helm lint helm/popcorn-umbrella
      
      - name: Deploy to ArgoCD
        run: |
          argocd app sync popcorn-dev --prune
```

---

## 체크리스트

### 배포 전

- [ ] Helm 의존성 업데이트 완료
- [ ] Helm lint 통과
- [ ] 템플릿 렌더링 검증 완료
- [ ] Dry-run 배포 성공
- [ ] 환경별 값 파일 검증 완료
- [ ] Secrets 설정 완료
- [ ] 데이터베이스 마이그레이션 완료

### 배포 중

- [ ] 배포 진행 상황 모니터링
- [ ] Pod 상태 확인
- [ ] 로그 실시간 확인
- [ ] 헬스체크 통과 확인

### 배포 후

- [ ] 모든 Pod가 Running 상태
- [ ] 서비스 엔드포인트 정상 응답
- [ ] 모니터링 메트릭 정상
- [ ] 스모크 테스트 통과
- [ ] 배포 문서 업데이트

---

## 참고 자료

- [Helm 공식 문서](https://helm.sh/docs/)
- [Kubernetes 공식 문서](https://kubernetes.io/docs/)
- [ArgoCD 공식 문서](https://argo-cd.readthedocs.io/)
- [프로젝트 배포 가이드](./DEPLOYMENT_GUIDE.md)
- [Helm 차트 구조](../helm/README.md)

---

## 변경 이력

| 날짜 | 버전 | 변경 내용 | 작성자 |
|------|------|-----------|--------|
| 2025-02-13 | 1.0.0 | 초기 작성 | DevOps Team |
