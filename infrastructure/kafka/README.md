# Kafka Ecosystem

Apache Kafka 및 관리 도구 설치 및 관리

## 개요

- **Kafka**: 이벤트 스트리밍 플랫폼 (KRaft 모드)
- **Kafka UI**: Kafka 클러스터 관리 웹 UI

## Helm Repository

```bash
# Bitnami Kafka
helm repo add bitnami https://charts.bitnami.com/bitnami

# Kafka UI
helm repo add kafka-ui https://provectus.github.io/kafka-ui-charts

helm repo update
```

## 네임스페이스

```bash
kubectl create namespace kafka
```

## 설치 명령어

### Kafka (KRaft 모드)
```bash
helm upgrade --install kafka bitnami/kafka \
  --namespace kafka \
  --values kafka/values.yaml \
  --values kafka/values-prod.yaml
```

### Kafka UI
```bash
helm upgrade --install kafka-ui kafka-ui/kafka-ui \
  --namespace kafka \
  --values kafka-ui/values.yaml \
  --values kafka-ui/values-prod.yaml
```

## 접속 정보

### Kafka 브로커
- 내부 접속: `kafka:9092`
- 외부 접속: NodePort 또는 LoadBalancer 설정 필요

### Kafka UI
```bash
# 포트 포워딩
kubectl port-forward -n kafka svc/kafka-ui 8080:80

# 브라우저에서 접속
open http://localhost:8080
```

## 토픽 관리

### CLI로 토픽 생성
```bash
kubectl exec -it kafka-0 -n kafka -- kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create \
  --topic order-events \
  --partitions 3 \
  --replication-factor 3
```

### Kafka UI에서 관리
- 토픽 생성/삭제
- 메시지 조회
- 컨슈머 그룹 모니터링
- 브로커 상태 확인

## 주요 토픽

Popcorn MSA에서 사용하는 토픽:
- `order-events`: 주문 이벤트
- `payment-events`: 결제 이벤트
- `user-events`: 사용자 이벤트
- `store-events`: 스토어 이벤트
- `checkin-events`: 체크인 이벤트

## 모니터링

- Kafka UI를 통한 실시간 모니터링
- Prometheus 메트릭 수집
- Grafana 대시보드 연동
