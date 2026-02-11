# ArgoCD Discord 알림 설정 가이드

## 개요

ArgoCD의 배포 상태를 Discord로 실시간 알림받을 수 있도록 설정합니다.

## 구성 요소

### 1. Secret (notifications-secret.yaml)
Discord 웹훅 URL을 안전하게 저장합니다.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: argocd-notifications-secret
  namespace: argocd
type: Opaque
stringData:
  discord-webhook-url: "https://discord.com/api/webhooks/..."
```

**보안 주의사항**:
- 이 파일은 Git에 커밋하지 마세요
- `.gitignore`에 추가 권장
- 실제 배포 시 수동으로 적용하거나 External Secrets 사용

### 2. ConfigMap (notifications-cm.yaml)
알림 템플릿과 트리거를 정의합니다.

**포함된 알림 유형**:
- ✅ 배포 성공
- ❌ 배포 실패
- ⚠️ 헬스 체크 실패
- 🔄 동기화 필요 (Out of Sync)

### 3. Values (values.yaml)
ArgoCD Notifications 컨트롤러를 활성화합니다.

## 배포 방법

### 1. Secret 적용 (수동)

```bash
# Secret 적용
kubectl apply -f infrastructure/argocd/notifications-secret.yaml

# Secret 확인
kubectl get secret argocd-notifications-secret -n argocd
```

### 2. ConfigMap 적용

```bash
# ConfigMap 적용
kubectl apply -f infrastructure/argocd/notifications-cm.yaml

# ConfigMap 확인
kubectl get cm argocd-notifications-cm -n argocd
```

### 3. ArgoCD Helm 업그레이드

```bash
# Dev 환경
helm upgrade argocd argo/argo-cd \
  -n argocd \
  -f infrastructure/argocd/values.yaml \
  -f infrastructure/argocd/values-dev.yaml

# Prod 환경
helm upgrade argocd argo/argo-cd \
  -n argocd \
  -f infrastructure/argocd/values.yaml \
  -f infrastructure/argocd/values-prod.yaml
```

## 알림 테스트

### 1. 테스트 애플리케이션 배포

```bash
# 간단한 애플리케이션 동기화
argocd app sync <app-name>
```

### 2. 알림 확인
Discord 채널에서 다음과 같은 메시지를 확인할 수 있습니다:

```
✅ 배포 성공

애플리케이션: popcorn-gateway
환경: dev
상태: Succeeded
동기화 리비전: abc123
시간: 2025-02-11T10:30:00Z

[ArgoCD에서 보기](https://argocd.goormpopcorn.shop/applications/popcorn-gateway)
```

## 애플리케이션별 알림 설정

특정 애플리케이션에만 알림을 받고 싶다면, Application 매니페스트에 어노테이션을 추가합니다:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: popcorn-gateway
  annotations:
    # 특정 트리거만 활성화
    notifications.argoproj.io/subscribe.on-deployed.discord: ""
    notifications.argoproj.io/subscribe.on-sync-failed.discord: ""
```

## 알림 비활성화

특정 애플리케이션의 알림을 비활성화하려면:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: popcorn-gateway
  annotations:
    # 모든 알림 비활성화
    notifications.argoproj.io/subscribe: ""
```

## 커스텀 알림 추가

### 1. ConfigMap에 템플릿 추가

```yaml
data:
  template.custom-alert: |
    message: |
      🔔 **커스텀 알림**
      
      **애플리케이션**: {{.app.metadata.name}}
      **메시지**: 원하는 내용
```

### 2. 트리거 추가

```yaml
data:
  trigger.on-custom: |
    - description: 커스텀 조건
      send:
      - custom-alert
      when: <조건>
```

## Discord 웹훅 URL 변경

### 1. 새 웹훅 생성
Discord 서버 설정 > 연동 > 웹훅에서 새 웹훅 생성

### 2. Secret 업데이트

```bash
# Secret 삭제
kubectl delete secret argocd-notifications-secret -n argocd

# 새 Secret 생성 (notifications-secret.yaml 수정 후)
kubectl apply -f infrastructure/argocd/notifications-secret.yaml
```

### 3. Notifications 컨트롤러 재시작

```bash
kubectl rollout restart deployment argocd-notifications-controller -n argocd
```

## 트러블슈팅

### 알림이 오지 않는 경우

1. **Secret 확인**
```bash
kubectl get secret argocd-notifications-secret -n argocd -o yaml
```

2. **ConfigMap 확인**
```bash
kubectl get cm argocd-notifications-cm -n argocd -o yaml
```

3. **Notifications 컨트롤러 로그 확인**
```bash
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-notifications-controller
```

4. **웹훅 URL 테스트**
```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"content": "테스트 메시지"}' \
  "https://discord.com/api/webhooks/..."
```

### 일반적인 문제

**문제**: "service not found" 에러
**해결**: ConfigMap에서 `service.discord` 설정 확인

**문제**: 웹훅 URL이 작동하지 않음
**해결**: Discord에서 웹훅이 활성화되어 있는지 확인

**문제**: 알림이 중복으로 옴
**해결**: Application 어노테이션과 ConfigMap의 기본 구독 설정 확인

## 보안 권장사항

### 1. Secret을 Git에서 제외

`.gitignore`에 추가:
```
infrastructure/argocd/notifications-secret.yaml
```

### 2. External Secrets 사용 (권장)

AWS Secrets Manager에 웹훅 URL 저장:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: argocd-notifications-secret
  namespace: argocd
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: argocd-notifications-secret
  data:
    - secretKey: discord-webhook-url
      remoteRef:
        key: argocd/discord-webhook-url
```

### 3. RBAC 설정

Secret에 대한 접근 제한:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: argocd-notifications-secret-reader
  namespace: argocd
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    resourceNames: ["argocd-notifications-secret"]
    verbs: ["get"]
```

## 참고 자료

- [ArgoCD Notifications 공식 문서](https://argocd-notifications.readthedocs.io/)
- [Discord 웹훅 가이드](https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks)
- [ArgoCD Notification 템플릿 예제](https://github.com/argoproj/argo-cd/tree/master/notifications_catalog)

## 다음 단계

1. Secret을 AWS Secrets Manager로 마이그레이션
2. 추가 알림 채널 설정 (Slack, Email 등)
3. 커스텀 알림 템플릿 작성
4. 알림 필터링 및 라우팅 규칙 추가
