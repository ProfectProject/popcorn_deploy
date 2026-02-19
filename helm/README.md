# Helm Charts

Popcorn MSA 애플리케이션의 Helm Chart 모음입니다.

## 디렉터리 구조

```
helm/
├── charts/                    # 개별 서비스 차트
│   ├── common/               # 공통 라이브러리 차트
│   ├── gateway/              # API Gateway
│   ├── users/                # User Service
│   ├── stores/               # Store Service
│   ├── order/                # Order Service
│   ├── payment/              # Payment Service
│   ├── frontend/             # Frontend Service
│   ├── orderQuery/           # Order Query Service
│   └── checkIns/             # CheckIn Service
└── popcorn-umbrella/         # Umbrella Chart (통합 관리)
    ├── Chart.yaml
    ├── values.yaml           # 기본 설정
    ├── values-dev.yaml       # 개발 환경
    └── values-prod.yaml      # 운영 환경
```

## 서비스 목록

| 서비스 | 설명 | ECR 이미지 |
|--------|------|-----------|
| gateway | API Gateway (Spring Cloud Gateway) | goorm-popcorn-api-gateway |
| users | 사용자 서비스 | goorm-popcorn-user |
| stores | 스토어 서비스 | goorm-popcorn-store |
| order | 주문 서비스 (Command) | goorm-popcorn-order |
| payment | 결제 서비스 | goorm-popcorn-payment |
| frontend | 프론트엔드 서비스 (Next.js) | goorm-popcorn-front |
| orderQuery | 주문 조회 서비스 (Query, CQRS) | goorm-popcorn-order-query |
| checkIns | 체크인 서비스 (QR 포함) | goorm-popcorn-checkin |

## 차트 구조

### Common Chart (공통 라이브러리)

모든 서비스가 재사용하는 공통 템플릿:
- `_deployment.yaml`: Deployment 템플릿
- `_service.yaml`: Service 템플릿
- `_hpa.yaml`: HorizontalPodAutoscaler 템플릿
- `_serviceaccount.yaml`: ServiceAccount 템플릿
- `_helpers.tpl`: 헬퍼 함수

### 개별 서비스 차트

각 서비스는 다음 구조를 가집니다:
```
service-name/
├── Chart.yaml              # 차트 메타데이터
├── values.yaml             # 기본 설정
└── templates/
    ├── deployment.yaml     # common.deployment 사용
    ├── service.yaml        # common.service 사용
    ├── serviceaccount.yaml # common.serviceaccount 사용
    ├── hpa.yaml           # common.hpa 사용
    └── configmap.yaml     # 서비스별 설정
```

### Umbrella Chart

모든 서비스를 하나의 릴리스로 관리:
- 서비스 간 의존성 정의
- 환경별 설정 오버라이드
- 통합 배포 및 관리

## 사용 방법

### 1. 개별 서비스 배포

```bash
# 특정 서비스만 배포
helm upgrade --install users ./charts/users \
  --namespace popcorn-dev \
  --create-namespace
```

### 2. Umbrella Chart로 전체 배포

```bash
# 개발 환경
helm upgrade --install popcorn-dev ./popcorn-umbrella \
  --namespace popcorn-dev \
  --create-namespace \
  --values ./popcorn-umbrella/values.yaml \
  --values ./popcorn-umbrella/values-dev.yaml

# 운영 환경
helm upgrade --install popcorn-prod ./popcorn-umbrella \
  --namespace popcorn-prod \
  --create-namespace \
  --values ./popcorn-umbrella/values.yaml \
  --values ./popcorn-umbrella/values-prod.yaml
```

### 3. 특정 서비스만 업데이트

```bash
# users 서비스의 이미지 태그만 변경
helm upgrade popcorn-dev ./popcorn-umbrella \
  --namespace popcorn-dev \
  --reuse-values \
  --set users.image.tag=v1.2.3
```

### 4. 특정 서비스 비활성화

```bash
# payment 서비스 비활성화
helm upgrade popcorn-dev ./popcorn-umbrella \
  --namespace popcorn-dev \
  --reuse-values \
  --set payment.enabled=false
```

## 환경별 설정

### 개발 환경 (values-dev.yaml)
- 최소 리소스 (50m CPU, 128Mi Memory)
- 1 replica
- 일부 서비스 비활성화 가능
- Ingress 비활성화 (포트 포워딩 사용)

### 운영 환경 (values-prod.yaml)
- 충분한 리소스 (200m+ CPU, 512Mi+ Memory)
- 2-3 replicas
- 모든 서비스 활성화
- HPA 활성화
- Ingress 활성화 (ALB)

## 커스터마이징

### 리소스 조정

```yaml
# values-prod.yaml
gateway:
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 2000m
      memory: 2Gi
```

### 환경 변수 추가

```yaml
# values.yaml
gateway:
  env:
    CUSTOM_ENV_VAR: "value"
    ANOTHER_VAR: "another-value"
```

### 데이터베이스 연결 변경

```yaml
# values-prod.yaml
global:
  database:
    host: popcorn-db-prod.cluster-xxx.ap-northeast-2.rds.amazonaws.com
    port: 5432
    name: popcorn
```

## 배포 전략

### Rolling Update (기본)
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```

### Blue-Green Deployment
ArgoCD의 Rollout 기능 사용

### Canary Deployment
ArgoCD의 Progressive Delivery 사용

## 트러블슈팅

### Chart 의존성 업데이트
```bash
cd popcorn-umbrella
helm dependency update
```

### Dry-run으로 확인
```bash
helm upgrade --install popcorn-dev ./popcorn-umbrella \
  --namespace popcorn-dev \
  --values values-dev.yaml \
  --dry-run --debug
```

### 템플릿 렌더링 확인
```bash
helm template popcorn-dev ./popcorn-umbrella \
  --values values-dev.yaml \
  > rendered.yaml
```

### 릴리스 히스토리 확인
```bash
helm history popcorn-dev -n popcorn-dev
```

### 롤백
```bash
helm rollback popcorn-dev 1 -n popcorn-dev
```

## 참고 자료

- [Helm 공식 문서](https://helm.sh/docs/)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- [상위 README](../README.md)
- [배포 가이드](../DEPLOYMENT_GUIDE.md)
