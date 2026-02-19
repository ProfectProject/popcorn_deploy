# Kafka Ecosystem

Popcorn Deploy 레포에서 Kafka(KRaft)와 Kafka UI를 설치/운영하는 가이드입니다.

## 디렉터리 구조

```text
infrastructure/
├── kafka/
│   ├── kafka/
│   │   ├── values.yaml
│   │   ├── values-dev.yaml
│   │   └── values-prod.yaml
│   └── kafka-ui/
│       ├── values.yaml
│       ├── values-dev.yaml
│       └── values-prod.yaml
└── scripts/
    └── install-kafka.sh
```

## 구성 요소

- **Kafka**: Bitnami Kafka Helm Chart 기반 KRaft 모드
- **Kafka UI**: Provectus Kafka UI

## 사전 준비

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add kafka-ui https://provectus.github.io/kafka-ui-charts
helm repo update
```

## 설치 방법

### 1. 권장: 스크립트 설치

레포 루트(`/Users/beom/IdeaProjects/popcorn_deploy`) 기준:

```bash
./infrastructure/scripts/install-kafka.sh prod
# 또는
./infrastructure/scripts/install-kafka.sh dev
```

### 2. 수동 Helm 설치

```bash
kubectl create namespace kafka --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install kafka-prod bitnami/kafka \
  --namespace kafka \
  --values infrastructure/kafka/kafka/values.yaml \
  --values infrastructure/kafka/kafka/values-prod.yaml \
  --wait \
  --timeout 10m

helm upgrade --install kafka-ui kafka-ui/kafka-ui \
  --namespace kafka \
  --values infrastructure/kafka/kafka-ui/values.yaml \
  --values infrastructure/kafka/kafka-ui/values-prod.yaml \
  --wait
```

## KRaft 상태 확인

```bash
# Kafka Controller quorum 상태 확인
kubectl exec -n kafka kafka-prod-controller-0 -- \
  kafka-metadata-quorum.sh --bootstrap-controller localhost:9093 describe --status
```

정상 상태라면 `LeaderId`, `CurrentVoters` 등의 quorum 정보가 출력됩니다.

## 접속 정보

- Kafka 내부 접속: `kafka-prod:9092`
- Kafka UI 도메인: `https://kafka.goormpopcorn.shop`
- Kafka UI 포트포워딩:

```bash
kubectl port-forward -n kafka svc/kafka-ui 8080:80
```

브라우저 접속: `http://localhost:8080`

## 토픽 관리

### CLI로 토픽 생성

```bash
kubectl exec -it kafka-prod-controller-0 -n kafka -- kafka-topics.sh \
  --bootstrap-server kafka-prod:9092 \
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

- `order-events`: 주문 이벤트
- `payment-events`: 결제 이벤트
- `user-events`: 사용자 이벤트
- `store-events`: 스토어 이벤트
- `checkin-events`: 체크인 이벤트
