#!/bin/bash

# AWS Secrets Manager에 시크릿 생성 스크립트
# 사용법: ./create-secrets.sh <environment>
# 예시: ./create-secrets.sh prod

set -e

ENVIRONMENT=${1:-prod}
REGION="ap-northeast-2"
PREFIX="/goorm-popcorn/${ENVIRONMENT}"

if [[ "$ENVIRONMENT" == "prod" ]]; then
  DEFAULT_RDS_HOST="goorm-popcorn-prod-postgres.cds4g0gykt3t.ap-northeast-2.rds.amazonaws.com"
  DEFAULT_RDS_PORT="5432"
  DEFAULT_RDS_DATABASE="popcorn"
  DEFAULT_RDS_USERNAME="postgres"
  DEFAULT_REDIS_HOST="master.goorm-popcorn-cache-prod.mkltth.apn2.cache.amazonaws.com"
  DEFAULT_REDIS_PORT="6379"
else
  DEFAULT_RDS_HOST="postgres.popcorn-dev.svc.cluster.local"
  DEFAULT_RDS_PORT="5432"
  DEFAULT_RDS_DATABASE="popcorn"
  DEFAULT_RDS_USERNAME="postgres"
  DEFAULT_REDIS_HOST="redis.popcorn-dev.svc.cluster.local"
  DEFAULT_REDIS_PORT="6379"
fi

RDS_HOST="${RDS_HOST:-$DEFAULT_RDS_HOST}"
RDS_PORT="${RDS_PORT:-$DEFAULT_RDS_PORT}"
RDS_DATABASE="${RDS_DATABASE:-$DEFAULT_RDS_DATABASE}"
RDS_USERNAME="${RDS_USERNAME:-$DEFAULT_RDS_USERNAME}"
REDIS_HOST="${REDIS_HOST:-$DEFAULT_REDIS_HOST}"
REDIS_PORT="${REDIS_PORT:-$DEFAULT_REDIS_PORT}"

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
RDS_JSON=$(cat <<EOF
{
  "host": "${RDS_HOST}",
  "port": "${RDS_PORT}",
  "database": "${RDS_DATABASE}",
  "username": "${RDS_USERNAME}",
  "password": "${RDS_PASSWORD}"
}
EOF
)
create_secret \
  "${PREFIX}/rds/master-password" \
  "${RDS_JSON}" \
  "RDS PostgreSQL credentials for ${ENVIRONMENT}"

# ElastiCache Auth Token 생성
echo ""
echo "📦 2. ElastiCache Auth Token"
REDIS_TOKEN=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
REDIS_JSON=$(cat <<EOF
{
  "host": "${REDIS_HOST}",
  "port": "${REDIS_PORT}",
  "password": "${REDIS_TOKEN}"
}
EOF
)
create_secret \
  "${PREFIX}/elasticache/auth-token" \
  "${REDIS_JSON}" \
  "ElastiCache Valkey credentials for ${ENVIRONMENT}"

# JWT Secret Key 생성
echo ""
echo "📦 3. JWT Secret Key"
JWT_SECRET=$(openssl rand -base64 64 | tr -d '\n' | tr -d "=+/" | cut -c1-64)
JWT_JSON=$(cat <<EOF
{
  "secret": "${JWT_SECRET}",
  "expiration": "3600000",
  "refresh_expiration": "604800000"
}
EOF
)
create_secret \
  "${PREFIX}/jwt/secret-key" \
  "${JWT_JSON}" \
  "JWT secret payload for user authentication in ${ENVIRONMENT}"

# Passport Secret Key 생성
echo ""
echo "📦 4. Passport Secret Key"
PASSPORT_SECRET=$(openssl rand -base64 64 | tr -d '\n' | tr -d "=+/" | cut -c1-64)
PASSPORT_JSON=$(cat <<EOF
{
  "secret": "${PASSPORT_SECRET}",
  "ttl_seconds": "60"
}
EOF
)
create_secret \
  "${PREFIX}/passport/secret-key" \
  "${PASSPORT_JSON}" \
  "Passport secret payload for service-to-service communication in ${ENVIRONMENT}"

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
  "user_auth_username": "${USER_AUTH_USERNAME:-user_auth_app}",
  "user_auth_password": "${USER_AUTH_PASSWORD:-$(openssl rand -base64 24 | tr -d '=+/' | cut -c1-20)}",
  "user_auth_flyway_username": "${USER_AUTH_FLYWAY_USERNAME:-user_auth_migrator}",
  "user_auth_flyway_password": "${USER_AUTH_FLYWAY_PASSWORD:-$(openssl rand -base64 24 | tr -d '=+/' | cut -c1-20)}",
  "order_username": "${ORDER_USERNAME:-order_app}",
  "order_password": "${ORDER_PASSWORD:-$(openssl rand -base64 24 | tr -d '=+/' | cut -c1-20)}",
  "order_flyway_username": "${ORDER_FLYWAY_USERNAME:-order_migrator}",
  "order_flyway_password": "${ORDER_FLYWAY_PASSWORD:-$(openssl rand -base64 24 | tr -d '=+/' | cut -c1-20)}",
  "payment_username": "${PAYMENT_USERNAME:-payment_app}",
  "payment_password": "${PAYMENT_PASSWORD:-$(openssl rand -base64 24 | tr -d '=+/' | cut -c1-20)}",
  "payment_flyway_username": "${PAYMENT_FLYWAY_USERNAME:-payment_migrator}",
  "payment_flyway_password": "${PAYMENT_FLYWAY_PASSWORD:-$(openssl rand -base64 24 | tr -d '=+/' | cut -c1-20)}",
  "store_username": "${STORE_USERNAME:-store_app}",
  "store_password": "${STORE_PASSWORD:-$(openssl rand -base64 24 | tr -d '=+/' | cut -c1-20)}",
  "store_flyway_username": "${STORE_FLYWAY_USERNAME:-store_migrator}",
  "store_flyway_password": "${STORE_FLYWAY_PASSWORD:-$(openssl rand -base64 24 | tr -d '=+/' | cut -c1-20)}",
  "qr_username": "${QR_USERNAME:-qr_app}",
  "qr_password": "${QR_PASSWORD:-$(openssl rand -base64 24 | tr -d '=+/' | cut -c1-20)}",
  "qr_flyway_username": "${QR_FLYWAY_USERNAME:-qr_migrator}",
  "qr_flyway_password": "${QR_FLYWAY_PASSWORD:-$(openssl rand -base64 24 | tr -d '=+/' | cut -c1-20)}",
  "order_query_username": "${ORDER_QUERY_USERNAME:-order_query_app}",
  "order_query_password": "${ORDER_QUERY_PASSWORD:-$(openssl rand -base64 24 | tr -d '=+/' | cut -c1-20)}",
  "order_query_flyway_username": "${ORDER_QUERY_FLYWAY_USERNAME:-order_query_migrator}",
  "order_query_flyway_password": "${ORDER_QUERY_FLYWAY_PASSWORD:-$(openssl rand -base64 24 | tr -d '=+/' | cut -c1-20)}",
  "coupon_username": "${COUPON_USERNAME:-coupon_app}",
  "coupon_password": "${COUPON_PASSWORD:-$(openssl rand -base64 24 | tr -d '=+/' | cut -c1-20)}",
  "coupon_flyway_username": "${COUPON_FLYWAY_USERNAME:-coupon_migrator}",
  "coupon_flyway_password": "${COUPON_FLYWAY_PASSWORD:-$(openssl rand -base64 24 | tr -d '=+/' | cut -c1-20)}"
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
