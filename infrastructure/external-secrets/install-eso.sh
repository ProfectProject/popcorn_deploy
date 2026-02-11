#!/bin/bash
set -e

# External Secrets Operator 설치 스크립트

ENVIRONMENT=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "External Secrets Operator 설치"
echo "환경: $ENVIRONMENT"
echo "=========================================="

# 환경 검증
if [[ "$ENVIRONMENT" != "dev" && "$ENVIRONMENT" != "prod" ]]; then
    echo "❌ 오류: 환경은 'dev' 또는 'prod'여야 합니다"
    echo "사용법: $0 <dev|prod>"
    exit 1
fi

# kubectl 확인
if ! command -v kubectl &> /dev/null; then
    echo "❌ 오류: kubectl이 설치되어 있지 않습니다"
    exit 1
fi

# helm 확인
if ! command -v helm &> /dev/null; then
    echo "❌ 오류: helm이 설치되어 있지 않습니다"
    exit 1
fi

# 클러스터 연결 확인
echo "📡 클러스터 연결 확인 중..."
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ 오류: Kubernetes 클러스터에 연결할 수 없습니다"
    exit 1
fi

CURRENT_CONTEXT=$(kubectl config current-context)
echo "✅ 현재 컨텍스트: $CURRENT_CONTEXT"

# 확인 프롬프트
read -p "이 컨텍스트에 ESO를 설치하시겠습니까? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ 설치가 취소되었습니다"
    exit 0
fi

# Helm 저장소 추가
echo ""
echo "📦 Helm 저장소 추가 중..."
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

# 네임스페이스 생성
echo ""
echo "📁 네임스페이스 생성 중..."
kubectl create namespace external-secrets --dry-run=client -o yaml | kubectl apply -f -

# ESO 설치
echo ""
echo "🚀 External Secrets Operator 설치 중..."
helm upgrade --install external-secrets \
  external-secrets/external-secrets \
  -n external-secrets \
  -f "$SCRIPT_DIR/values-$ENVIRONMENT.yaml" \
  --wait

# 설치 확인
echo ""
echo "✅ 설치 완료!"
echo ""
echo "📊 설치된 리소스:"
kubectl get pods -n external-secrets
echo ""
kubectl get crds | grep external-secrets

echo ""
echo "=========================================="
echo "다음 단계:"
echo "=========================================="
echo "1. SecretStore 생성:"
echo "   kubectl apply -f $SCRIPT_DIR/secretstore-$ENVIRONMENT.yaml"
echo ""
echo "2. ExternalSecret 생성:"
echo "   kubectl apply -f $SCRIPT_DIR/externalsecrets/"
echo ""
echo "3. Secret 생성 확인:"
echo "   kubectl get secrets"
echo ""
