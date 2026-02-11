#!/bin/bash

# AWS Secrets Manager 시크릿 검증 스크립트
# 사용법: ./verify-secrets.sh <environment>
# 예시: ./verify-secrets.sh prod

set -e

ENVIRONMENT=${1:-prod}
REGION="ap-northeast-2"
PREFIX="/goorm-popcorn/${ENVIRONMENT}"

# 색상 정의
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔍 Verifying secrets for environment: ${ENVIRONMENT}"
echo "📍 Region: ${REGION}"
echo "📂 Prefix: ${PREFIX}"
echo ""

# 시크릿 검증 함수
verify_secret() {
  local secret_name=$1
  local description=$2

  echo -n "Checking ${secret_name}... "
  
  if aws secretsmanager describe-secret \
    --secret-id "${secret_name}" \
    --region "${REGION}" &>/dev/null; then
    echo -e "${GREEN}✓ Exists${NC}"
    
    # 값 확인 (마스킹)
    local value=$(aws secretsmanager get-secret-value \
      --secret-id "${secret_name}" \
      --region "${REGION}" \
      --query 'SecretString' \
      --output text 2>/dev/null)
    
    if [ -n "$value" ]; then
      local length=${#value}
      echo -e "  ${GREEN}✓ Has value (${length} characters)${NC}"
    else
      echo -e "  ${RED}✗ Empty value${NC}"
      return 1
    fi
  else
    echo -e "${RED}✗ Not found${NC}"
    return 1
  fi
}

# 필수 시크릿 목록
SECRETS=(
  "${PREFIX}/rds/master-password:RDS PostgreSQL master password"
  "${PREFIX}/elasticache/auth-token:ElastiCache Valkey auth token"
  "${PREFIX}/jwt/secret-key:JWT secret key"
  "${PREFIX}/passport/secret-key:Passport secret key"
  "${PREFIX}/external-apis/payment:Payment API keys"
  "${PREFIX}/database/users:Database user credentials"
)

# 검증 실행
FAILED=0
for secret_info in "${SECRETS[@]}"; do
  IFS=':' read -r secret_name description <<< "$secret_info"
  if ! verify_secret "$secret_name" "$description"; then
    FAILED=$((FAILED + 1))
  fi
  echo ""
done

# 결과 출력
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}✅ All secrets verified successfully!${NC}"
else
  echo -e "${RED}❌ ${FAILED} secret(s) failed verification${NC}"
  echo ""
  echo "To create missing secrets, run:"
  echo "  ./create-secrets.sh ${ENVIRONMENT}"
  exit 1
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
