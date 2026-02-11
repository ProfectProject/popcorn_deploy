#!/bin/bash
# V0 데이터베이스 초기화 배포 스크립트

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="${NAMESPACE:-default}"

echo "=== V0 Database Initialization Deployment ==="
echo "Namespace: $NAMESPACE"
echo "Script Directory: $SCRIPT_DIR"
echo ""

# 사전 확인
echo "1. Checking prerequisites..."

# RDS Secret 확인
if ! kubectl get secret rds-credentials -n $NAMESPACE &>/dev/null; then
    echo "❌ Error: rds-credentials secret not found in namespace $NAMESPACE"
    echo "Please ensure External Secrets is configured and synced."
    exit 1
fi
echo "✅ RDS credentials secret found"

# V0__init.sql 파일 확인
if [ ! -f "$SCRIPT_DIR/V0__init.sql" ]; then
    echo "❌ Error: V0__init.sql not found in $SCRIPT_DIR"
    exit 1
fi
echo "✅ V0__init.sql file found"

# 기존 Job 확인 및 삭제
echo ""
echo "2. Checking for existing Job..."
if kubectl get job db-init-v0 -n $NAMESPACE &>/dev/null; then
    echo "⚠️  Existing Job found. Deleting..."
    kubectl delete job db-init-v0 -n $NAMESPACE
    echo "✅ Existing Job deleted"
else
    echo "✅ No existing Job found"
fi

# ConfigMap 생성
echo ""
echo "3. Creating ConfigMap from V0__init.sql..."
kubectl create configmap db-init-v0-script \
    --from-file=V0__init.sql="$SCRIPT_DIR/V0__init.sql" \
    --namespace=$NAMESPACE \
    --dry-run=client -o yaml | kubectl apply -f -

if [ $? -eq 0 ]; then
    echo "✅ ConfigMap created/updated"
else
    echo "❌ Failed to create ConfigMap"
    exit 1
fi

# Job 배포
echo ""
echo "4. Deploying Job..."
kubectl apply -f "$SCRIPT_DIR/db-init-job.yaml" -n $NAMESPACE

if [ $? -eq 0 ]; then
    echo "✅ Job deployed"
else
    echo "❌ Failed to deploy Job"
    exit 1
fi

# Job 상태 모니터링
echo ""
echo "5. Monitoring Job execution..."
echo "Waiting for Job to complete (timeout: 5 minutes)..."

# 5분 동안 Job 완료 대기
timeout=300
elapsed=0
interval=5

while [ $elapsed -lt $timeout ]; do
    status=$(kubectl get job db-init-v0 -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>/dev/null)
    failed=$(kubectl get job db-init-v0 -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' 2>/dev/null)
    
    if [ "$status" == "True" ]; then
        echo ""
        echo "✅ Job completed successfully!"
        break
    elif [ "$failed" == "True" ]; then
        echo ""
        echo "❌ Job failed!"
        echo ""
        echo "=== Job Logs ==="
        kubectl logs -l app=db-init -n $NAMESPACE --tail=50
        exit 1
    fi
    
    echo -n "."
    sleep $interval
    elapsed=$((elapsed + interval))
done

if [ $elapsed -ge $timeout ]; then
    echo ""
    echo "⚠️  Job did not complete within timeout"
    echo ""
    echo "=== Job Status ==="
    kubectl get job db-init-v0 -n $NAMESPACE
    echo ""
    echo "=== Pod Status ==="
    kubectl get pods -l app=db-init -n $NAMESPACE
    echo ""
    echo "=== Recent Logs ==="
    kubectl logs -l app=db-init -n $NAMESPACE --tail=50
    exit 1
fi

# 로그 출력
echo ""
echo "=== Job Logs ==="
kubectl logs -l app=db-init -n $NAMESPACE

# 검증
echo ""
echo "6. Verifying database initialization..."
echo "Please manually verify the database schemas:"
echo ""
echo "  psql -h \$RDS_ENDPOINT -U postgres -d popcorn -c '\\dn'"
echo ""
echo "Expected schemas:"
echo "  - user_auth"
echo "  - store"
echo "  - orders"
echo "  - payment"
echo "  - checkIns"
echo "  - order_query"
echo ""

echo "=== V0 Database Initialization Completed ==="
echo ""
echo "Next steps:"
echo "1. Verify schemas in database"
echo "2. Deploy application services"
echo "3. Flyway will create service-specific history tables"
