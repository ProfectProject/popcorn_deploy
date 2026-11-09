# Popcorn MSA Deployment

Popcorn MSA 애플리케이션의 Kubernetes 배포를 위한 Helm Chart 및 인프라 관리 저장소입니다.

> 📚 **문서 찾기**: 모든 문서의 위치와 용도는 [README_INDEX.md](README_INDEX.md)를 참고하세요.

## 프로젝트 구조

```
popcorn_deploy/
├── helm/                          # 애플리케이션 Helm Charts
│   ├── charts/                    # 개별 서비스 차트
│   │   ├── common/               # 공통 라이브러리 차트
│   │   ├── gateway/              # API Gateway
│   │   ├── users/                # User Service
│   │   ├── stores/               # Store Service
│   │   ├── order/                # Order Service
│   │   ├── payment/              # Payment Service
│   │   ├── coupon/               # Coupon Service
│   │   ├── frontend/             # Frontend Service
│   │   ├── orderQuery/           # Order Query Service
│   │   └── checkIns/             # CheckIn Service
│   └── popcorn-umbrella/         # Umbrella Chart
│       ├── Chart.yaml
│       ├── values.yaml           # 기본값
│       ├── values-dev.yaml       # 개발 환경
│       └── values-prod.yaml      # 운영 환경
├── infrastructure/                # 인프라 컴포넌트
│   ├── lgtm/                     # LGTM Stack (Observability)
│   │   ├── loki/                 # 로그 수집
│   │   ├── grafana/              # 시각화
│   │   ├── tempo/                # 분산 추적
│   │   └── mimir/                # 메트릭 저장
│   ├── kafka/                    # Kafka Ecosystem
│   │   ├── kafka/                # Kafka
│   │   └── kafka-ui/             # Kafka UI
│   ├── argocd/                   # ArgoCD Helm Values
│   └── scripts/                  # 설치 스크립트
│       ├── install-argocd.sh
│       ├── install-kafka.sh
│       ├── install-lgtm.sh
│       ├── install-all.sh
│       └── uninstall-all.sh
└── applications/                 # ArgoCD Application CRD
    ├── dev/
    └── prod/
```

## 서비스 목록

1. **gateway** - API Gateway (Spring Cloud Gateway)
2. **users** - 사용자 서비스
3. **stores** - 스토어 서비스
4. **order** - 주문 서비스 (Command)
5. **payment** - 결제 서비스
6. **frontend** - 프론트엔드 서비스 (Next.js)
7. **orderQuery** - 주문 조회 서비스 (Query, CQRS)
8. **checkIns** - 체크인 서비스 (QR 코드 포함)
9. **coupon** - 쿠폰 서비스

## ECR 이미지 주소

```
{aws_account_id}.dkr.ecr.{region}.amazonaws.com/goorm-popcorn-api-gateway
{aws_account_id}.dkr.ecr.{region}.amazonaws.com/goorm-popcorn-user
{aws_account_id}.dkr.ecr.{region}.amazonaws.com/goorm-popcorn-store
{aws_account_id}.dkr.ecr.{region}.amazonaws.com/goorm-popcorn-order
{aws_account_id}.dkr.ecr.{region}.amazonaws.com/goorm-popcorn-payment
{aws_account_id}.dkr.ecr.{region}.amazonaws.com/goorm-popcorn-front
{aws_account_id}.dkr.ecr.{region}.amazonaws.com/goorm-popcorn-order-query
{aws_account_id}.dkr.ecr.{region}.amazonaws.com/goorm-popcorn-checkin
{aws_account_id}.dkr.ecr.{region}.amazonaws.com/goorm-popcorn-coupon
```

## 배포 방법

### 1. 인프라 컴포넌트 설치

먼저 필요한 인프라 컴포넌트(ArgoCD, Kafka, LGTM)를 설치합니다.

```bash
# 모든 인프라 컴포넌트 한 번에 설치
cd infrastructure/scripts
./install-all.sh prod

# 또는 개별 설치
./install-argocd.sh prod
./install-kafka.sh prod
./install-lgtm.sh prod
```

자세한 내용은 [Infrastructure README](infrastructure/README.md)를 참고하세요.

### 2. 애플리케이션 배포

#### Helm CLI 배포

```bash
# 로컬 charts 변경 사항을 umbrella dependency(.tgz)로 동기화
./helm/scripts/sync-umbrella-deps.sh

# 개발 환경
helm upgrade --install popcorn-dev ./helm/popcorn-umbrella \
  --namespace popcorn-dev \
  --create-namespace \
  --values ./helm/popcorn-umbrella/values.yaml \
  --values ./helm/popcorn-umbrella/values-dev.yaml

# 운영 환경
helm upgrade --install popcorn-prod ./helm/popcorn-umbrella \
  --namespace popcorn-prod \
  --create-namespace \
  --values ./helm/popcorn-umbrella/values.yaml \
  --values ./helm/popcorn-umbrella/values-prod.yaml
```

### ArgoCD 배포

```bash
# ArgoCD Application 생성
kubectl apply -f applications/dev/application.yaml
kubectl apply -f applications/prod/application.yaml
```

## 환경별 설정

- **Dev**: 최소 리소스, 일부 서비스 비활성화 가능
- **Prod**: 고가용성, 오토스케일링 활성화

## 인프라 컴포넌트

### LGTM Stack (Observability)
- **Loki**: 로그 수집 및 저장
- **Grafana**: 시각화 및 대시보드
- **Tempo**: 분산 추적
- **Mimir**: 메트릭 저장 (Prometheus 호환)

### Kafka Ecosystem
- **Kafka**: 이벤트 스트리밍 플랫폼 (KRaft 모드)
- **Kafka UI**: Kafka 관리 웹 UI

### ArgoCD
- **ArgoCD**: GitOps 기반 배포 자동화

## 접속 정보

### ArgoCD
```bash
kubectl port-forward -n argocd svc/argocd-server 8080:443
# URL: https://localhost:8080
```

### Kafka UI
```bash
kubectl port-forward -n kafka svc/kafka-ui 8080:80
# URL: http://localhost:8080
```

### Grafana
```bash
kubectl port-forward -n monitoring svc/grafana 3000:80
# URL: http://localhost:3000
```

## 참고 문서

### 주요 문서
- 📚 [문서 인덱스](README_INDEX.md) - 모든 문서 목록과 시나리오별 가이드
- 📖 [디렉터리 가이드](DIRECTORY_GUIDE.md) - 디렉터리 구조 상세 설명
- 🚀 [배포 가이드](DEPLOYMENT_GUIDE.md) - 배포 방법 및 트러블슈팅

### 세부 문서
- [Helm Charts](helm/README.md) - Helm Chart 사용 가이드
- [Infrastructure](infrastructure/README.md) - 인프라 설치 가이드
- [Applications](applications/README.md) - ArgoCD Application 가이드
- [파일 구조](STRUCTURE.md) - 전체 파일 트리

## 인프라 설계·운영 문서

| 분류 | 문서 |
|---|---|
| 아키텍처 | [prod 인프라 다이어그램](design/architecture/popcorn-prod-architecture.png) · [인프라 개요와 의사결정](design/INFRA_OVERVIEW_AND_DECISIONS.md) · [인프라 설계서 (popcorn-terraform)](https://github.com/ProfectProject/popcorn-terraform/blob/HEAD/docs/ARCHITECTURE.md) |
| 관측성 | [로그 설계서](design/observability/LOGGING_DESIGN.md) · [운영 모니터링 Runbook](infrastructure/lgtm/RUNBOOK.md) · [Grafana 신호별 대시보드](infrastructure/lgtm/DASHBOARDS.md) · [OTel·LGTM 파이프라인 가이드](infrastructure/otel/PIPELINE_GUIDE.md) |
| 의사결정 | [ADR-0001 OTel Java Agent vs SDK](design/adr/0001-otel-java-agent-vs-sdk.md) |
| 배포 | [ArgoCD Helm 의존성 가이드](helm/ARGOCD_HELM_DEPENDENCY.md) |
| 장애 대응 | [장애 기록 7건](design/troubleshooting/INCIDENT_REPORTS.md) · [부하 테스트 후 개선 과제](design/POST_LOADTEST_IMPROVEMENTS.md) |
