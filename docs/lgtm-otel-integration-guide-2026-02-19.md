# LGTM + OTel 연동 운영 가이드 (Popcorn 배포 기준)

## 1. 현재 스택에서의 OTel 연결 맵

현재 `infrastructure` 기준에서 OTel은 아래로 구성되어 있습니다.

- 수집기: `infrastructure/otel/values.yaml`
  - OTLP 수신: `4317`(gRPC), `4318`(HTTP)
  - 파이프라인
    - traces → `tempo.monitoring.svc.cluster.local:4317`
    - metrics → `mimir-nginx.monitoring.svc.cluster.local/api/v1/push`
    - logs → `loki.monitoring.svc.cluster.local:3100/otlp`
- LGTM Data Source
  - Loki: `http://loki:3100`
  - Tempo: `http://tempo:3100`
  - Mimir: `http://mimir-nginx/prometheus`

## 2. 핵심: 연동 포인트

현재는 OTel Collector 자체는 준비되어 있으나, **애플리케이션이 OTLP를 실제 송신하도록 설정되지 않은 상태**입니다. (서비스 chart 값에서 `OTEL_*` 미설정)

따라서 연동은 두 단계입니다.

### 2-1) 서비스(Trace/Log) 연동

#### A. Java 에이전트 방식(권장, 빠른 적용)

각 서비스 컨테이너에 아래 환경변수와 Java Agent를 붙입니다.

- `OTEL_SERVICE_NAME`: `gateway`, `users`, `order`, `payment`, `stores`, `checkins` 등
- `OTEL_RESOURCE_ATTRIBUTES`: `service.name=..., service.namespace=popcorn-prod, deployment.environment=prod`
- `OTEL_EXPORTER_OTLP_ENDPOINT`: `http://otel-collector-opentelemetry-collector.monitoring:4318`
- `OTEL_EXPORTER_OTLP_PROTOCOL`: `http/protobuf`
- `OTEL_TRACES_EXPORTER`: `otlp`
- `OTEL_METRICS_EXPORTER`: `otlp`
- `OTEL_LOGS_EXPORTER`: `otlp`
- `OTEL_PROPAGATORS`: `tracecontext,baggage`
- `JAVA_TOOL_OPTIONS` 또는 `ENTRYPOINT`
  - `-javaagent:/app/otel/opentelemetry-javaagent.jar`

> 로그를 애플리케이션 stdout(JSON) + OTel trace/span id 상관관계로 구조화하는 방식이 디버깅과 조회에 가장 효율적입니다.

#### B. 로그만 우선하려는 경우(단기 대체)

Pod stdout에서 바로 수집하는 방식(예: Fluent Bit/Promtail/Filelog receiver)으로 Loki 인입 후,
점진적으로 OTel 로그 exporter를 추가합니다.

### 2-2) 인프라 연동

#### Kafka
- **로그**: Loki로 수집 (Pod 로그/브로커 로그)
- **메트릭**: 현재 `jmx` 기반 수집 설정이 존재(`infrastructure/kafka/strimzi/...` 또는 `kafka/.../metrics.jmx.enabled`)
- **트레이스**: Kafka를 호출하는 애플리케이션 Span을 통해 상관관계 추적

#### Redis
- Redis가 관리형(예: ElastiCache)이라면
  - 로그: 플랫폼 로그(CloudWatch/Managed log)
  - 메트릭: Redis/캐시 지표 (연결 실패, 메모리, 레이턴시, Eviction) 수집
- 자가 운영 Redis라면 Redis Exporter + Mimir로 메트릭 수집을 권장

## 3. 지금 바로 수집해야 하는 항목 (우선순위)

### P0 (장애 탐지 필수)
1. **Trace ID 기반 4가지 핵심 이벤트**
   - 요청 시작/종료
   - DB/외부API/메시지 큐 호출
   - 인증/인가 실패
   - 예외 발생

2. **HTTP 요청 로그**
   - `method`, `path`, `status`, `duration_ms`, `request_id`, `client_ip`, `user_agent`

3. **비즈니스 트랜잭션 로그**
   - 주문, 결제, 체크인, 쿠폰/스토어 핵심 이벤트
   - `order_id`, `user_id`, `payment_id`, `qr_id`, `amount`, `event`

4. **시스템 상태 로그**
   - 서비스 시작/중단
   - Flyway 적용/실패
   - 캐시 불일치, DB 커넥션 풀 고갈

### P1 (운영 안정성)
1. **Kafka 이벤트 로그**
   - 토픽/파티션/오프셋/컨슈머그룹/재시도/실패

2. **Redis 이벤트 로그/메트릭**
   - `connection_timeout`, `command_timeout`, `used_memory`, `evicted_keys`, `cache_miss`

3. **메트릭 연동(자동 + 경보)**
   - 요청량(RPS), 오류율, p95/p99, DB latency, Redis latency
   - Broker leader epoch 이동, under_replicated_partitions
   - queue depth / DLQ / deadletter 처리 건수

### P2 (감사/규제)
1. 로그인/권한 변경/토큰 발급 기록
2. 결제/환불/재고 변경 감사 이벤트

## 4. 샘플 헬름 값(개념)

`values.yaml`의 `env`에 아래를 반영해 OTLP 송신을 붙입니다(공통 템플릿 기준).

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

> 실제 동작 전에 Java Agent JAR 배포 경로와 Dockerfile 변경이 선행돼야 합니다.

## 5. 수집 검증 체크리스트

### Trace
1. `kubectl -n popcorn-prod get deploy/payment -o yaml | rg -n "OTEL_"`
2. 결제/주문 API 요청 후 Tempo에서 동일 `trace_id` 조회

### Log
1. Grafana → Loki
2. `namespace="popcorn-prod"` + `service_name` 라벨로 recent ERROR 조회
3. `trace_id`로 request-to-log 추적

### Metric
1. Mimir/Prometheus에서 `rate(http_server_requests_seconds_count{job="kubernetes-pods"}[5m])`
2. `http_server_requests_seconds_bucket` 기반 p95/p99 체크
3. Kafka/Redis 지표와 장애 알람 연동

### 인프라
1. Grafana에서 tempo/loki/mimir datasource healthy 확인
2. `otel-collector` 로그에서 OTLP 수신/전송 에러 없음 확인
3. Kafka `jmx` exporter target, Redis 지표 target healthy 확인

## 6. LGTM에서 바로 쓸 쿼리 예시

### Loki (에러 상위)
- `{namespace="popcorn-prod", level="ERROR"}`
- `| json | line_format "{{.timestamp}} [{{.level}}] {{.logger}}: {{.message}} (trace_id={{.trace_id}})"`

### Tempo + Loki 상관조회
- trace 상세에서 `trace ID`를 가져와 Loki에 동일 필터 적용

### Mimir (서비스 오류율)
- `sum(rate(http_server_requests_seconds_count{job="kubernetes-pods",status=~"5.."}[5m])) / sum(rate(http_server_requests_seconds_count{job="kubernetes-pods"}[5m]))`

## 7. 보안/개인정보 체크

- JWT, Passport 키/비밀번호/토큰 원문은 로그에 출력 금지
- email/전화번호/주문자명 등은 마스킹 또는 해시 처리
- `trace_id`/`span_id`는 예외 없이 남기되 개인정보와 직접 조합 금지
