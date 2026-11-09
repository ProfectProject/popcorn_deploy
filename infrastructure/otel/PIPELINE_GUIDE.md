# OTel + LGTM 파이프라인 동작 원리 및 연동 가이드

> 원본: Notion "OTel + LGTM 개념/동작/통신 원리"(2026-02-18) + "LGTM + OTel 연동 운영 가이드 (Popcorn 배포 기준)"(2026-02-20). 작성: 인프라·배포 설계 담당.
> 참고: 연동 가이드는 Java Agent 적용 이전 시점에 작성되었다. 현재 운영 구조는 `observability-runbook.md` 참고.

## 1. 목적
- 마이크로서비스의 Trace/Metric/Log를 표준 수집기(OTel Collector)로 통합 수집
- LGTM(Loki, Grafana, Tempo, Mimir)으로 저장·조회·시각화 일원화

## 2. 구성 요소
| 구성 요소 | 역할 |
| --- | --- |
| OpenTelemetry Collector | OTLP 수신, `memory_limiter`/`batch` 처리, 신호별 백엔드 라우팅 |
| Tempo | 분산 추적 저장 |
| Loki | 로그 저장/조회 |
| Mimir | Prometheus 호환 메트릭 저장/조회 |
| Grafana | Loki/Tempo/Mimir 통합 조회 |

## 3. 신호별 파이프라인
| 신호 | 앱 → Collector | Collector → 백엔드 | Grafana 조회 |
| --- | --- | --- | --- |
| Trace | OTLP gRPC 4317 / HTTP 4318 | `otlp_grpc` → `tempo.monitoring.svc.cluster.local:4317` | Tempo API |
| Metric | OTLP | `prometheusremotewrite` → `mimir-nginx.monitoring.svc.cluster.local/api/v1/push` | `http://mimir-nginx/prometheus` |
| Log | OTLP | `otlp_http` → `loki.monitoring.svc.cluster.local:3100/otlp` | `http://loki:3100` |

## 4. 클러스터 내부 엔드포인트
- OTel Collector: `otel-collector-opentelemetry-collector.monitoring.svc.cluster.local` (4317 gRPC, 4318 HTTP)
- Tempo query: `tempo.monitoring.svc.cluster.local:3200`
- Loki: `loki.monitoring.svc.cluster.local:3100`
- Mimir gateway: `mimir-nginx.monitoring.svc.cluster.local`
- Grafana: `grafana.monitoring.svc.cluster.local` (Ingress host `grafana.goormpopcorn.shop`)

## 5. 서비스 연동

### A. Java Agent 방식 (권장)
```yaml
env:
  OTEL_SERVICE_NAME: "gateway"
  OTEL_RESOURCE_ATTRIBUTES: "service.name=gateway,service.namespace=popcorn-prod,deployment.environment=prod"
  OTEL_EXPORTER_OTLP_ENDPOINT: "http://otel-collector-opentelemetry-collector.monitoring.svc.cluster.local:4318"
  OTEL_EXPORTER_OTLP_PROTOCOL: "http/protobuf"
  OTEL_TRACES_EXPORTER: "otlp"
  OTEL_METRICS_EXPORTER: "otlp"
  OTEL_LOGS_EXPORTER: "otlp"
  OTEL_PROPAGATORS: "tracecontext,baggage"
  OTEL_EXPERIMENTAL_RESOURCE_DETECTORS: "all"
  JAVA_TOOL_OPTIONS: "-javaagent:/app/otel/opentelemetry-javaagent.jar"
```
> Java Agent JAR 배포 경로(이미지 또는 initContainer)가 선행되어야 한다. 로그는 stdout JSON + trace/span id 상관관계로 구조화하는 것이 가장 효율적이다.

### B. 로그 우선 (단기 대체)
Pod stdout을 Fluent Bit 등으로 Loki에 수집한 뒤 점진적으로 OTel 로그 exporter를 추가한다.

### 인프라 컴포넌트
- **Kafka**: 로그는 Loki, 메트릭은 JMX 기반, 트레이스는 Kafka를 호출하는 애플리케이션 span으로 상관관계 추적
- **Redis/Valkey (관리형)**: 플랫폼 로그는 CloudWatch, 연결 실패·메모리·지연·eviction 지표 수집. 자가 운영 시 Redis Exporter + Mimir

## 6. 수집 우선순위
- **P0 (장애 탐지)**: trace ID 기반 요청 시작/종료·DB/외부API/MQ 호출·인증 실패·예외, HTTP 요청 로그(`method`, `path`, `status`, `duration_ms`, `request_id`), 주문/결제/체크인/쿠폰 비즈니스 이벤트, 서비스 시작/중단·Flyway·커넥션 풀 고갈
- **P1 (운영 안정성)**: Kafka 토픽/파티션/오프셋/컨슈머그룹/재시도, Redis timeout·memory·eviction, RPS·오류율·p95/p99, under-replicated partitions, DLQ 처리 건수
- **P2 (감사)**: 로그인·권한 변경·토큰 발급, 결제/환불/재고 변경 감사 이벤트

## 7. 검증 체크리스트
- Trace: Pod env에 `OTEL_*` 존재 확인 → 주문/결제 요청 후 Tempo에서 동일 trace 조회
- Log: Grafana → Loki에서 `namespace="popcorn-prod"` + `service_name`으로 ERROR 조회, trace_id로 요청-로그 추적
- Metric: 요청 rate, histogram 기반 p95/p99, Kafka/Redis 지표 알람 연동
- 인프라: Grafana datasource healthy, Collector 로그에 export 실패 없음, JMX/Redis target healthy, PVC/MinIO 용량 모니터링

## 8. 보안/개인정보
- JWT·Passport 키·비밀번호·토큰 원문 로그 금지
- 이메일·전화번호·주문자명 마스킹 또는 해시
- `trace_id`/`span_id`는 항상 남기되 개인정보와 직접 조합 금지
