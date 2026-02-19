# 1순위 요청량(request) 튜닝 실행 내역 (Prod 기준)

작성일: 2026-02-18  
대상: `popcorn_deploy` 운영 환경 인프라 + 애플리케이션 Helm values(prod)

## 1) 작업 배경

클러스터 현재 상태에서 노드 수(4개)가 적고 노드당 요청 기준 사용량이 높았습니다.
`kubectl top nodes` 기준 CPU 요청이 거의 포화 상태였기 때문에,
실사용량 대비 과다한 `requests`를 선제적으로 낮춰 최소 사양에서 운영할 수 있도록 요청량 튜닝을 먼저 진행했습니다.

> 참고: 실제 트래픽이 낮은 상태 기준으로 진행한 1순위 조치이며, 부하 테스트 후 재조정이 필요합니다.

## 2) 변경 대상 파일 (prod)

### 애플리케이션 Umbrella
- `helm/popcorn-umbrella/values-prod.yaml`
  - `gateway/users/stores/order/payment/order-query`
    - CPU request `200m` → `100m`
    - CPU limit `1000m` → `500m`
    - Memory request/limit 유지(최소 동작 안정성 고려)
  - `checkins`
    - CPU request `100m` → `50m`
    - CPU limit `500m` → `300m`

### ArgoCD
- `infrastructure/argocd/values-prod.yaml`
  - `server.requests.cpu` `200m` → `100m`
  - `repoServer.requests.cpu` `200m` → `100m`
  - `controller.requests.cpu` `300m` → `150m`
  - 일부 memory/request, limit 완화

### External Secrets
- `infrastructure/external-secrets/values-prod.yaml`
  - Operator
    - requests `200m/256Mi` → `100m/128Mi`
    - limits `1000m/512Mi` → `500m/256Mi`
  - Webhook / Cert Controller
    - requests `100m/128Mi` → `50m/64Mi`
    - limits `500m/256Mi` → `250m/192Mi`

### Kafka
- `infrastructure/kafka/kafka/values-prod.yaml`
  - `controller.resources.requests.cpu` `500m` → `300m`
  - `controller.resources.requests.memory` `1Gi` → `768Mi`
  - `controller.resources.limits.cpu` `1000m` → `700m`
  - `controller.resources.limits.memory` `2Gi` → `1.5Gi`
- `infrastructure/kafka/kafka-ui/values-prod.yaml`
  - requests `100m/128Mi` → `50m/128Mi`

### LGTM
- `infrastructure/lgtm/grafana/values-prod.yaml`
  - requests `200m/256Mi` → `100m/128Mi`
  - limits `500m/512Mi` → `300m/512Mi`
- `infrastructure/lgtm/loki/values-prod.yaml`
  - requests `150m/256Mi` → `100m/192Mi`
  - limits `400m/512Mi` → `300m/512Mi`
- `infrastructure/lgtm/mimir/values-prod.yaml`
  - distributor/querier/query_frontend/query_scheduler/compactor/store_gateway/minio 등 CPU·memory request를 다단계 하향
- `infrastructure/lgtm/tempo/values-prod.yaml`
  - requests `150m/384Mi` → `100m/256Mi`
  - limits `600m/1Gi` → `500m/1Gi`

### OTel Collector
- `infrastructure/otel/values-prod.yaml`
  - requests `200m/384Mi` → `100m/256Mi`
  - limits `800m/1Gi` → `400m/768Mi`

## 3) 적용 순서

아래 순서로 `helm upgrade` 적용 권장:

1. `helm upgrade --install argocd argo/argo-cd ...`
2. `helm upgrade --install external-secrets external-secrets/...`
3. `helm upgrade --install kafka-prod bitnami/kafka ...`
4. `helm upgrade --install kafka-ui kafka-ui/kafka-ui ...`
5. `helm upgrade --install loki grafana/loki ...`
6. `helm upgrade --install tempo grafana/tempo ...`
7. `helm upgrade --install mimir grafana/mimir-distributed ...`
8. `helm upgrade --install grafana grafana/grafana ...`
9. `helm upgrade --install otel-collector open-telemetry/opentelemetry-collector ...`

## 4) 검증 체크리스트

### 적용 직후 확인
- `kubectl get pods -n argocd`  
- `kubectl get pods -n external-secrets`  
- `kubectl get pods -n kafka`  
- `kubectl get pods -n monitoring`
- `kubectl top pods -A --sort-by=cpu`
- `kubectl top nodes`
- `kubectl get events -A --field-selector reason=FailedScheduling`

### 확인 기준
- 스케줄링 실패 이벤트 없음
- `kafka-ui`, `otel-collector`, `mimir/tempo/loki/grafana`, `argocd`, `external-secrets` 모두 `Running/Ready`
- 노드별 CPU 요청률이 개선(100~95% 초과 감소 추세), 빈 Pod 재스케줄 필요 없음

## 5) 다음 단계(우선순위 2로 연계)

이후 2순위로는 아래를 진행해야 합니다.
- `limits`는 실사용 기반으로 추가 안정화 (현재는 1순위에서 request 위주 축소)
- 필요 시 `nodegroup` `desired/min` 축소 및 Karpenter `NodePool` 분리 정책 검토
- Kafka 파드 안정성 검증(부하 테스트 후 controller 메모리 오버헤드 추가 보정)
