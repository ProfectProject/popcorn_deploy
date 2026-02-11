# Database V0 초기화 가이드

## 개요

RDS PostgreSQL 생성 후 글로벌 스키마(V0__init.sql)를 초기화하는 Kubernetes Job입니다.

## 구성 요소

```
db-init/
├── configmap.yaml       # V0__init.sql 스크립트
├── db-init-job.yaml     # 초기화 Job
├── kustomization.yaml   # Kustomize 설정
└── README.md           # 이 문서
```

## 사전 요구사항

### 1. External Secrets 설정 완료

RDS 자격 증명이 Kubernetes Secret으로 동기화되어 있어야 합니다:

```bash
kubectl get secret rds-credentials -n default
```

필요한 키:
- `host`: RDS 엔드포인트
- `port`: 포트 (기본 5432)
- `database`: 데이터베이스 이름
- `username`: 마스터 사용자명 (postgres)
- `password`: 마스터 비밀번호

### 2. RDS 보안 그룹 설정

EKS 노드에서 RDS로 접근 가능해야 합니다:
- RDS 보안 그룹에 EKS 노드 보안 그룹 허용
- 포트 5432 인바운드 규칙 추가

## 배포 방법

### 방법 1: Kustomize 사용 (권장)

```bash
# db-init 디렉터리에서 실행
cd popcorn_deploy/infrastructure/db-init

# ConfigMap과 Job 동시 배포
kubectl apply -k .
```

Kustomize가 자동으로:
- V0__init.sql 파일에서 ConfigMap 생성
- Job 리소스 배포

### 방법 2: kubectl 직접 적용

```bash
# 1. ConfigMap 생성 (파일에서)
kubectl create configmap db-init-v0-script \
  --from-file=V0__init.sql=./V0__init.sql \
  --namespace=default \
  --dry-run=client -o yaml | kubectl apply -f -

# 2. Job 실행
kubectl apply -f db-init-job.yaml
```

### 방법 3: Helm으로 통합

Helm 차트의 pre-install hook으로 통합:

```yaml
# templates/db-init-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  annotations:
    "helm.sh/hook": pre-install
    "helm.sh/hook-weight": "-5"
    "helm.sh/hook-delete-policy": before-hook-creation
# ... (나머지 Job 정의)
```

## 실행 확인

### Job 상태 확인

```bash
# Job 상태
kubectl get job db-init-v0

# Pod 상태
kubectl get pods -l app=db-init

# 로그 확인
kubectl logs -l app=db-init -f
```

### 성공 확인

```bash
# Job 완료 확인
kubectl get job db-init-v0 -o jsonpath='{.status.succeeded}'
# 출력: 1 (성공)

# 로그에서 성공 메시지 확인
kubectl logs -l app=db-init | grep "Completed Successfully"
```

## 실행 결과

### 성공 시

```
=== Starting V0 Database Initialization ===
Database Host: popcorn-db.xxxxx.ap-northeast-2.rds.amazonaws.com
Database Name: popcorn
Database User: postgres
Testing database connection...
Database is ready. Executing V0__init.sql...
NOTICE:  V0 Global Schema Initialization Completed
=== V0 Database Initialization Completed Successfully ===
```

### 실패 시

```bash
# 로그 확인
kubectl logs -l app=db-init

# 일반적인 오류:
# 1. 연결 실패: RDS 보안 그룹 확인
# 2. 인증 실패: Secret 자격 증명 확인
# 3. SQL 오류: V0__init.sql 스크립트 확인
```

## 재실행

### Job 삭제 후 재실행

```bash
# Job 삭제
kubectl delete job db-init-v0

# ConfigMap 업데이트 (필요시)
kubectl apply -f configmap.yaml

# Job 재실행
kubectl apply -f db-init-job.yaml
```

### 멱등성

V0__init.sql은 멱등성을 보장하도록 작성되어 있습니다:
- `IF NOT EXISTS` 사용
- `DO $$ BEGIN ... END $$` 블록 사용
- 재실행해도 안전

## 검증

### 데이터베이스 접속하여 확인

```bash
# Bastion 또는 로컬에서
psql -h $RDS_ENDPOINT -U postgres -d popcorn

# 스키마 확인
\dn

# 예상 출력:
#   user_auth
#   store
#   orders
#   payment
#   checkIns
#   order_query

# 역할 확인
\du

# 예상 출력:
#   user_auth_app, user_auth_migrator
#   store_app, store_migrator
#   order_app, order_migrator
#   payment_app, payment_migrator
#   qr_app, qr_migrator
#   order_query_app, order_query_migrator
```

### 테이블 확인

```sql
-- 각 스키마별 테이블 확인
SELECT schemaname, tablename 
FROM pg_tables 
WHERE schemaname IN ('user_auth', 'store', 'orders', 'payment', 'checkIns', 'order_query')
ORDER BY schemaname, tablename;
```

## 트러블슈팅

### 1. 연결 실패

```bash
# RDS 엔드포인트 확인
kubectl get secret rds-credentials -o jsonpath='{.data.host}' | base64 -d

# 보안 그룹 확인
aws ec2 describe-security-groups --group-ids <rds-sg-id>

# EKS 노드 보안 그룹 확인
kubectl get nodes -o wide
```

### 2. 권한 오류

```bash
# Secret 확인
kubectl get secret rds-credentials -o yaml

# 마스터 사용자 권한 확인
psql -h $RDS_ENDPOINT -U postgres -c "\du"
```

### 3. SQL 실행 오류

```bash
# ConfigMap 내용 확인
kubectl get configmap db-init-v0-script -o yaml

# 로컬에서 SQL 테스트
psql -h $RDS_ENDPOINT -U postgres -d popcorn -f V0__init.sql
```

## 정리

### Job 삭제

```bash
# Job만 삭제 (ConfigMap 유지)
kubectl delete job db-init-v0

# 모두 삭제
kubectl delete -f db-init-job.yaml
kubectl delete -f configmap.yaml
```

### 자동 정리

Job은 24시간 후 자동 삭제됩니다 (`ttlSecondsAfterFinished: 86400`).

## 프로덕션 고려사항

### 1. 보안

- **비밀번호 변경**: V0__init.sql의 하드코딩된 비밀번호를 변경하세요
- **Secrets Manager 사용**: 역할 비밀번호를 AWS Secrets Manager에 저장
- **최소 권한**: Job에 필요한 최소 권한만 부여

### 2. 백업

```bash
# V0 실행 전 RDS 스냅샷 생성
aws rds create-db-snapshot \
  --db-instance-identifier popcorn-db-prod \
  --db-snapshot-identifier popcorn-db-before-v0-$(date +%Y%m%d)
```

### 3. 모니터링

```bash
# CloudWatch 로그 확인
aws logs tail /aws/rds/instance/popcorn-db-prod/postgresql --follow
```

## 다음 단계

V0 초기화 완료 후:

1. **각 서비스 배포**
   - Flyway가 서비스별 히스토리 테이블 생성
   - V1 이후 마이그레이션 자동 실행

2. **검증**
   ```sql
   -- Flyway 히스토리 테이블 확인
   SELECT tablename FROM pg_tables 
   WHERE tablename LIKE 'flyway_schema_history%';
   ```

3. **애플리케이션 배포**
   ```bash
   # Helm으로 전체 애플리케이션 배포
   helm install popcorn ./helm/popcorn-umbrella -f values-prod.yaml
   ```

## 참고

- V0는 한 번만 실행되어야 합니다
- 각 서비스의 Flyway는 V1부터 시작합니다
- 서비스별 히스토리 테이블로 버전 충돌 방지
