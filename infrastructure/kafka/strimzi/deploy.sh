#!/bin/bash

# Strimzi Kafka 배포 스크립트

set -e

NAMESPACE="kafka"
STRIMZI_VERSION="0.44.0"

echo "=== Strimzi Kafka Operator 배포 시작 ==="

# 1. Namespace 생성 (이미 존재하면 무시)
echo "1. Namespace 확인/생성..."
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# 2. Strimzi Operator 설치
echo "2. Strimzi Operator 설치..."
kubectl create -f "https://strimzi.io/install/latest?namespace=${NAMESPACE}" -n ${NAMESPACE}

# 3. Operator가 준비될 때까지 대기
echo "3. Operator 준비 대기..."
kubectl wait --for=condition=ready pod -l name=strimzi-cluster-operator -n ${NAMESPACE} --timeout=300s

# 4. Kafka 메트릭 ConfigMap 생성
echo "4. Kafka 메트릭 ConfigMap 생성..."
kubectl apply -f kafka-metrics-config.yaml

# 5. Kafka 클러스터 생성
echo "5. Kafka 클러스터 생성..."
kubectl apply -f kafka-cluster.yaml

# 6. Kafka 클러스터가 준비될 때까지 대기
echo "6. Kafka 클러스터 준비 대기 (약 5-10분 소요)..."
kubectl wait kafka/kafka-cluster --for=condition=Ready --timeout=600s -n ${NAMESPACE}

echo ""
echo "=== Strimzi Kafka 배포 완료 ==="
echo ""
echo "Kafka 클러스터 상태 확인:"
echo "  kubectl get kafka -n ${NAMESPACE}"
echo ""
echo "Kafka Pod 상태 확인:"
echo "  kubectl get pods -n ${NAMESPACE}"
echo ""
echo "Kafka 서비스 엔드포인트:"
echo "  Plain: kafka-cluster-kafka-bootstrap.${NAMESPACE}.svc.cluster.local:9092"
echo "  TLS:   kafka-cluster-kafka-bootstrap.${NAMESPACE}.svc.cluster.local:9093"
echo ""
echo "Kafka 토픽 생성 예시:"
echo "  kubectl apply -f - <<EOF"
echo "  apiVersion: kafka.strimzi.io/v1beta2"
echo "  kind: KafkaTopic"
echo "  metadata:"
echo "    name: my-topic"
echo "    namespace: ${NAMESPACE}"
echo "    labels:"
echo "      strimzi.io/cluster: kafka-cluster"
echo "  spec:"
echo "    partitions: 3"
echo "    replicas: 3"
echo "  EOF"
