# Grafana 신호별 운영 대시보드 설계 (Logs / Metrics / Traces)

> 원본: Notion "Grafana Signal별 운영 대시보드 설계 및 반영" (Infra > 작업목록, 모니터링). 작성: 인프라·배포 설계 담당, 2026-02-23.

## 1) 문제
- 대시보드가 SLO 중심 1개(`popcorn-slo-overview`)뿐이라 신호별 즉시 대응이 어렵다.
- 지표를 봤을 때 무엇을 해야 하는지(판단 기준/조치)가 문서로 고정되어 있지 않다.
- 로그 설계 스키마와 실제 수집값이 다르고, 서비스별 구조화 수준이 달라 탐색성이 균일하지 않다.

## 2) 원인
- 신호별 세부 운영 보드 부재
- 애플리케이션 로그 포맷이 서비스별로 구조화 JSON / 원문 `log` 필드로 혼재
- 필드 네이밍 차이: 설계(`trace_id`, `event_id`, `result`) vs 실제(`traceId`, `httpStatus`, `elapsedMs`)

## 3) 조치

### 3-1. 로그 수집값 교차 검증
- 실제 Loki 수집 필드
  - 앱: `@timestamp`, `level`, `service`, `traceId`, `httpMethod`, `path`, `httpStatus`, `elapsedMs`, `thread`, `logger`, `message`
  - 수집기: `time`, `stream`, `_p`
  - K8s 메타: `kubernetes.pod_id`, `kubernetes.labels.*`, `kubernetes.container_image`, `kubernetes.host`
- Loki 라벨: `container`, `job`, `namespace`, `pod`, `service_name`, `stream`

### 3-2. 대시보드 반영 (`infrastructure/lgtm/argocd-chart/values-prod.yaml`)
- 신규: `popcorn-logs-overview`, `popcorn-metrics-overview`, `popcorn-traces-overview`
- 유지: `popcorn-slo-overview`

### 3-3. 신호별 패널, 판단 기준, 조치

**A. Logs (Loki)**

| 패널 | 이유 | 판단 기준 | 조치 |
| --- | --- | --- | --- |
| 서비스별 ERROR 추이 (5m) | 장애 시작점 식별 | 5분 연속 증가 | 최근 배포/롤아웃, RDS/Kafka 의존성 점검 |
| 서비스별 WARN 추이 (5m) | 장애 전조 | 평시 대비 3배 이상 | 재시도 폭증·타임아웃·외부 API 지연 차단 |
| 민감 키워드 탐지 (`password`, `token`, `passport.secret`) | 보안사고 예방 | 1건 이상 = P1 | 마스킹/코드 수정, 노출 시크릿 즉시 로테이션 |
| 4xx/5xx 응답 로그 추이 | 사용자 영향 | 지속 증가 | Gateway 라우팅·인증·다운스트림 확인 |
| 최근 ERROR 스트림 | 원인 본문 확보 | 즉시 | `traceId`로 Tempo 연계, 메트릭과 교차 확인 |

**B. Metrics (Mimir)**

| 패널 | 이유 | 판단 기준 | 조치 |
| --- | --- | --- | --- |
| 서비스별 RPS | 트래픽 급증 감지 | 평시 대비 3배 이상 | HPA/Karpenter/리소스 상한 확인 |
| 서비스별 5xx 비율 | 사용자 오류 | gateway > 2%, core > 5% (5m) | 롤백/격리, DB·Kafka·외부 API 확인 |
| 서버 P95 지연 | 체감 성능 | gateway > 0.8s, core > 1.5s (5m) | 느린 엔드포인트·쿼리 식별, 캐시/튜닝 |
| Outbound HTTP P95 | 다운스트림 상태 | 급증 | 타임아웃/재시도/서킷브레이커 점검 |
| JVM Heap 사용률 | OOM/GC 리스크 | 80% 이상 지속 | 힙·리소스 상향, 누수 탐지 |
| DB 커넥션 사용률 | DB 병목 | 70% 이상 지속 | 풀 튜닝, 장기 쿼리 점검 |
| Kafka Consumer Lag Max | 이벤트 지연 | 지속 증가 | 컨슈머 처리량·파티션·재시도 점검 |

**C. Traces (Tempo + OTel span metrics)**

| 패널 | 이유 | 판단 기준 | 조치 |
| --- | --- | --- | --- |
| Started Spans/s | 추적 데이터 생성량 | 트래픽 대비 급감 | Agent 주입·OTLP endpoint·샘플링 점검 |
| Span-to-Request 비율 | 계측 누락 | 급감 또는 0 근접 | 누락 API/비동기 경로 보강 |
| OTLP Span Export Success % | Collector 전달 품질 | 99% 미만 지속 | Collector/네트워크/Tempo ingest 점검 |
| Exported Spans/s | 실제 전송량 | 특정 서비스 급감 | exporter 실패 로그 확인 |
| Live Spans | 지연/정체 | 비정상 증가 | 느린 외부호출/DB 구간 drill-down |
| Trace Reporting Services 수 | 계측 커버리지 | 감소 | 서비스별 Agent/OTEL env 재점검 |

### 3-4. 확인된 운영 리스크
- 구조화 필드 미통일: `service` 기반 집계 가능 로그와 원문 `log`만 있는 로그가 혼재
- 민감 키워드 탐지 쿼리에서 실제 매치 발생 → 로그 설계서의 시크릿 원문 금지 정책 보강 필요

## 4) 검증
- `helm lint infrastructure/lgtm/argocd-chart -f values.yaml -f values-prod.yaml` 통과
- `helm template` 결과에서 대시보드 4개(`popcorn-{slo,logs,metrics,traces}-overview.json`) 확인, ConfigMap JSON 파싱 통과
- 실데이터: Loki 라벨/LogQL 응답, Mimir `http_server_*`·`jvm_memory_*`·`db_client_connections_usage`·`kafka_consumer_records_lag_max`·`otel_sdk_span_*`·`otlp_exporter_*`, Tempo 8개 서비스 확인

## 5) 잔여 항목
- ArgoCD 동기화 후 Grafana UI에서 신규 대시보드 3개 생성 확인
- 민감정보 로그 라인 제거/마스킹, 노출된 시크릿 로테이션
- 설계 스키마(`trace_id`, `event_id`, `result`)로 서비스 공통 포맷 점진 통일
