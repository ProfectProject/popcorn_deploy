# ESO 전체 배포 가이드

실제 프로덕션 환경에 ESO를 배포하는 완전한 가이드입니다.

## 사전 준비

### 1. Terraform으로 인프라 생성 완료
- EKS 클러스터
- RDS PostgreSQL
- ElastiCache Valkey
- IRSA 역할 (External Secrets용)

### 2. kubectl 설정
```bash
aws eks update-kubeconfig \
  --region ap-northeast-2 \
  --name goorm-popcorn-prod
```

### 3. 네임스페이스 확인
```bash
kubectl get namespaces
```

## 1단계: AWS Secrets Manager에 시크릿 생성

### 자동 생성 (권장)
```bash
cd popcorn_deploy/infrastructure/external-secrets/scripts

# Prod 환경
./create-secrets.sh prod

# Dev 환경
./create-secrets.sh dev
```

생성되는 시크릿:
1. `/goorm-popcorn/prod/rds/master-password` - RDS 마스터 비밀번호
2. `/goorm-popcorn/prod/elasticache/auth-token` - Redis 인증 토큰
3. `/goorm-popcorn/prod/jwt/secret-key` - JWT 시크릿 키
4. `/goorm-popcorn/prod/passport/secret-key` - Passport 시크릿 키
5. `/goorm-popcorn/prod/external-apis/payment` - Toss Payments API 키
6. `/goorm-popcorn/prod/database/users` - 서비스별 DB 사용자 자격증명

### 수동 생성 (필요시)

#### RDS 마스터 비밀번호
```bash
aws secretsmanager create-secret \
  --name /goorm-popcorn/prod/rds/master-password \
  --description "RDS PostgreSQL master password" \
  --secret-string '{
    "username": "postgres",
    "password": "YOUR_SECURE_PASSWORD",
    "engine": "postgres",
    "host": "goorm-popcorn-rds-prod.xxxxxx.ap-northeast-2.rds.amazonaws.com",
    "port": 5432,
    "dbname": "popcorn_db"
  }' \
  --region ap-northeast-2
```

#### Database Users
```bash
aws secretsmanager create-secret \
  --name /goorm-popcorn/prod/database/users \
  --description "Database user credentials for all microservices" \
  --secret-string '{
    "user_auth_username": "user_auth_app",
    "user_auth_password": "SECURE_PASSWORD_1",
    "user_auth_flyway_username": "user_auth_migrator",
    "user_auth_flyway_password": "SECURE_PASSWORD_2",
    "order_username": "order_app",
    "order_password": "SECURE_PASSWORD_3",
    "order_flyway_username": "order_migrator",
    "order_flyway_password": "SECURE_PASSWORD_4",
    "payment_username": "payment_app",
    "payment_password": "SECURE_PASSWORD_5",
    "payment_flyway_username": "payment_migrator",
    "payment_flyway_password": "SECURE_PASSWORD_6",
    "store_username": "store_app",
    "store_password": "SECURE_PASSWORD_7",
    "store_flyway_username": "store_migrator",
    "store_flyway_password": "SECURE_PASSWORD_8",
    "qr_username": "qr_app",
    "qr_password": "SECURE_PASSWORD_9",
    "qr_flyway_username": "qr_migrator",
    "qr_flyway_password": "SECURE_PASSWORD_10"
  }' \
  --region ap-northeast-2
```

### 시크릿 검증
```bash
./verify-secrets.sh prod
```

## 2단계: ESO Helm 차트 설치

```bash
cd popcorn_deploy/infrastructure/external-secrets

# Prod 환경
./install-eso.sh prod
```

설치 확인:
```bash
# Pod 상태 확인
kubectl get pods -n external-secrets

# 로그 확인
kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets -f
```

예상 출력:
```
NAME                                                READY   STATUS    RESTARTS   AGE
external-secrets-7d8f9c5b6d-xxxxx                  1/1     Running   0          30s
external-secrets-cert-controller-5b7c8d9f4-xxxxx   1/1     Running   0          30s
external-secrets-webhook-6f8d7c5b4d-xxxxx          1/1     Running   0          30s
```

## 3단계: ClusterSecretStore 생성

```bash
kubectl apply -f clustersecretstore.yaml
```

ClusterSecretStore 상태 확인:
```bash
kubectl get clustersecretstore aws-secrets-manager

kubectl describe clustersecretstore aws-secrets-manager
```

예상 출력:
```
Name:         aws-secrets-manager
Scope:        Cluster
Status:
  Conditions:
    Status:  True
    Type:    Ready
```

## 4단계: ExternalSecret 생성

```bash
# Prod 환경
kubectl apply -f externalsecrets/prod/

# Dev 환경
kubectl apply -f externalsecrets/dev/
```

ExternalSecret 상태 확인:
```bash
# 모든 ExternalSecret 상태
kubectl get externalsecrets -n popcorn-prod

# 특정 ExternalSecret 상세 정보
kubectl describe externalsecret rds-credentials -n popcorn-prod
```

예상 출력:
```
NAME                 STORE                  REFRESH INTERVAL   STATUS         READY
rds-credentials      aws-secrets-manager    1h                 SecretSynced   True
redis-credentials    aws-secrets-manager    1h                 SecretSynced   True
jwt-secret           aws-secrets-manager    1h                 SecretSynced   True
passport-secret      aws-secrets-manager    1h                 SecretSynced   True
payment-api-keys     aws-secrets-manager    1h                 SecretSynced   True
database-users       aws-secrets-manager    1h                 SecretSynced   True
```

## 5단계: Kubernetes Secret 생성 확인

```bash
# 생성된 Secret 목록
kubectl get secrets -n popcorn-prod | grep -E "rds-credentials|redis-credentials|jwt-secret|passport-secret|payment-api-keys|database-users"

# 특정 Secret 상세 정보
kubectl describe secret rds-credentials -n popcorn-prod

# Secret 키 목록 확인
kubectl get secret rds-credentials -n popcorn-prod -o jsonpath='{.data}' | jq 'keys'

# Secret 값 확인 (Base64 디코딩)
kubectl get secret rds-credentials -n popcorn-prod -o jsonpath='{.data.DB_HOST}' | base64 -d
```

## 6단계: 애플리케이션 배포

### Helm values 업데이트

각 서비스의 `values.yaml`에 `service` 필드 추가:

```yaml
# users/values.yaml
service: "users"

# order/values.yaml
service: "order"

# payment/values.yaml
service: "payment"

# stores/values.yaml
service: "stores"

# checkins/values.yaml
service: "checkins"
```

### Deployment 템플릿 업데이트

`templates/deployment.yaml`에 공통 템플릿 적용:

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
        
        # 공통 시크릿 (RDS + Redis + JWT + Passport + Database Users)
        {{- include "common.env.all-secrets" . | nindent 8 }}
        
        # ConfigMap 참조
        envFrom:
        - configMapRef:
            name: common-config
        - configMapRef:
            name: {{ include "users.fullname" . }}-config
            optional: true
```

### 배포 실행

```bash
# Umbrella 차트로 전체 배포
helm upgrade --install popcorn \
  ./helm/popcorn-umbrella \
  -f ./helm/popcorn-umbrella/values-prod.yaml \
  --namespace popcorn-prod

# 개별 서비스 배포
helm upgrade --install users \
  ./helm/charts/users \
  -f ./helm/charts/users/values-prod.yaml \
  --namespace popcorn-prod
```

## 7단계: 검증

### Pod 환경변수 확인
```bash
# Pod 이름 확인
kubectl get pods

# 환경변수 확인
kubectl exec -it <pod-name> -- env | grep -E "DB_|REDIS_|JWT_|PASSPORT_|ORDER_|PAYMENT_|STORE_|QR_|USER_AUTH_"
```

### 애플리케이션 로그 확인
```bash
kubectl logs -f <pod-name>
```

### 데이터베이스 연결 테스트
```bash
# Pod 내부에서 psql 실행
kubectl exec -it <pod-name> -- bash

# PostgreSQL 연결 테스트
psql -h $DB_HOST -p $DB_PORT -U $ORDER_DB_USERNAME -d $DB_NAME
```

### Redis 연결 테스트
```bash
# Pod 내부에서 redis-cli 실행
kubectl exec -it <pod-name> -- bash

# Redis 연결 테스트
redis-cli -h $REDIS_HOST -p $REDIS_PORT -a $REDIS_PASSWORD ping
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

예상 어노테이션:
```yaml
Annotations:
  eks.amazonaws.com/role-arn: arn:aws:iam::375896310755:role/goorm-popcorn-prod-external-secrets
```

3. **IAM 역할 확인**
```bash
aws iam get-role --role-name goorm-popcorn-prod-external-secrets
```

4. **AWS Secrets Manager 접근 테스트**
```bash
aws secretsmanager get-secret-value \
  --secret-id /goorm-popcorn/prod/rds/master-password \
  --region ap-northeast-2
```

5. **ESO Pod 로그 확인**
```bash
kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets --tail=100
```

### Secret이 생성되지 않음

1. **ExternalSecret 이벤트 확인**
```bash
kubectl describe externalsecret rds-credentials -n popcorn-prod
```

2. **네임스페이스 확인**
```bash
kubectl get externalsecret rds-credentials -n popcorn-prod -o yaml | grep namespace
```

3. **시크릿 경로 확인**
```bash
aws secretsmanager list-secrets \
  --region ap-northeast-2 \
  --query 'SecretList[?starts_with(Name, `/goorm-popcorn/prod/`)].Name'
```

### Pod가 시작되지 않음

1. **Pod 이벤트 확인**
```bash
kubectl describe pod <pod-name>
```

2. **Secret 존재 확인**
```bash
kubectl get secrets
```

3. **Secret 키 확인**
```bash
kubectl get secret rds-credentials -o yaml
```

## 보안 고려사항

1. **최소 권한 원칙**: IRSA 역할은 필요한 시크릿에만 접근
2. **네임스페이스 격리**: ExternalSecret은 같은 네임스페이스에만 Secret 생성
3. **감사 로그**: CloudTrail로 Secrets Manager 접근 기록 추적
4. **시크릿 로테이션**: 정기적으로 시크릿 값 변경 (90일 권장)
5. **암호화**: Secrets Manager는 기본적으로 KMS로 암호화

## 시크릿 로테이션

### 수동 로테이션
```bash
# 1. AWS Secrets Manager에서 시크릿 업데이트
aws secretsmanager put-secret-value \
  --secret-id /goorm-popcorn/prod/jwt/secret-key \
  --secret-string "NEW_SECRET_VALUE" \
  --region ap-northeast-2

# 2. ExternalSecret 재동기화 (즉시 반영)
kubectl delete externalsecret jwt-secret -n popcorn-prod
kubectl apply -f externalsecrets/prod/jwt-secret.yaml

# 3. Pod 재시작 (환경변수 갱신)
kubectl rollout restart deployment/popcorn-users
```

### 자동 로테이션 (AWS Secrets Manager)
```bash
# Lambda 함수를 사용한 자동 로테이션 설정
aws secretsmanager rotate-secret \
  --secret-id /goorm-popcorn/prod/rds/master-password \
  --rotation-lambda-arn arn:aws:lambda:ap-northeast-2:375896310755:function:SecretsManagerRotation \
  --rotation-rules AutomaticallyAfterDays=90 \
  --region ap-northeast-2
```

## 모니터링

### CloudWatch 알람 설정
```bash
# Secrets Manager 접근 실패 알람
aws cloudwatch put-metric-alarm \
  --alarm-name "SecretsManager-AccessDenied" \
  --alarm-description "Alert when Secrets Manager access is denied" \
  --metric-name AccessDenied \
  --namespace AWS/SecretsManager \
  --statistic Sum \
  --period 300 \
  --threshold 1 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1
```

### ESO 메트릭 확인
```bash
# Prometheus 메트릭 (ESO가 노출)
kubectl port-forward -n external-secrets svc/external-secrets-metrics 8080:8080

# 브라우저에서 http://localhost:8080/metrics 접속
```

## 다음 단계

1. 각 서비스 Helm 차트에 공통 템플릿 적용
2. ConfigMap으로 일반 설정 분리
3. ArgoCD로 GitOps 파이프라인 구성
4. 시크릿 로테이션 정책 수립
5. 모니터링 및 알람 설정

## 참고 자료

- [ESO 공식 문서](https://external-secrets.io/)
- [AWS Secrets Manager 가이드](https://docs.aws.amazon.com/secretsmanager/)
- [IRSA 설정 가이드](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
