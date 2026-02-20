# Kafka Connect on EKS

`debezium/connect:2.7` 기반 Kafka Connect를 ArgoCD로 배포하는 설정입니다.

## 배포 방식

1. `Deployment`는 Helm 차트로 렌더링됩니다.
2. 배포 리소스는 `kafka` 네임스페이스에서 실행됩니다.
3. 값 오버라이드는 환경별 파일(`values-dev.yaml`, `values-prod.yaml`)로 분리되어 있습니다.

## 현재 ArgoCD Application

- `applications/dev/kafka-connect.yaml`
- `applications/prod/kafka-connect.yaml`

적용:

```bash
kubectl apply -f applications/dev/kafka-connect.yaml
kubectl apply -f applications/prod/kafka-connect.yaml
```

## compose 기반 대비 (EKS 적용 포인트)

- `kafka` 서비스는 `kafka-prod:9092`로 변경
- `host.docker.internal`는 EKS에서 동작하지 않으므로 RDS 엔드포인트 또는 클러스터 내 DB Service DNS로 변경
- `kafka-connect`는 `kafka-connect` Deployment(Service)로 분리
- `docker-compose`의 `kafka-connect` 환경변수는 Helm values로 주입해 관리

## DB 접속 정보 주입 방법

`debezium` 커넥터에서 사용할 DB 사용자/비밀번호는 Secret으로 넣고 `values.yaml` `pod.extraEnv`로 주입하세요.

예시:

```bash
kubectl -n kafka create secret generic popcorn-cdc-db-credentials \
  --from-literal=CHECKINS_DB_USER=qr_app \
  --from-literal=CHECKINS_DB_PASSWORD=비밀번호 \
  --from-literal=PAYMENT_DB_USER=payment_app \
  --from-literal=PAYMENT_DB_PASSWORD=비밀번호
```

차트에 아래 항목을 추가해주면 됩니다.

```yaml
pod:
  extraEnv:
    - name: CHECKINS_DB_USER
      valueFrom:
        secretKeyRef:
          name: popcorn-cdc-db-credentials
          key: CHECKINS_DB_USER
```

`valueFrom`도 함께 지원됩니다.
민감정보는 **Secret 참조 방식**으로 관리하는 것을 권장합니다.

## ArgoCD 배포 후 기본 확인

```bash
kubectl get pods -n kafka -l app.kubernetes.io/component=kafka-connect
kubectl -n kafka port-forward svc/kafka-connect 18083:8083
curl -s http://127.0.0.1:18083/connectors | jq
```

## 주의

- 아직 `Kafka Connect` 커넥터 등록은 API 호출(`POST /connectors`) 단계가 별도입니다.
- 권한 제한으로 `kafka-connect`가 컨테이너 내부에서 Connector 등록 권한을 갖는지 확인하려면
  `kubectl -n kafka logs deploy/kafka-connect`로 Connect 기동 로그를 먼저 확인하세요.
