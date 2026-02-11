# Helm 차트에서 시크릿 사용하기

ESO로 생성된 시크릿을 Helm 차트에서 사용하는 방법입니다.

## 공통 템플릿 사용

`common/templates/_secrets.tpl`에 정의된 템플릿을 사용하면 간편하게 시크릿을 주입할 수 있습니다.

### 방법 1: 개별 시크릿 템플릿 사용

각 서비스의 `templates/deployment.yaml`에서:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "users.fullname" . }}
spec:
  template:
    spec:
      containers:
      - name: {{ .Chart.Name }}
        env:
        # 기본 환경변수
        - name: SPRING_PROFILES_ACTIVE
          value: {{ .Values.env.SPRING_PROFILES_ACTIVE }}
        - name: SERVER_PORT
          value: {{ .Values.env.SERVER_PORT | quote }}
        
        # RDS 자격증명 (공통 템플릿)
        {{- include "common.env.rds" . | nindent 8 }}
        
        # Redis 자격증명 (공통 템플릿)
        {{- include "common.env.redis" . | nindent 8 }}
        
        # JWT 시크릿 (공통 템플릿)
        {{- include "common.env.jwt" . | nindent 8 }}
        
        # Passport 시크릿 (공통 템플릿)
        {{- include "common.env.passport" . | nindent 8 }}
```

### 방법 2: 모든 시크릿 한 번에 사용

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "users.fullname" . }}
spec:
  template:
    spec:
      containers:
      - name: {{ .Chart.Name }}
        env:
        # 기본 환경변수
        - name: SPRING_PROFILES_ACTIVE
          value: {{ .Values.env.SPRING_PROFILES_ACTIVE }}
        
        # 모든 공통 시크릿 (RDS + Redis + JWT + Passport)
        {{- include "common.env.all-secrets" . | nindent 8 }}
```

### 방법 3: 결제 서비스 전용

Payment 서비스의 경우:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "payment.fullname" . }}
spec:
  template:
    spec:
      containers:
      - name: {{ .Chart.Name }}
        env:
        # 기본 환경변수
        - name: SPRING_PROFILES_ACTIVE
          value: {{ .Values.env.SPRING_PROFILES_ACTIVE }}
        
        # 공통 시크릿
        {{- include "common.env.all-secrets" . | nindent 8 }}
        
        # 결제 API 키 (Payment 서비스 전용)
        {{- include "common.env.payment" . | nindent 8 }}
```

## 서비스별 적용 가이드

### Users 서비스
필요한 시크릿: RDS, Redis, JWT, Passport

```yaml
{{- include "common.env.all-secrets" . | nindent 8 }}
```

### Stores 서비스
필요한 시크릿: RDS, Redis, Passport

```yaml
{{- include "common.env.rds" . | nindent 8 }}
{{- include "common.env.redis" . | nindent 8 }}
{{- include "common.env.passport" . | nindent 8 }}
```

### Order 서비스
필요한 시크릿: RDS, Redis, Passport

```yaml
{{- include "common.env.rds" . | nindent 8 }}
{{- include "common.env.redis" . | nindent 8 }}
{{- include "common.env.passport" . | nindent 8 }}
```

### OrderQuery 서비스
필요한 시크릿: RDS (읽기 전용), Redis

```yaml
{{- include "common.env.rds" . | nindent 8 }}
{{- include "common.env.redis" . | nindent 8 }}
```

### Payment 서비스
필요한 시크릿: RDS, Redis, Passport, Payment API Keys

```yaml
{{- include "common.env.all-secrets" . | nindent 8 }}
{{- include "common.env.payment" . | nindent 8 }}
```

### CheckIns 서비스
필요한 시크릿: RDS, Redis, Passport

```yaml
{{- include "common.env.rds" . | nindent 8 }}
{{- include "common.env.redis" . | nindent 8 }}
{{- include "common.env.passport" . | nindent 8 }}
```

### Gateway 서비스
필요한 시크릿: Redis, JWT

```yaml
{{- include "common.env.redis" . | nindent 8 }}
{{- include "common.env.jwt" . | nindent 8 }}
```

## 커스텀 시크릿 추가

서비스별로 추가 시크릿이 필요한 경우:

```yaml
env:
# 공통 시크릿
{{- include "common.env.all-secrets" . | nindent 8 }}

# 서비스 전용 시크릿
- name: CUSTOM_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.customSecret.name }}
      key: {{ .Values.customSecret.key }}
```

## values.yaml 설정

시크릿 참조는 템플릿에서 처리하므로 `values.yaml`에는 기본 환경변수만 정의:

```yaml
env:
  SPRING_PROFILES_ACTIVE: "prod"
  SERVER_PORT: "8080"
  JAVA_OPTS: "-Xms256m -Xmx512m"
  
  # 시크릿은 템플릿에서 자동 주입되므로 여기에 정의하지 않음
  # DB_HOST, DB_PASSWORD 등은 ESO가 관리
```

## 로컬 개발 환경

로컬에서는 ESO 없이 직접 Secret을 생성:

```bash
kubectl create secret generic rds-credentials \
  --from-literal=host=localhost \
  --from-literal=port=5432 \
  --from-literal=database=popcorn_dev \
  --from-literal=username=postgres \
  --from-literal=password=postgres
```

## 테스트

Helm 차트 렌더링 확인:

```bash
helm template users ./helm/charts/users \
  -f ./helm/popcorn-umbrella/values-prod.yaml \
  --debug
```

환경변수 주입 확인:

```bash
kubectl exec -it <pod-name> -- env | grep -E "DB_|REDIS_|JWT_|PASSPORT_"
```

## 문제 해결

### 환경변수가 주입되지 않음

1. Secret이 생성되었는지 확인:
```bash
kubectl get secrets
```

2. Pod 이벤트 확인:
```bash
kubectl describe pod <pod-name>
```

3. Secret 키 이름 확인:
```bash
kubectl get secret rds-credentials -o yaml
```

### 템플릿 렌더링 오류

```bash
# Helm 차트 문법 검증
helm lint ./helm/charts/users

# 렌더링 결과 확인
helm template users ./helm/charts/users --debug
```

## 참고

- ESO 설정: `infrastructure/external-secrets/README.md`
- 시크릿 생성: `infrastructure/external-secrets/scripts/create-secrets.sh`
- 공통 템플릿: `helm/charts/common/templates/_secrets.tpl`
