#!/bin/bash
# V0__init.sql을 ConfigMap으로 생성하는 스크립트

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
V0_SQL_PATH="${SCRIPT_DIR}/../../../popcorn_msa/V0._init.sql"

if [ ! -f "$V0_SQL_PATH" ]; then
    echo "❌ V0__init.sql 파일을 찾을 수 없습니다: $V0_SQL_PATH"
    exit 1
fi

echo "📝 V0__init.sql을 ConfigMap으로 생성합니다..."

kubectl create configmap db-init-v0-script \
    --from-file=V0__init.sql="$V0_SQL_PATH" \
    --namespace=default \
    --dry-run=client \
    -o yaml | kubectl apply -f -

if [ $? -eq 0 ]; then
    echo "✅ ConfigMap 생성 완료"
    echo ""
    echo "다음 명령으로 Job을 실행하세요:"
    echo "  kubectl apply -f db-init-job.yaml"
else
    echo "❌ ConfigMap 생성 실패"
    exit 1
fi
