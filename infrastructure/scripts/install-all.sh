#!/bin/bash

# 모든 인프라 컴포넌트 설치 스크립트

set -e

ENVIRONMENT=${1:-prod}

echo "=========================================="
echo "Popcorn MSA 인프라 설치 시작"
echo "Environment: $ENVIRONMENT"
echo "=========================================="

# 1. ArgoCD 설치 (GitOps 도구 먼저 설치)
echo ""
echo "1/3: ArgoCD 설치 중..."
./install-argocd.sh $ENVIRONMENT

echo ""
echo "ArgoCD 설치 완료! 잠시 대기 중..."
sleep 10

# 2. Kafka 설치 (이벤트 스트리밍)
echo ""
echo "2/3: Kafka 설치 중..."
./install-kafka.sh $ENVIRONMENT

echo ""
echo "Kafka 설치 완료! 잠시 대기 중..."
sleep 10

# 3. LGTM Stack 설치 (모니터링)
echo ""
echo "3/3: LGTM Stack 설치 중..."
./install-lgtm.sh $ENVIRONMENT

echo ""
echo "=========================================="
echo "모든 인프라 컴포넌트 설치 완료!"
echo "=========================================="

echo ""
echo "설치된 컴포넌트:"
echo "- ArgoCD (namespace: argocd)"
echo "- Kafka + Kafka UI (namespace: kafka)"
echo "- LGTM Stack (namespace: monitoring)"

echo ""
echo "다음 단계:"
echo "1. ArgoCD에서 Popcorn MSA Application 생성"
echo "   kubectl apply -f ../../applications/dev/application.yaml"
echo ""
echo "2. 각 서비스 접속:"
echo "   - ArgoCD: kubectl port-forward -n argocd svc/argocd-server 8080:443"
echo "   - Kafka UI: kubectl port-forward -n kafka svc/kafka-ui 8080:80"
echo "   - Grafana: kubectl port-forward -n monitoring svc/grafana 3000:80"
