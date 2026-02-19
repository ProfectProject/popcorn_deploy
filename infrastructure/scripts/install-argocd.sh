#!/bin/bash

# ArgoCD 설치 스크립트

set -e

NAMESPACE="argocd"
RELEASE_NAME="argocd"
ENVIRONMENT=${1:-prod}

echo "=========================================="
echo "ArgoCD 설치 시작"
echo "Environment: $ENVIRONMENT"
echo "=========================================="

# Helm Repository 추가
echo "Helm Repository 추가 중..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Namespace 생성
echo "Namespace 생성 중..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# ArgoCD 설치
echo "ArgoCD 설치 중..."
helm upgrade --install $RELEASE_NAME argo/argo-cd \
  --namespace $NAMESPACE \
  --values ../argocd/values.yaml \
  --values ../argocd/values-${ENVIRONMENT}.yaml \
  --wait

echo "=========================================="
echo "ArgoCD 설치 완료!"
echo "=========================================="

# 초기 비밀번호 확인
echo ""
echo "ArgoCD 접속 정보:"
echo "URL: http://localhost:8080"
echo "Username: admin"
echo -n "Password: "
kubectl -n $NAMESPACE get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "비밀번호를 가져올 수 없습니다."
echo ""

echo ""
echo "포트 포워딩 명령어:"
echo "kubectl port-forward -n $NAMESPACE svc/argocd-server 8080:80"
