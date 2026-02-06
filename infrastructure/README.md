# Infrastructure Components

Popcorn MSA를 위한 인프라 컴포넌트 Helm Charts 관리

## 구성 요소

### 1. LGTM Stack (Observability)
- **Loki**: 로그 수집 및 저장
- **Grafana**: 시각화 및 대시보드
- **Tempo**: 분산 추적 (Distributed Tracing)
- **Mimir**: 메트릭 저장 및 쿼리

### 2. Kafka (Event Streaming)
- **Kafka**: 이벤트 스트리밍 플랫폼
- **Kafka UI**: Kafka 관리 웹 UI

### 3. ArgoCD (GitOps)
- **ArgoCD**: Kubernetes 배포 자동화

## 디렉터리 구조

```
infrastructure/
├── lgtm/                      # LGTM Stack
│   ├── loki/
│   │   ├── values.yaml
│   │   ├── values-dev.yaml
│   │   └── values-prod.yaml
│   ├── grafana/
│   │   ├── values.yaml
│   │   ├── values-dev.yaml
│   │   └── values-prod.yaml
│   ├── tempo/
│   │   ├── values.yaml
│   │   ├── values-dev.yaml
│   │   └── values-prod.yaml
│   └── mimir/
│       ├── values.yaml
│       ├── values-dev.yaml
│       └── values-prod.yaml
├── kafka/                     # Kafka Ecosystem
│   ├── kafka/
│   │   ├── values.yaml
│   │   ├── values-dev.yaml
│   │   └── values-prod.yaml
│   └── kafka-ui/
│       ├── values.yaml
│       ├── values-dev.yaml
│       └── values-prod.yaml
├── argocd/                    # ArgoCD Helm Values
│   ├── values.yaml
│   ├── values-dev.yaml
│   └── values-prod.yaml
└── scripts/                   # 설치 스크립트
    ├── install-lgtm.sh
    ├── install-kafka.sh
    ├── install-argocd.sh
    └── install-all.sh
```

## 주의사항

### ArgoCD 디렉터리 구분
- **`/infrastructure/argocd`**: ArgoCD 자체를 설치하기 위한 Helm values
- **`/applications`**: ArgoCD로 애플리케이션을 배포하기 위한 Application CRD

혼동하지 않도록 주의하세요!

## 설치 순서

1. **ArgoCD** (GitOps 도구 먼저 설치)
2. **Kafka** (이벤트 스트리밍)
3. **LGTM Stack** (모니터링 및 관찰성)

## Helm Repository 추가

```bash
# Grafana (LGTM)
helm repo add grafana https://grafana.github.io/helm-charts

# Bitnami (Kafka)
helm repo add bitnami https://charts.bitnami.com/bitnami

# ArgoCD
helm repo add argo https://argoproj.github.io/argo-helm

# Repository 업데이트
helm repo update
```

## 네임스페이스

- `monitoring`: LGTM Stack
- `kafka`: Kafka 및 Kafka UI
- `argocd`: ArgoCD

## 참고 자료

- [Grafana Helm Charts](https://github.com/grafana/helm-charts)
- [Bitnami Kafka Helm Chart](https://github.com/bitnami/charts/tree/main/bitnami/kafka)
- [ArgoCD Helm Chart](https://github.com/argoproj/argo-helm)
