# 운영 트러블슈팅 기록 (2026-02-19 ~ 02-22)

> 원본: Notion "트러블 슈팅" 데이터베이스 (Infra). 작성: 인프라·배포 설계 담당.
> AWS 계정 ID, Route53 Zone/Change ID, ALB DNS, 공인/내부 IP, DB 비밀번호는 [REDACTED] 처리.

| # | 제목 | 날짜 | 태그 |
| --- | --- | --- | --- |
| 1 | checkins CrashLoopBackOff (Flyway 오너십) | 02-19 | K8s, Application |
| 2 | ImagePullBackOff (ECR 태그 미존재) | 02-19 | K8s, AWS |
| 3 | Front/API 도메인 접근 및 Swagger 이슈 | 02-20 | K8s, AWS, Application |
| 4 | Gateway Argo Rollout 전환 | 02-20 | K8s |
| 5 | 전체 서비스 Deployment → Rollout (Blue/Green) 전환 | 02-20 | K8s |
| 6 | stores CrashLoopBackOff (`storeKafkaConfig`) | 02-20 | K8s, Application |
| 7 | Outbox CDC Kafka Connect 복구 | 02-22 | Application |

---

## 1. checkins CrashLoopBackOff — Flyway 마이그레이션 오너십

- **증상**: `popcorn-prod-checkins`가 CrashLoopBackOff 반복.
  - 초기: `UnsatisfiedDependencyException` (`headerAuthenticationFilter`, `passport.secret` 주입 문제)
  - 이후: `Migration of schema "checkins" to version "2 - outbox events" failed` / `ERROR: must be owner of table outbox_events`, 이어서 V3에서 `must be owner of table qr_order_qr_codes`
- **검증**: Pod env에 `SPRING_FLYWAY_USER=qr_migrator`, `SPRING_FLYWAY_PASSWORD=[REDACTED]`, `SPRING_DATASOURCE_USERNAME=qr_app`이 정상 반영됨. 그러나 DB 실제 오너는 `outbox_events`, `qr_checkins`, `qr_order_qr_codes` 모두 `postgres`, `flyway_schema_history`만 `qr_migrator`.
- **원인**: 엔티티 테이블 오너가 `postgres`라 migrator 계정이 DDL(`CREATE INDEX` 등)을 수행할 수 없음.
- **조치**: 이미지 변경 없이 오너십 정리 후 재기동
  ```sql
  ALTER TABLE checkins.flyway_schema_history OWNER TO qr_migrator;
  ALTER TABLE checkins.outbox_events          OWNER TO qr_migrator;
  ALTER TABLE checkins.qr_checkins            OWNER TO qr_migrator;
  ALTER TABLE checkins.qr_order_qr_codes      OWNER TO qr_migrator;
  ALTER SEQUENCE checkins.outbox_events_id_seq OWNER TO qr_migrator;
  ```
  `kubectl -n popcorn-prod rollout restart deployment popcorn-prod-checkins` → `1/1 Running`, flyway history V1~V6 성공 기록.
- **교훈**: Helm에 `SPRING_FLYWAY_USER`를 지정해도 DB 오브젝트 오너십이 맞지 않으면 계속 실패한다.
- **재발 방지**: 배포 전 스키마 오너 선검사(불일치 시 배포 차단), CI에서 `helm template` 결과의 Flyway/Passport env 누락 검증, 배포 후 2회 재기동 테스트, PostgreSQL/Flyway 버전 호환성 경고 별도 티켓화.

## 2. ImagePullBackOff — ECR 태그 미존재

- **증상**: `dev`, `helm-test`, `popcorn-prod` 다수 Pod가 `ImagePullBackOff`/`ErrImagePull`. 일부 `CreateContainerConfigError`(`configmap "...-config" not found`) 동반.
- **원인**
  - 핵심: `goorm-popcorn-*:dev-1e443671` 태그가 ECR에 없음 (`[REDACTED].dkr.ecr.ap-northeast-2.amazonaws.com/goorm-popcorn-order:dev-1e443671 ... not found`)
  - 부차: `0/3 nodes are available: Insufficient memory, Too many pods`, `untolerated taint` 누적으로 복구 지연
- **조치**: 정상 Pod(`:dev-latest`)와 장애 Pod(`:dev-1e443671`) 혼재 확인 → 태그 정합성 재검토 후 재배포.
- **재발 방지**: CI에서 렌더 결과의 모든 `image.repository:tag`가 ECR에 존재하는지 사전 검사, 배포 직후 ImagePullBackOff 비율 감시(예: 5% 이상 실패), configmap 누락 동시 점검, 노드 메모리/pods/taint 지표화, rollout `maxSurge/maxUnavailable` 완화.

## 3. Front/API 도메인 접근 및 Swagger 이슈

- **상황**: `goormpopcorn.shop`(front), `swagger.goormpopcorn.shop` 접속 불가 보고. swagger 전용 도메인은 제거 요청.
- **점검**: Ingress `popcorn-prod-frontend`(→ :3000), `popcorn-prod-gateway`(`api.`/`swagger.` → :8080) 정상, Pod 1/1 Ready. Route53 레코드는 각 ALB([REDACTED])를 가리킴. ALB는 443만 노출(`ssl-redirect: 443`).
- **조치**
  1. Route53에서 `swagger.goormpopcorn.shop` CNAME 삭제(INSYNC) + `values-prod.yaml`의 `gateway.ingress.hosts`에서 제거해 GitOps 재생성 방지.
  2. 검증: `curl -I --resolve goormpopcorn.shop:443:[REDACTED] https://goormpopcorn.shop` → 200, `https://api.goormpopcorn.shop/v3/api-docs` → 200.
- **추가 이슈 A — API 루트 404**: gateway에 `/` 핸들러가 없어 Whitelabel 404.
  - 시도 1: `OpenApiProxyController`에 `/` → 302 리다이렉트 추가한 이미지 배포 → Redis 연결 초기화 실패로 CrashLoop → 즉시 `v1.0.1`로 롤백.
  - 시도 2 (최종): ALB Ingress 액션 `alb.ingress.kubernetes.io/actions.redirect-root-to-swagger`로 `/` 경로를 302 처리. `curl -I https://api.goormpopcorn.shop/` → 302, Swagger UI → 200.
- **추가 이슈 B — Swagger mixed-content**: `GATEWAY_SERVICE_URL=http://popcorn-prod-gateway:8080`로 내부 HTTP URL이 생성됨 → 공개 도메인 `https://api.goormpopcorn.shop`으로 변경. `initialDelaySeconds: 330`으로 인한 일시 Ready=0 후 정상화.
- **추가 이슈 C — Payment Swagger 403**: payment 이미지의 prod 설정에서 `springdoc.api-docs.enabled=false` → `/v3/api-docs` 404 후 `Http403ForbiddenEntryPoint`로 403. 재빌드 없이 Helm env `SPRINGDOC_API_DOCS_ENABLED`/`SPRINGDOC_SWAGGER_UI_ENABLED=true` 오버라이드 → ArgoCD sync, Blue/Green 승격 후 200.

## 4. Gateway Argo Rollout 전환

- **문제**: gateway 차트가 Deployment 전용이라 Rollout 적용 불가. Deployment는 보관해야 하며, 동시에 띄우면 Service selector가 같아 트래픽 혼선 위험.
- **조치**
  - `templates/rollout.yaml` 추가 (`argoproj.io/v1alpha1` Rollout, canary)
  - `deployment.yaml`: `rollout.enabled=false` 또는 `rollout.keepDeployment=true`일 때만 렌더
  - `hpa.yaml`: `rollout.enabled=false`일 때만 렌더
  - prod values: `replicaCount: 0`(Deployment 보관, Pod 미기동), `rollout.enabled: true`, `rollout.replicas: 1`
- **검증**: `helm lint`/`helm template`에서 Deployment replicas 0, Rollout replicas 1 확인. ArgoCD `OutOfSync` 지속으로 특정 리비전 수동 sync 후 Rollout AVAILABLE=1. `initialDelaySeconds: 330` 동안 일시 503 후 200 복구.
- **롤백 절차**: `gateway.rollout.enabled=false`, `gateway.replicaCount=1`로 원복 후 sync.

## 5. 전체 서비스 Deployment → Rollout (Blue/Green) 전환

- **목표**: frontend, gateway, users, stores, order, payment, order-query, checkins 8개 서비스를 Rollout으로 전환, `deployment.yaml`은 파일만 보관.
- **문제**: 대부분 서비스에 Rollout 템플릿 없음, HPA가 Deployment를 스케일 타깃으로 사용해 충돌 가능. 반영 중 선행 커밋이 prod 이미지 태그를 ECR에 없는 `dev-4537917f`로 바꿔 `ErrImagePull`.
- **조치**
  - 전 서비스: Deployment는 `keepDeployment=true`일 때만, HPA는 `rollout.enabled=false`일 때만 렌더, `values.yaml`에 `rollout` 기본값 추가
  - checkins/frontend/order/order-query/payment/stores에 `rollout.yaml` 신규
  - prod 이미지 태그를 안정 태그 `v1.0.1`로 복구
  - ArgoCD 수동 sync 후 기존 Deployment 8개 수동 삭제
  - 후속: 전 서비스 `blueGreen` 전략 + `preview` Service 추가 (users만 `autoPromotionEnabled=false`)
- **검증**: 렌더 결과 `kind: Rollout`만 생성, 클러스터 Deployment 0개, Rollout 8개, `*-preview` Service 8개. stores는 6번 이슈 해결 후 Healthy.

## 6. stores CrashLoopBackOff — `storeKafkaConfig`

- **증상**: `BeanCreationException: Error creating bean with name 'storeKafkaConfig'`, stores endpoint 없음, ArgoCD 앱 전체 Healthy 미달.
- **원인**: 이미지의 `application-prod.yml`이 `spring.kafka.consumer.group-id: ${STORE_KAFKA_CONSUMER_GROUP_ID}`를 참조하나 ConfigMap에는 `KAFKA_CONSUMER_GROUP_ID`만 존재.
- **조치**: `helm/charts/stores/templates/configmap.yaml`에 `STORE_KAFKA_CONSUMER_GROUP_ID`, `SPRING_KAFKA_BOOTSTRAP_SERVERS`, `SPRING_KAFKA_CONSUMER_GROUP_ID` 추가 → umbrella `helm dependency update` → 커밋 → Rollout `restartedAt` 패치로 재주입.
- **검증**: ArgoCD Synced/Healthy, 전 서비스 AVAILABLE=1, stores 1/1 Running(재시작 0), endpoint 복구([REDACTED]:8080), consumer group `stores-group` 파티션 할당 로그 확인.
- **개선**: ConfigMap 키 네이밍 규칙 통일(`SPRING_*`), 이미지의 placeholder 키와 Helm env 매핑을 CI 스모크 체크로 자동 검증.

## 7. Outbox CDC Kafka Connect 복구

- **증상**: `checkins-outbox-connector`, `payment-outbox-connector` 모두 task FAILED. 에러가 단계적으로 바뀌며 반복:
  `no pg_hba.conf entry` → `must be owner of publication` → `must be owner of table outbox_events` → `logical decoding requires "wal_level" >= "logical"`
- **원인**
  - CDC 계정(`qr_app`, `payment_app`)에 `rds_replication` 권한 없음
  - Debezium `publication.autocreate.mode=filtered` 특성상 publication/table 소유권 필요
  - RDS 파라미터 `rds.logical_replication=1`이 `pending-reboot` 상태라 실제 `wal_level=replica`
- **조치**
  ```sql
  GRANT rds_replication TO qr_app;
  GRANT rds_replication TO payment_app;
  GRANT CONNECT, CREATE ON DATABASE popcorn_prod TO qr_app, payment_app;
  ALTER PUBLICATION checkins_outbox_pub OWNER TO qr_app;
  ALTER PUBLICATION payment_outbox_pub  OWNER TO payment_app;
  ALTER TABLE checkins.outbox_events OWNER TO qr_app;
  ALTER TABLE payment.outbox_events  OWNER TO payment_app;
  ```
  RDS 재부팅으로 파라미터 `in-sync` → `POST /connectors/<name>/restart?includeTasks=true&onlyFailed=true`
- **검증**: `wal_level=logical`, 두 커넥터 RUNNING, replication slot 2개 `active=true`.
- **추가 보정 (스모크 테스트)**
  - `DataException: topic is not a valid field name` → outbox 테이블에 `topic` 컬럼이 없음. `transforms.outbox.route.by.field=aggregate_type`, `route.topic.replacement`를 `checkin-events`/`payment-events`로 지정.
  - 두 커넥터가 같은 `topic.prefix=popcorn`을 쓰면 Debezium 논리 서버명/오프셋 충돌로 한쪽 slot이 inactive가 될 수 있어 `popcorn-checkins-cdc`, `popcorn-payment-cdc`로 분리.
  - 최종: 두 토픽에서 스모크 이벤트 소비 확인.
- **권장**: `publication.autocreate.mode=disabled` + publication 사전 생성, 또는 CDC 전용 계정/소유권 정책 문서화.
