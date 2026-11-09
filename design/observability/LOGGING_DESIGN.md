# 로그 데이터 설계서

> 원본: Notion "로그 설계서" (Infra > 인프라 설계). 작성: 인프라·배포 설계 담당, 2026-02-22.
> 분석 기준: `popcorn_msa` `develop-kafka` 브랜치(커밋 `2e1871f8`). 범위: gateway, users, stores, order, payment, orderQuery, checkIns, coupon, common-lib.

## 1) 문제
- 서비스별 로그 포맷·필드가 달라 장애 분석 시 교차 조회가 어렵다.
- Kafka/Outbox 비동기 흐름에서 `eventId`, `correlationId`, `topic/partition/offset`이 일관되지 않아 재처리·중복 추적이 어렵다.
- 민감정보가 로그에 노출되는 지점이 있다.
- 요구사항의 "로그-메트릭-트레이스 상관관계"를 충족할 표준 로그 계약이 없다.

## 2) 원인
- 공통 로깅 컴포넌트(`common-lib`의 `TraceMdcFilter`, `RequestLoggingFilterImpl`, `EventLoggingAspect`)는 있으나 서비스별 적용 방식이 다르다(일부 서비스는 `com.popcorn.common` 스캔 제한/미적용).
- 서비스별 `logging.pattern`, 로그 레벨, JSON 구조가 제각각이다.
- 민감정보를 직접 출력하는 코드가 있다.
- Loki 라벨이 `container_id`, `stream` 중심이라 서비스/이벤트 단위 탐색성이 낮다.

## 3) 설계

### 3.1 목표
- 트랜잭션 추적: `trace_id` + `correlation_id` + `event_id` 연결
- 비동기 추적: Kafka/Outbox 전 과정을 공통 키로 연결
- 보안: 비밀·토큰·개인정보 원문 로그 금지
- 운영성: 로그 기반 SLI/SLO, 알림, 재처리 판단 근거

### 3.2 공통 로그 스키마

| 필드 | 타입 | 필수 | 설명 |
| --- | --- | --- | --- |
| `ts` | RFC3339 | Y | 발생 시각 (UTC 저장, KST 조회) |
| `level` | string | Y | DEBUG/INFO/WARN/ERROR |
| `service` | string | Y | 서비스명 |
| `env` | string | Y | local/dev/prod |
| `trace_id` | string | Y | HTTP/메시지 전파 추적 ID |
| `request_id` | string | N | HTTP 요청 단위 ID |
| `correlation_id` | string | N | 도메인 흐름 상관관계 ID |
| `event_id` | string | N | 이벤트 고유 ID |
| `event_type` | string | N | 도메인 이벤트 타입 |
| `aggregate_type` | string | N | ORDER, PAYMENT, COUPON 등 |
| `aggregate_id` | string | N | 비즈니스 식별자 |
| `result` | string | Y | SUCCESS/FAIL/SKIP/RETRY |
| `error_code` | string | N | 비즈니스/시스템 에러 코드 |
| `error_class` | string | N | 예외 클래스명 |
| `error_message` | string | N | 민감정보 제거 후 메시지 |
| `duration_ms` | number | N | 처리 시간 |
| `message` | string | Y | 요약 메시지 |

### 3.3 로그 유형별 확장 필드

| 유형 | 추가 필드 |
| --- | --- |
| HTTP_ACCESS | `http.method`, `http.path`, `http.route`, `http.status`, `client.ip_hash` |
| HTTP_ERROR | `http.method`, `http.path`, `http.status`, `error_code`, `error_class` |
| SECURITY_AUDIT | `actor_type`, `actor_id_hash`, `action`, `resource`, `decision`, `reason` |
| KAFKA_CONSUME | `kafka.topic`, `kafka.partition`, `kafka.offset`, `kafka.group`, `kafka.key_hash` |
| KAFKA_PRODUCE | `kafka.topic`, `kafka.key_hash`, `producer`, `publish_mode` (outbox / direct) |
| OUTBOX_WRITE | `outbox.table`, `outbox.schema_version`, `outbox.created_at`, `outbox.topic` |
| DLQ_EVENT | `dlq.topic`, `original.topic`, `original.partition`, `original.offset`, `retry_attempt` |
| SCHEDULER_JOB | `job.name`, `job.run_id`, `job.batch_size`, `job.success_count`, `job.fail_count` |
| EXTERNAL_CALL | `peer.service`, `peer.endpoint`, `http.status`, `timeout_ms`, `retry_count` |

### 3.4 서비스별 필수 로그

| 서비스 | 시나리오 | 필수 데이터 |
| --- | --- | --- |
| gateway | JWT 인증 성공/실패, 라우팅 결과 | `trace_id`, `http.*`, `route_id`, `target_service`, `decision`, `duration_ms` |
| users | 로그인/리프레시/권한거부 | `actor_id_hash`, `auth_flow`, `decision`, `reason`, `client.ip_hash` |
| order | 상태 전이, Outbox 기록, 보상 트랜잭션 | `order_id`, `popup_id`, `event_type`, `from_status`, `to_status`, `outbox.*` |
| payment | 요청/승인/취소, DLQ, 재시도 | `payment_id`, `order_id`, `event_type`, `retry_attempt`, `dlq.*`, `duration_ms` |
| stores | 재고/스케줄 예약, HOLD 해제 재시도 | `order_id`, `popup_id`, `goods_id/schedule_id`, `qty`, `retry_count`, `result` |
| checkIns | QR 생성/무효화/체크인, 중복 스킵 | `order_id`, `payment_id`, `event_id`, `idempotency`, `kafka.*` |
| orderQuery | 이벤트 정규화, 프로젝션 반영 | `event_type(raw/normalized)`, `event_id`, `projection`, `apply_result` |
| coupon | 발급/예약/사용, Outbox 배치 | `coupon_id`, `user_coupon_id`, `order_id`, `job.*`, `published_count` |

### 3.5 민감정보 정책

| 데이터 | 정책 |
| --- | --- |
| 비밀키(passport secret, JWT secret, DB password) | 출력 금지 |
| 토큰 원문(Authorization, refresh token, passport payload) | 출력 금지, 길이/존재 여부만 |
| 이메일/전화/주소 | 해시(sha256) 또는 마스킹 |
| 결제키/결제 URL 쿼리 | 접두/접미 일부만 |
| 요청/응답 body | 기본 금지, 화이트리스트 필드만 구조화 |

### 3.6 수집·보존·알림
- 파이프라인: Application JSON Log → Fluent Bit → Loki
- 보존: Loki 7일, Tempo 7일, Mimir 30일
- 최소 라벨: `service`, `env`, `level`, `event_type`, `kafka.topic`, `result`
- 알림: ERROR 비율 급증(5/10분 윈도우), `payment.dlq.*` 증가, consumer lag 임계 초과, outbox 미발행 증가 추세

### 3.7 로그 레벨
- INFO: 상태 전이 완료, 메시지 처리 완료, 배치 요약
- WARN: 재시도, 부분 실패, 유효성 실패, 중복 스킵
- ERROR: 처리 실패, DLQ 전송, 정합성 깨짐, 보안 이벤트
- DEBUG: local/dev만, 운영 기본 비활성

### 3.8 표준 JSON 예시

```json
{
  "ts": "2026-02-22T06:15:01.234Z",
  "level": "INFO",
  "service": "payment",
  "env": "prod",
  "trace_id": "9c2f5f6dbad44d7ea4dd7f6f8c0b1e30",
  "correlation_id": "f0b1f8e6-1f23-4e12-a8f0-5501d6dcbb5f",
  "event_id": "bf9e0b0a-17db-4f6d-b282-3792c8d42f28",
  "event_type": "PAYMENT_APPROVED",
  "aggregate_type": "PAYMENT",
  "aggregate_id": "2c4d10e9-b9aa-4f7d-83cb-9c1743bf5f6c",
  "kafka.topic": "payment-events",
  "kafka.partition": 2,
  "kafka.offset": 104822,
  "result": "SUCCESS",
  "duration_ms": 128,
  "message": "결제 승인 이벤트 처리 완료"
}
```

## 4) 기대 효과
- `trace_id`/`correlation_id`/`event_id` 기반 이벤트 추적성 향상
- 장애 원인 파악 시간 단축
- 민감정보 노출 리스크 감소

## 5) 잔여 항목
- 공통 스키마를 서비스 로거(JSON encoder)와 Fluent Bit 라벨 규칙에 반영할 배포 계획 확정
- 운영/개발 로그 레벨 분리, 공통 마스킹 유틸 적용 범위 확정
- Grafana/Loki에서 `service + event_type + result` 축 탐색 UX 점검

## 부록) 설계 근거 코드 (popcorn_msa 기준 상대 경로)
- `common-lib/src/main/java/com/popcorn/common/logging/TraceMdcFilter.java`
- `common-lib/src/main/java/com/popcorn/common/filter/RequestLoggingFilterImpl.java`
- `common-lib/src/main/java/com/popcorn/common/aop/EventLoggingAspect.java`
- `common-lib/src/main/resources/logback-spring.xml`
- 보안 리스크 지점: `gateway/.../jwt/JwtFilter.java`, `checkIns/.../CheckInsApplication.java`
- Outbox: order/stores/checkIns/payment의 `OutboxEvent`, coupon `CouponOutboxEventProcessor.kt`
