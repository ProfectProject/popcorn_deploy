# LGTM Stack

Grafana LGTM Stack (Loki, Grafana, Tempo, Mimir) 설치 및 관리

## 개요

LGTM은 Grafana의 통합 관찰성 스택입니다:
- **L**oki: 로그 수집 및 저장
- **G**rafana: 시각화 및 대시보드
- **T**empo: 분산 추적 (Distributed Tracing)
- **M**imir: 메트릭 저장 및 쿼리 (Prometheus 호환)

## 설치 순서

1. Loki (로그 저장소)
2. Tempo (트레이스 저장소)
3. Mimir (메트릭 저장소)
4. Grafana (시각화)

## Helm Repository

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

## 네임스페이스

```bash
kubectl create namespace monitoring
```

## 설치 명령어

```bash
# Loki
helm upgrade --install loki grafana/loki \
  --namespace monitoring \
  --values loki/values.yaml \
  --values loki/values-prod.yaml

# Tempo
helm upgrade --install tempo grafana/tempo \
  --namespace monitoring \
  --values tempo/values.yaml \
  --values tempo/values-prod.yaml

# Mimir
helm upgrade --install mimir grafana/mimir-distributed \
  --namespace monitoring \
  --version 5.8.0 \
  --values mimir/values.yaml \
  --values mimir/values-prod.yaml

# Grafana
helm upgrade --install grafana grafana/grafana \
  --namespace monitoring \
  --values grafana/values.yaml \
  --values grafana/values-prod.yaml
```

## 접속 정보

### Grafana
```bash
# 포트 포워딩
kubectl port-forward -n monitoring svc/grafana 3000:80

# 초기 비밀번호 확인
kubectl get secret -n monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode
```

## 데이터 소스 구성

Grafana에서 다음 데이터 소스를 자동으로 구성:
- Loki: `http://loki:3100`
- Tempo: `http://tempo:3100`
- Mimir: `http://mimir-nginx/prometheus`

## 대시보드

사전 구성된 대시보드:
- Kubernetes Cluster Monitoring
- Application Metrics
- Log Analysis
- Distributed Tracing
