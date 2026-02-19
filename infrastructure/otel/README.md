# OpenTelemetry Collector

OpenTelemetry Collector를 `monitoring` 네임스페이스에 배포합니다.

## 설치

```bash
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install otel-collector open-telemetry/opentelemetry-collector \
  --namespace monitoring \
  --values values.yaml \
  --values values-prod.yaml
```

## 파이프라인

- traces: OTLP 수신 -> Tempo(`tempo:4317`) 전송
- metrics: OTLP 수신 -> Mimir(`mimir-nginx/api/v1/push`) remote write
- logs: OTLP 수신 -> Loki(`loki:3100/otlp`) 전송

## 엔드포인트

- OTLP gRPC: `otel-collector-opentelemetry-collector.monitoring.svc.cluster.local:4317`
- OTLP HTTP: `otel-collector-opentelemetry-collector.monitoring.svc.cluster.local:4318`
