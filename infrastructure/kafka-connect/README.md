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

### 1) Secret 준비

```bash
# 예시: 동일 RDS를 사용하면서 권한 계정을 분리해 주입
kubectl -n kafka create secret generic popcorn-cdc-db-credentials \
  --from-literal=CHECKINS_DB_HOST=<rds-endpoint> \
  --from-literal=CHECKINS_DB_PORT=5432 \
  --from-literal=CHECKINS_DB_NAME=popcorn_prod \
  --from-literal=CHECKINS_DB_USER=<checkins-replication-user> \
  --from-literal=CHECKINS_DB_PASSWORD=<password> \
  --from-literal=PAYMENT_DB_HOST=<rds-endpoint> \
  --from-literal=PAYMENT_DB_PORT=5432 \
  --from-literal=PAYMENT_DB_NAME=popcorn_prod \
  --from-literal=PAYMENT_DB_USER=<payment-replication-user> \
  --from-literal=PAYMENT_DB_PASSWORD=<password> \
  --dry-run=client -o yaml | kubectl apply -f -
```

### 2) `values-prod.yaml`에 커넥터 정의 추가

```yaml
# 실제 prod values에는 checkins/payment 2개 커넥터가 기본 정의되어 있습니다.
# (checkins-outbox-connector, payment-outbox-connector)
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
