#!/bin/bash

# OpenTelemetry Collector 설치 스크립트

set -e

NAMESPACE="monitoring"
ENVIRONMENT=${1:-prod}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VALUES_DIR="${SCRIPT_DIR}/../otel"

echo "=========================================="
echo "OpenTelemetry Collector 설치 시작"
echo "Environment: $ENVIRONMENT"
echo "=========================================="

echo "Helm Repository 추가 중..."
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts >/dev/null 2>&1 || true
helm repo update

echo "Namespace 생성 중..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

echo "OpenTelemetry Collector 설치 중..."
helm upgrade --install otel-collector open-telemetry/opentelemetry-collector \
  --namespace $NAMESPACE \
  --values "${VALUES_DIR}/values.yaml" \
  --values "${VALUES_DIR}/values-${ENVIRONMENT}.yaml" \
  --wait \
  --timeout 10m

echo "=========================================="
echo "OpenTelemetry Collector 설치 완료"
echo "=========================================="

echo ""
echo "확인 명령어:"
echo "kubectl get pods -n $NAMESPACE | grep otel-collector"
echo "kubectl logs -n $NAMESPACE deploy/otel-collector-opentelemetry-collector --tail=100"
