# Kafka Connect on EKS (Helm/GitOps)

`debezium/connect:2.7.3.Final` 기반 Kafka Connect를 Helm 차트로 운영합니다.

## 운영 기준

- Kafka/Connect는 **Helm 차트 + ArgoCD** 기준으로만 관리합니다.
- 수동 `kubectl patch/set image`는 금지하고, 값 변경은 Git 커밋으로 반영합니다.
- 현재 기본값:
  - prod: `replicaCount=1`, `bootstrapServers=kafka-prod:9092`
  - dev: `replicaCount=0` (불필요 CrashLoop/비용 방지)

## ArgoCD Application

- `/Users/beom/IdeaProjects/popcorn_deploy/applications/prod/kafka-connect.yaml`
- `/Users/beom/IdeaProjects/popcorn_deploy/applications/dev/kafka-connect.yaml`

적용:

```bash
kubectl apply -f applications/prod/kafka-connect.yaml
kubectl apply -f applications/dev/kafka-connect.yaml
```

## Outbox CDC 커넥터 GitOps 등록

차트에 `connectorBootstrap` Job이 추가되어, 커넥터 정의를 values에 두고 Sync 시 REST API로 upsert 할 수 있습니다.

### 1) Secret 준비 (예시)

```bash
kubectl -n kafka create secret generic popcorn-cdc-db-credentials \
  --from-literal=CHECKINS_DB_HOST=<rds-endpoint> \
  --from-literal=CHECKINS_DB_USER=<user> \
  --from-literal=CHECKINS_DB_PASSWORD=<password> \
  --from-literal=PAYMENT_DB_HOST=<rds-endpoint> \
  --from-literal=PAYMENT_DB_USER=<user> \
  --from-literal=PAYMENT_DB_PASSWORD=<password>
```

### 2) `values-prod.yaml`에 커넥터 정의 추가

```yaml
connectorBootstrap:
  enabled: true
  envFromSecrets:
    - popcorn-cdc-db-credentials
  connectors:
    - name: checkins-outbox-connector
      config:
        connector.class: io.debezium.connector.postgresql.PostgresConnector
        database.hostname: ${CHECKINS_DB_HOST}
        database.port: "5432"
        database.user: ${CHECKINS_DB_USER}
        database.password: ${CHECKINS_DB_PASSWORD}
        database.dbname: popcorn_prod
        plugin.name: pgoutput
        slot.name: checkins_outbox_slot
        publication.autocreate.mode: filtered
        schema.include.list: checkins
        table.include.list: checkins.outbox_events
        topic.prefix: popcorn
        transforms: outbox
        transforms.outbox.type: io.debezium.transforms.outbox.EventRouter
        transforms.outbox.table.field.event.id: event_id
        transforms.outbox.table.field.event.key: partition_key
        transforms.outbox.table.field.event.type: event_type
        transforms.outbox.table.field.event.payload: event_data
        transforms.outbox.table.expand.json.payload: "true"
        transforms.outbox.route.by.field: topic
        transforms.outbox.route.topic.replacement: ${routedByValue}
        key.converter: org.apache.kafka.connect.storage.StringConverter
        value.converter: org.apache.kafka.connect.json.JsonConverter
        value.converter.schemas.enable: "false"
```

### 3) Sync 후 확인

```bash
kubectl -n argocd get app popcorn-prod-kafka-connect

CONNECT_SVC=$(kubectl -n kafka get svc -l app.kubernetes.io/component=kafka-connect -o jsonpath='{.items[0].metadata.name}')
kubectl -n kafka port-forward svc/${CONNECT_SVC} 18083:8083

curl -s http://127.0.0.1:18083/connectors | jq
curl -s http://127.0.0.1:18083/connectors/checkins-outbox-connector/status | jq
```

## 주의사항

- `host.docker.internal`는 EKS에서 동작하지 않으므로 RDS 엔드포인트를 사용해야 합니다.
- `connect-configs`, `connect-offsets`, `connect-status` 토픽은 사전에 적절한 replication factor를 유지해야 합니다.
- 커넥터 등록 실패 시 다음 로그를 먼저 확인하세요:

```bash
kubectl -n kafka logs deploy/popcorn-prod-kafka-connect-kafka-connect
kubectl -n kafka logs job/popcorn-prod-kafka-connect-kafka-connect-connector-bootstrap --tail=200
```
