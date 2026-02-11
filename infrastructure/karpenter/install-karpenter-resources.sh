#!/bin/bash

# Karpenter NodePool 및 EC2NodeClass 설치 스크립트
# 사용법: ./install-karpenter-resources.sh <environment>
# 예시: ./install-karpenter-resources.sh prod

set -e

ENVIRONMENT=${1:-prod}

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Karpenter Resources Installation${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "Environment: ${GREEN}${ENVIRONMENT}${NC}"
echo ""

# 환경 검증
if [[ "$ENVIRONMENT" != "dev" && "$ENVIRONMENT" != "prod" ]]; then
  echo -e "${RED}❌ Invalid environment: ${ENVIRONMENT}${NC}"
  echo "Usage: $0 <dev|prod>"
  exit 1
fi

# kubectl 확인
if ! command -v kubectl &> /dev/null; then
  echo -e "${RED}❌ kubectl not found${NC}"
  exit 1
fi

# 클러스터 연결 확인
echo -e "${YELLOW}🔍 Checking cluster connection...${NC}"
if ! kubectl cluster-info &> /dev/null; then
  echo -e "${RED}❌ Cannot connect to Kubernetes cluster${NC}"
  echo "Please configure kubectl first:"
  echo "  aws eks update-kubeconfig --region ap-northeast-2 --name goorm-popcorn-${ENVIRONMENT}"
  exit 1
fi
echo -e "${GREEN}✓ Connected to cluster${NC}"
echo ""

# Karpenter 설치 확인
echo -e "${YELLOW}🔍 Checking Karpenter installation...${NC}"
if ! kubectl get deployment -n karpenter karpenter &> /dev/null; then
  echo -e "${RED}❌ Karpenter not installed${NC}"
  echo "Please install Karpenter first using Terraform:"
  echo "  cd popcorn-terraform-feature/envs/${ENVIRONMENT}"
  echo "  terraform apply"
  exit 1
fi
echo -e "${GREEN}✓ Karpenter is installed${NC}"
echo ""

# Karpenter Pod 상태 확인
echo -e "${YELLOW}🔍 Checking Karpenter pods...${NC}"
KARPENTER_READY=$(kubectl get pods -n karpenter -l app.kubernetes.io/name=karpenter -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' | grep -o "True" | wc -l)
if [ "$KARPENTER_READY" -eq 0 ]; then
  echo -e "${RED}❌ Karpenter pods are not ready${NC}"
  kubectl get pods -n karpenter
  exit 1
fi
echo -e "${GREEN}✓ Karpenter pods are ready${NC}"
echo ""

# EC2NodeClass 적용
echo -e "${YELLOW}📦 Applying EC2NodeClass...${NC}"
if kubectl apply -f ec2nodeclass-${ENVIRONMENT}.yaml; then
  echo -e "${GREEN}✓ EC2NodeClass applied${NC}"
else
  echo -e "${RED}❌ Failed to apply EC2NodeClass${NC}"
  exit 1
fi
echo ""

# EC2NodeClass 상태 확인
echo -e "${YELLOW}🔍 Waiting for EC2NodeClass to be ready...${NC}"
for i in {1..30}; do
  if kubectl get ec2nodeclass default &> /dev/null; then
    echo -e "${GREEN}✓ EC2NodeClass is ready${NC}"
    break
  fi
  if [ $i -eq 30 ]; then
    echo -e "${RED}❌ EC2NodeClass not ready after 30 seconds${NC}"
    kubectl describe ec2nodeclass default
    exit 1
  fi
  sleep 1
done
echo ""

# NodePool 적용
echo -e "${YELLOW}📦 Applying NodePool...${NC}"
if kubectl apply -f nodepool-${ENVIRONMENT}.yaml; then
  echo -e "${GREEN}✓ NodePool applied${NC}"
else
  echo -e "${RED}❌ Failed to apply NodePool${NC}"
  exit 1
fi
echo ""

# NodePool 상태 확인
echo -e "${YELLOW}🔍 Waiting for NodePool to be ready...${NC}"
for i in {1..30}; do
  if kubectl get nodepool default &> /dev/null; then
    echo -e "${GREEN}✓ NodePool is ready${NC}"
    break
  fi
  if [ $i -eq 30 ]; then
    echo -e "${RED}❌ NodePool not ready after 30 seconds${NC}"
    kubectl describe nodepool default
    exit 1
  fi
  sleep 1
done
echo ""

# 리소스 상태 출력
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Resource Status${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${YELLOW}EC2NodeClass:${NC}"
kubectl get ec2nodeclass
echo ""

echo -e "${YELLOW}NodePool:${NC}"
kubectl get nodepool
echo ""

echo -e "${YELLOW}Karpenter Pods:${NC}"
kubectl get pods -n karpenter
echo ""

# 완료 메시지
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Karpenter resources installed successfully!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${YELLOW}📋 Next steps:${NC}"
echo "  1. Deploy a test workload:"
echo "     kubectl apply -f test-workload.yaml"
echo ""
echo "  2. Monitor Karpenter logs:"
echo "     kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter -f"
echo ""
echo "  3. Check node provisioning:"
echo "     kubectl get nodes -l karpenter.sh/capacity-type=spot"
echo ""
echo "  4. View NodePool status:"
echo "     kubectl describe nodepool default"
echo ""
