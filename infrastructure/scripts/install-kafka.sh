#!/bin/bash

# Kafka 및 Kafka UI 설치 스크립트

set -e

NAMESPACE="kafka"
ENVIRONMENT=${1:-prod}

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
helm upgrade --install kafka bitnami/kafka \
  --namespace $NAMESPACE \
  --values ../kafka/kafka/values.yaml \
  --values ../kafka/kafka/values-${ENVIRONMENT}.yaml \
  --wait \
  --timeout 10m

echo "Kafka 설치 완료!"

# Kafka UI 설치
echo "Kafka UI 설치 중..."
helm upgrade --install kafka-ui kafka-ui/kafka-ui \
  --namespace $NAMESPACE \
  --values ../kafka/kafka-ui/values.yaml \
  --values ../kafka/kafka-ui/values-${ENVIRONMENT}.yaml \
  --wait

echo "=========================================="
echo "Kafka Ecosystem 설치 완료!"
echo "=========================================="

echo ""
echo "Kafka 접속 정보:"
echo "Internal: kafka:9092"
echo ""
echo "Kafka UI 접속:"
echo "kubectl port-forward -n $NAMESPACE svc/kafka-ui 8080:80"
echo "URL: http://localhost:8080"
