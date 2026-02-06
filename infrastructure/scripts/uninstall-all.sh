#!/bin/bash

# 모든 인프라 컴포넌트 제거 스크립트

set -e

echo "=========================================="
echo "Popcorn MSA 인프라 제거 시작"
echo "=========================================="

read -p "정말로 모든 인프라를 제거하시겠습니까? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "취소되었습니다."
    exit 0
fi

# LGTM Stack 제거
echo ""
echo "LGTM Stack 제거 중..."
helm uninstall grafana -n monitoring || true
helm uninstall mimir -n monitoring || true
helm uninstall tempo -n monitoring || true
helm uninstall loki -n monitoring || true

# Kafka 제거
echo ""
echo "Kafka 제거 중..."
helm uninstall kafka-ui -n kafka || true
helm uninstall kafka -n kafka || true

# ArgoCD 제거
echo ""
echo "ArgoCD 제거 중..."
helm uninstall argocd -n argocd || true

# Namespace 제거 (선택사항)
read -p "Namespace도 제거하시겠습니까? (yes/no): " delete_ns
if [ "$delete_ns" = "yes" ]; then
    echo "Namespace 제거 중..."
    kubectl delete namespace monitoring --ignore-not-found=true
    kubectl delete namespace kafka --ignore-not-found=true
    kubectl delete namespace argocd --ignore-not-found=true
fi

echo ""
echo "=========================================="
echo "인프라 제거 완료!"
echo "=========================================="
