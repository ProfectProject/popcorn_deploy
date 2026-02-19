#!/bin/bash

# Kafka 및 Kafka UI 설치 스크립트

set -e

NAMESPACE="kafka"
KAFKA_RELEASE_NAME="kafka-prod"
KAFKA_UI_RELEASE_NAME="kafka-ui"
ENVIRONMENT=${1:-prod}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KAFKA_VALUES_DIR="${SCRIPT_DIR}/../kafka/kafka"
KAFKA_UI_VALUES_DIR="${SCRIPT_DIR}/../kafka/kafka-ui"

KAFKA_BASE_VALUES="${KAFKA_VALUES_DIR}/values.yaml"
KAFKA_ENV_VALUES="${KAFKA_VALUES_DIR}/values-${ENVIRONMENT}.yaml"
KAFKA_UI_BASE_VALUES="${KAFKA_UI_VALUES_DIR}/values.yaml"
KAFKA_UI_ENV_VALUES="${KAFKA_UI_VALUES_DIR}/values-${ENVIRONMENT}.yaml"

for file in "${KAFKA_BASE_VALUES}" "${KAFKA_ENV_VALUES}" "${KAFKA_UI_BASE_VALUES}" "${KAFKA_UI_ENV_VALUES}"; do
  if [[ ! -f "${file}" ]]; then
    echo "필수 values 파일이 없습니다: ${file}"
    exit 1
  fi
done

echo "=========================================="
echo "Kafka Ecosystem 설치 시작"
echo "Environment: $ENVIRONMENT"
echo "=========================================="

# Helm Repository 추가
echo "Helm Repository 추가 중..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add kafka-ui https://provectus.github.io/kafka-ui-charts
helm repo update

# Namespace 생성
echo "Namespace 생성 중..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Kafka 설치
echo "Kafka 설치 중..."
helm upgrade --install "$KAFKA_RELEASE_NAME" bitnami/kafka \
  --namespace $NAMESPACE \
  --values "${KAFKA_BASE_VALUES}" \
  --values "${KAFKA_ENV_VALUES}" \
  --wait \
  --timeout 10m

echo "Kafka 설치 완료!"

# Kafka UI 설치
echo "Kafka UI 설치 중..."
helm upgrade --install "$KAFKA_UI_RELEASE_NAME" kafka-ui/kafka-ui \
  --namespace $NAMESPACE \
  --values "${KAFKA_UI_BASE_VALUES}" \
  --values "${KAFKA_UI_ENV_VALUES}" \
  --wait

echo "=========================================="
echo "Kafka Ecosystem 설치 완료!"
echo "=========================================="

echo ""
echo "Kafka 접속 정보:"
echo "Internal: ${KAFKA_RELEASE_NAME}:9092"
echo "KRaft 상태 확인: kubectl exec -n $NAMESPACE ${KAFKA_RELEASE_NAME}-controller-0 -- kafka-metadata-quorum.sh --bootstrap-controller localhost:9093 describe --status"
echo ""
echo "Kafka UI 접속:"
echo "kubectl port-forward -n $NAMESPACE svc/kafka-ui 8080:80"
echo "URL: http://localhost:8080"
