#!/bin/bash

# AWS Secrets Manager에 시크릿 생성 스크립트
# 사용법: ./create-secrets.sh <environment>
# 예시: ./create-secrets.sh prod

set -e

ENVIRONMENT=${1:-prod}
REGION="ap-northeast-2"
PREFIX="/goorm-popcorn/${ENVIRONMENT}"

echo "🔐 Creating secrets for environment: ${ENVIRONMENT}"
echo "📍 Region: ${REGION}"
echo "📂 Prefix: ${PREFIX}"
echo ""

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 시크릿 생성 함수
create_secret() {
  local secret_name=$1
  local secret_value=$2
  local description=$3

  echo -n "Creating ${secret_name}... "
  
  # 시크릿이 이미 존재하는지 확인
  if aws secretsmanager describe-secret \
    --secret-id "${secret_name}" \
    --region "${REGION}" &>/dev/null; then
    echo -e "${YELLOW}Already exists${NC}"
    
    # 값 업데이트
    aws secretsmanager put-secret-value \
      --secret-id "${secret_name}" \
      --secret-string "${secret_value}" \
      --region "${REGION}" &>/dev/null
    echo -e "  ${GREEN}✓ Updated${NC}"
  else
    # 새로 생성
    aws secretsmanager create-secret \
      --name "${secret_name}" \
      --description "${description}" \
      --secret-string "${secret_value}" \
      --region "${REGION}" &>/dev/null
    echo -e "${GREEN}✓ Created${NC}"
  fi
}

# RDS 마스터 비밀번호 생성
echo "📦 1. RDS Master Password"
RDS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
create_secret \
  "${PREFIX}/rds/master-password" \
  "${RDS_PASSWORD}" \
  "RDS PostgreSQL master password for ${ENVIRONMENT}"

# ElastiCache Auth Token 생성
echo ""
echo "📦 2. ElastiCache Auth Token"
REDIS_TOKEN=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
create_secret \
  "${PREFIX}/elasticache/auth-token" \
  "${REDIS_TOKEN}" \
  "ElastiCache Valkey auth token for ${ENVIRONMENT}"

# JWT Secret Key 생성
echo ""
echo "📦 3. JWT Secret Key"
JWT_SECRET=$(openssl rand -base64 64 | tr -d "=+/" | cut -c1-64)
create_secret \
  "${PREFIX}/jwt/secret-key" \
  "${JWT_SECRET}" \
  "JWT secret key for user authentication in ${ENVIRONMENT}"

# Passport Secret Key 생성
echo ""
echo "📦 4. Passport Secret Key"
PASSPORT_SECRET=$(openssl rand -base64 64 | tr -d "=+/" | cut -c1-64)
create_secret \
  "${PREFIX}/passport/secret-key" \
  "${PASSPORT_SECRET}" \
  "Passport secret key for service-to-service communication in ${ENVIRONMENT}"

# Payment API Keys 생성 (JSON 형식)
echo ""
echo "📦 5. Payment API Keys"
PAYMENT_JSON=$(cat <<EOF
{
  "toss_client_key": "test_ck_$(openssl rand -hex 16)",
  "toss_secret_key": "test_sk_$(openssl rand -hex 16)"
}
EOF
)
create_secret \
  "${PREFIX}/external-apis/payment" \
  "${PAYMENT_JSON}" \
  "Payment gateway API keys for ${ENVIRONMENT}"

# Database Users 생성 (JSON 형식)
echo ""
echo "📦 6. Database Users Credentials"
DB_USERS_JSON=$(cat <<EOF
{
  "user_auth_username": "user_auth_app",
  "user_auth_password": "$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-20)",
  "user_auth_flyway_username": "user_auth_migrator",
  "user_auth_flyway_password": "$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-20)",
  "order_username": "order_app",
  "order_password": "$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-20)",
  "order_flyway_username": "order_migrator",
  "order_flyway_password": "$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-20)",
  "payment_username": "payment_app",
  "payment_password": "$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-20)",
  "payment_flyway_username": "payment_migrator",
  "payment_flyway_password": "$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-20)",
  "store_username": "store_app",
  "store_password": "$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-20)",
  "store_flyway_username": "store_migrator",
  "store_flyway_password": "$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-20)",
  "qr_username": "qr_app",
  "qr_password": "$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-20)",
  "qr_flyway_username": "qr_migrator",
  "qr_flyway_password": "$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-20)"
}
EOF
)
create_secret \
  "${PREFIX}/database/users" \
  "${DB_USERS_JSON}" \
  "Database user credentials for all microservices in ${ENVIRONMENT}"

echo ""
echo -e "${GREEN}✅ All secrets created successfully!${NC}"
echo ""
echo "📋 Created secrets:"
echo "  1. ${PREFIX}/rds/master-password"
echo "  2. ${PREFIX}/elasticache/auth-token"
echo "  3. ${PREFIX}/jwt/secret-key"
echo "  4. ${PREFIX}/passport/secret-key"
echo "  5. ${PREFIX}/external-apis/payment"
echo "  6. ${PREFIX}/database/users"
echo ""
echo "🔍 Verify secrets:"
echo "  aws secretsmanager list-secrets --region ${REGION} --query 'SecretList[?starts_with(Name, \`${PREFIX}\`)].Name'"
echo ""
echo -e "${YELLOW}⚠️  Important: Save these secrets in a secure location!${NC}"
