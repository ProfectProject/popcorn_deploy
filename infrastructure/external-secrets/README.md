# External Secrets Operator (ESO)

AWS Secrets Manager의 시크릿을 Kubernetes Secret으로 자동 동기화합니다.

## 개요

ESO는 AWS Secrets Manager에 저장된 시크릿을 Kubernetes 클러스터로 가져와 Secret 리소스로 생성합니다.

## 아키텍처

```
AWS Secrets Manager
    ↓ (IRSA 인증)
External Secrets Operator
    ↓ (동기화)
Kubernetes Secrets
    ↓ (환경변수 주입)
Application Pods
```

## 전체 설치 가이드

### 1단계: Terraform으로 IRSA 역할 생성

ESO가 AWS Secrets Manager에 접근하려면 IRSA(IAM Roles for Service Accounts) 역할이 필요합니다.

```bash
cd popcorn-terraform-feature/envs/prod
terraform apply
```

생성되는 리소스:
- IAM Role: `goorm-popcorn-prod-external-secrets`
- 권한: Secrets Manager 읽기 권한 (`/goorm-popcorn/prod/*`)

### 2단계: AWS Secrets Manager에 시크릿 생성

```bash
cd popcorn_deploy/infrastructure/external-secrets/scripts

# Prod 환경 시크릿 생성
./create-secrets.sh prod

# Dev 환경 시크릿 생성
./create-secrets.sh dev
```

생성되는 시크릿:
- `/goorm-popcorn/prod/rds/master-password` - RDS 마스터 비밀번호
- `/goorm-popcorn/prod/elasticache/auth-token` - Redis/Valkey 인증 토큰
- `/goorm-popcorn/prod/jwt/secret-key` - JWT 시크릿 키
- `/goorm-popcorn/prod/passport/secret-key` - Passport 시크릿 키
- `/goorm-popcorn/prod/external-apis/payment` - 결제 API 키 (JSON)

### 3단계: 시크릿 검증

```bash
# 시크릿이 제대로 생성되었는지 확인
./verify-secrets.sh prod
```

### 4단계: ESO Helm 차트 설치

```bash
cd popcorn_deploy/infrastructure/external-secrets

# Prod 환경
./install-eso.sh prod

# Dev 환경
./install-eso.sh dev
```

`install-eso.sh`는 다음을 자동으로 수행합니다.
- ESO Helm 설치 (`external-secrets` 네임스페이스)
- 앱 네임스페이스 생성 (`popcorn-prod` 또는 `popcorn-dev`)
- 공용 `ClusterSecretStore` 적용
- 환경별 `ExternalSecret` 적용 (`externalsecrets/prod`, `externalsecrets/dev`)

설치 확인:
```bash
kubectl get pods -n external-secrets
kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets
```

### 5단계: ClusterSecretStore 생성 (수동 적용 시)

```bash
kubectl apply -f clustersecretstore.yaml
```

ClusterSecretStore 상태 확인:
```bash
kubectl get clustersecretstore aws-secrets-manager
kubectl describe clustersecretstore aws-secrets-manager
```

### 6단계: ExternalSecret 생성 (수동 적용 시)

```bash
# Prod 환경
kubectl apply -f externalsecrets/prod/

# Dev 환경
kubectl apply -f externalsecrets/dev/
```

ExternalSecret 상태 확인:
```bash
kubectl get externalsecrets -n popcorn-prod
kubectl describe externalsecret rds-credentials -n popcorn-prod
```

### 7단계: Kubernetes Secret 생성 확인

ESO가 자동으로 생성한 Secret 확인:
```bash
kubectl get secrets -n popcorn-prod

# Secret 내용 확인 (Base64 디코딩)
kubectl get secret rds-credentials -n popcorn-prod -o jsonpath='{.data.password}' | base64 -d
```

## 파일 구조

```
external-secrets/
├── README.md                    # 이 파일
├── install-eso.sh              # ESO 설치 스크립트
├── values-dev.yaml             # Dev 환경 Helm values
├── values-prod.yaml            # Prod 환경 Helm values
├── clustersecretstore.yaml     # 공용 ClusterSecretStore
├── externalsecrets/            # ExternalSecret 매니페스트
│   ├── prod/
│   └── dev/
└── scripts/                    # 유틸리티 스크립트
    ├── create-secrets.sh       # AWS Secrets Manager 시크릿 생성
    └── verify-secrets.sh       # 시크릿 검증
```

## 주요 개념

### ClusterSecretStore
클러스터 공용 AWS Secrets Manager 연결 설정. IRSA 역할을 사용하여 인증합니다.

### ExternalSecret
동기화할 시크릿 정의. AWS Secrets Manager의 어떤 시크릿을 Kubernetes Secret으로 가져올지 지정합니다.

### Kubernetes Secret
ESO가 자동으로 생성하는 최종 Secret. 애플리케이션 Pod에서 환경변수로 주입됩니다.

## 애플리케이션에서 사용하기

### Helm values.yaml 예제

```yaml
env:
  # RDS 연결 정보
  DB_HOST:
    valueFrom:
      secretKeyRef:
        name: rds-credentials
        key: host
  DB_PASSWORD:
    valueFrom:
      secretKeyRef:
        name: rds-credentials
        key: password
  
  # JWT 시크릿
  JWT_SECRET_KEY:
    valueFrom:
      secretKeyRef:
        name: jwt-secret
        key: secret-key
```

### Spring Boot application.yaml 예제

```yaml
spring:
  datasource:
    url: jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}
    username: ${DB_USERNAME}
    password: ${DB_PASSWORD}
  
  data:
    redis:
      host: ${REDIS_HOST}
      port: ${REDIS_PORT}
      password: ${REDIS_PASSWORD}

jwt:
  secret: ${JWT_SECRET_KEY}
  expiration: 3600000

passport:
  secret: ${PASSPORT_SECRET_KEY}
  expiration: 60000
```

## 모니터링

### ESO Pod 로그 확인
```bash
kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets -f
```

### ExternalSecret 상태 확인
```bash
# 모든 ExternalSecret 상태
kubectl get externalsecrets -n popcorn-prod

# 특정 ExternalSecret 상세 정보
kubectl describe externalsecret rds-credentials -n popcorn-prod
```

### Secret 생성 확인
```bash
# 모든 Secret 목록
kubectl get secrets -n popcorn-prod

# 특정 Secret 확인
kubectl describe secret rds-credentials -n popcorn-prod
```

### 동기화 상태 확인
```bash
# ExternalSecret의 Status 필드 확인
kubectl get externalsecret rds-credentials -n popcorn-prod -o yaml | grep -A 10 status
```

## 문제 해결

### ExternalSecret이 동기화되지 않음

1. **ClusterSecretStore 상태 확인**
```bash
kubectl describe clustersecretstore aws-secrets-manager
```

2. **IRSA 권한 확인**
```bash
kubectl describe sa external-secrets-sa -n external-secrets
```

3. **AWS Secrets Manager 접근 확인**
```bash
aws secretsmanager get-secret-value \
  --secret-id /goorm-popcorn/prod/rds/master-password \
  --region ap-northeast-2
```

4. **ESO Pod 로그 확인**
```bash
kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets
```

### Secret이 생성되지 않음

1. **ExternalSecret 이벤트 확인**
```bash
kubectl describe externalsecret rds-credentials -n popcorn-prod
```

2. **네임스페이스 확인**
```bash
# ExternalSecret과 Secret이 같은 네임스페이스에 있는지 확인
kubectl get externalsecret rds-credentials -n popcorn-prod -o yaml | grep namespace
kubectl get secret rds-credentials -n popcorn-prod -o yaml | grep namespace
```

3. **시크릿 경로 확인**
```bash
# AWS Secrets Manager에 시크릿이 존재하는지 확인
aws secretsmanager list-secrets \
  --region ap-northeast-2 \
  --query 'SecretList[?starts_with(Name, `/goorm-popcorn/prod/`)].Name'
```

### IRSA 권한 오류

1. **ServiceAccount 어노테이션 확인**
```bash
kubectl get sa external-secrets-sa -n external-secrets -o yaml
```

예상 출력:
```yaml
metadata:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::375896310755:role/goorm-popcorn-prod-external-secrets
```

2. **IAM 역할 신뢰 관계 확인**
```bash
aws iam get-role --role-name goorm-popcorn-prod-external-secrets
```

3. **IAM 정책 확인**
```bash
aws iam list-role-policies --role-name goorm-popcorn-prod-external-secrets
```

## 시크릿 업데이트

### AWS Secrets Manager에서 시크릿 업데이트

```bash
# 시크릿 값 업데이트
aws secretsmanager put-secret-value \
  --secret-id /goorm-popcorn/prod/jwt/secret-key \
  --secret-string "new-secret-value" \
  --region ap-northeast-2
```

ESO는 기본적으로 1시간마다 자동으로 동기화합니다. 즉시 동기화하려면:

```bash
# ExternalSecret 재생성
kubectl delete externalsecret jwt-secret -n popcorn-prod
kubectl apply -f externalsecrets/prod/jwt-secret.yaml
```

### 동기화 주기 변경

`externalsecrets/prod/*.yaml` 또는 `externalsecrets/dev/*.yaml` 파일에서 `refreshInterval` 수정:

```yaml
spec:
  refreshInterval: 5m  # 5분마다 동기화
```

## 보안 고려사항

1. **최소 권한 원칙**: IRSA 역할은 필요한 시크릿에만 접근 가능
2. **네임스페이스 격리**: ExternalSecret은 같은 네임스페이스에만 Secret 생성
3. **감사 로그**: AWS CloudTrail로 Secrets Manager 접근 기록 추적
4. **시크릿 로테이션**: 정기적으로 시크릿 값 변경 권장

## 참고 자료

- [External Secrets Operator 공식 문서](https://external-secrets.io/)
- [AWS Provider 가이드](https://external-secrets.io/latest/provider/aws-secrets-manager/)
- [IRSA 설정 가이드](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
