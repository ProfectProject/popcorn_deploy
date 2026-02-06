#!/bin/bash

# LGTM Stack 설치 스크립트

set -e

NAMESPACE="monitoring"
ENVIRONMENT=${1:-prod}

echo "=========================================="
echo "LGTM Stack 설치 시작"
echo "Environment: $ENVIRONMENT"
echo "=========================================="

# Helm Repository 추가
echo "Helm Repository 추가 중..."
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Namespace 생성
echo "Namespace 생성 중..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Loki 설치
echo "Loki 설치 중..."
helm upgrade --install loki grafana/loki \
  --namespace $NAMESPACE \
  --values ../lgtm/loki/values.yaml \
  --values ../lgtm/loki/values-${ENVIRONMENT}.yaml \
  --wait

echo "Loki 설치 완료!"

# Tempo 설치
echo "Tempo 설치 중..."
helm upgrade --install tempo grafana/tempo \
  --namespace $NAMESPACE \
  --values ../lgtm/tempo/values.yaml \
  --values ../lgtm/tempo/values-${ENVIRONMENT}.yaml \
  --wait

echo "Tempo 설치 완료!"

# Mimir 설치
echo "Mimir 설치 중..."
helm upgrade --install mimir grafana/mimir-distributed \
  --namespace $NAMESPACE \
  --values ../lgtm/mimir/values.yaml \
  --values ../lgtm/mimir/values-${ENVIRONMENT}.yaml \
  --wait \
  --timeout 10m

echo "Mimir 설치 완료!"

# Grafana 설치
echo "Grafana 설치 중..."
helm upgrade --install grafana grafana/grafana \
  --namespace $NAMESPACE \
  --values ../lgtm/grafana/values.yaml \
  --values ../lgtm/grafana/values-${ENVIRONMENT}.yaml \
  --wait

echo "=========================================="
echo "LGTM Stack 설치 완료!"
echo "=========================================="

# Grafana 접속 정보
echo ""
echo "Grafana 접속 정보:"
echo "URL: http://localhost:3000"
echo "Username: admin"
echo -n "Password: "
kubectl get secret -n $NAMESPACE grafana -o jsonpath="{.data.admin-password}" 2>/dev/null | base64 -d || echo "비밀번호를 가져올 수 없습니다."
echo ""

echo ""
echo "포트 포워딩 명령어:"
echo "kubectl port-forward -n $NAMESPACE svc/grafana 3000:80"
