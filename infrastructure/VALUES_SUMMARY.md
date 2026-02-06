# Infrastructure Values 설정 요약

## 개요

모든 인프라 컴포넌트의 values 파일이 작성되었습니다. 각 컴포넌트는 환경별(dev, prod) 설정을 지원합니다.

## 작성된 Values 파일

### 1. ArgoCD (GitOps)
```
infrastructure/argocd/
├── values.yaml           ✅ 기본 설정
├── values-dev.yaml       ✅ 개발 환경 (1 replica, 최소 리소스)
└── values-prod.yaml      ✅ 운영 환경 (2+ replicas, HA, 오토스케일링)
```

**주요 설정:**
- Server, Repo Server, Controller 구성
- Ingress 설정 (ALB)
- RBAC 정책
- Git 저장소 연동

### 2. Kafka (Event Streaming)
```
infrastructure/kafka/
├── kafka/
│   ├── values.yaml       ✅ KRaft 모드, 3 replicas
│   ├── values-dev.yaml   ✅ 1 replica, 최소 리소스
│   └── values-prod.yaml  ✅ 3 replicas, HA, 50Gi 스토리지
└── kafka-ui/
    ├── values.yaml       ✅ 기본 UI 설정
    ├── values-dev.yaml   ✅ 개발 환경
    └── values-prod.yaml  ✅ 운영 환경 (2 replicas, Ingress)
```

**주요 설정:**
- KRaft 모드 (ZooKeeper 불필요)
- 로그 보관 정책 (dev: 1일, prod: 7일)
- 복제 팩터 (dev: 1, prod: 3)
- JMX 메트릭 활성화

### 3. LGTM Stack (Observability)

#### Loki (로그)
```
infrastructure/lgtm/loki/
├── values.yaml           ✅ SingleBinary 모드
├── values-dev.yaml       ✅ 1 replica, 5Gi, 1일 보관
└── values-prod.yaml      ✅ SimpleScalable, 3 replicas, 50Gi, 7일 보관
```

#### Grafana (시각화)
```
infrastructure/lgtm/grafana/
├── values.yaml           ✅ 데이터 소스 자동 구성
├── values-dev.yaml       ✅ 1 replica, 5Gi
└── values-prod.yaml      ✅ 2 replicas, 20Gi, Ingress, HA
```

**사전 구성된 데이터 소스:**
- Loki (로그)
- Tempo (추적)
- Mimir (메트릭)

**사전 구성된 대시보드:**
- Kubernetes Cluster (ID: 7249)
- Kubernetes Pods (ID: 6417)
- Loki Logs (ID: 13639)

#### Tempo (분산 추적)
```
infrastructure/lgtm/tempo/
├── values.yaml           ✅ SingleBinary 모드
├── values-dev.yaml       ✅ 1 replica, 5Gi, 1일 보관
└── values-prod.yaml      ✅ Distributed, 여러 컴포넌트, 7일 보관
```

#### Mimir (메트릭)
```
infrastructure/lgtm/mimir/
├── values.yaml           ✅ SingleBinary 모드
├── values-dev.yaml       ✅ 1 replica, 5Gi
└── values-prod.yaml      ✅ Distributed, 여러 컴포넌트, 50Gi
```

## 환경별 리소스 비교

### 개발 환경 (Dev)
| 컴포넌트 | Replicas | CPU Request | Memory Request | Storage |
|----------|----------|-------------|----------------|---------|
| ArgoCD Server | 1 | 50m | 128Mi | - |
| Kafka | 1 | 100m | 256Mi | 5Gi |
| Kafka UI | 1 | 50m | 128Mi | - |
| Loki | 1 | 50m | 128Mi | 5Gi |
| Grafana | 1 | 50m | 128Mi | 5Gi |
| Tempo | 1 | 50m | 128Mi | 5Gi |
| Mimir | 1 | 50m | 128Mi | 5Gi |

**총 리소스:**
- CPU: ~400m
- Memory: ~1Gi
- Storage: ~30Gi

### 운영 환경 (Prod)
| 컴포넌트 | Replicas | CPU Request | Memory Request | Storage |
|----------|----------|-------------|----------------|---------|
| ArgoCD Server | 2 | 200m | 256Mi | - |
| Kafka | 3 | 500m | 1Gi | 50Gi |
| Kafka UI | 2 | 200m | 512Mi | - |
| Loki (total) | 7 | 1000m | 2.5Gi | 100Gi |
| Grafana | 2 | 200m | 512Mi | 20Gi |
| Tempo (total) | 10 | 1200m | 3Gi | 100Gi |
| Mimir (total) | 12 | 2000m | 5Gi | 150Gi |

**총 리소스:**
- CPU: ~5000m (5 cores)
- Memory: ~12Gi
- Storage: ~420Gi

## 설치 순서

```bash
# 1. ArgoCD 설치 (GitOps 먼저)
cd infrastructure/scripts
./install-argocd.sh prod

# 2. Kafka 설치
./install-kafka.sh prod

# 3. LGTM Stack 설치
./install-lgtm.sh prod

# 또는 한 번에 설치
./install-all.sh prod
```

## 접속 정보

### ArgoCD
```bash
kubectl port-forward -n argocd svc/argocd-server 8080:443
# URL: https://localhost:8080
# User: admin
# Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Kafka UI
```bash
kubectl port-forward -n kafka svc/kafka-ui 8080:80
# URL: http://localhost:8080
```

### Grafana
```bash
kubectl port-forward -n monitoring svc/grafana 3000:80
# URL: http://localhost:3000
# User: admin
# Password: kubectl get secret -n monitoring grafana -o jsonpath="{.data.admin-password}" | base64 -d
```

## 커스터마이징

### 도메인 변경
각 values 파일에서 `goormpopcorn.shop`을 실제 도메인으로 변경:
- `argocd/values.yaml`: `global.domain`
- `kafka-ui/values.yaml`: `ingress.hosts`
- `grafana/values.yaml`: `ingress.hosts`, `env.GF_SERVER_ROOT_URL`

### ACM 인증서 ARN 변경
운영 환경 values 파일에서 인증서 ARN 업데이트:
```yaml
ingress:
  annotations:
    alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:ap-northeast-2:375896310755:certificate/YOUR_CERT_ID"
```

### 스토리지 클래스 변경
기본값은 `gp3`이며, 필요시 변경:
```yaml
persistence:
  storageClass: "gp3"  # 또는 "ebs-sc", "efs-sc" 등
```

### 리소스 조정
각 컴포넌트의 리소스는 실제 사용량에 따라 조정:
```yaml
resources:
  requests:
    cpu: 200m
    memory: 512Mi
  limits:
    cpu: 1000m
    memory: 1Gi
```

## 모니터링 통합

### Prometheus 메트릭 수집
모든 컴포넌트는 Prometheus 메트릭을 노출합니다:
- ArgoCD: `:8082/metrics`
- Kafka: JMX Exporter (`:9997`)
- Grafana: `:3000/metrics`

### Grafana 대시보드
Grafana에 자동으로 구성되는 데이터 소스:
1. **Loki**: 로그 조회 및 분석
2. **Tempo**: 분산 추적 시각화
3. **Mimir**: 메트릭 쿼리 및 알림

## 보안 고려사항

### 운영 환경 체크리스트
- [ ] Grafana admin 비밀번호 변경
- [ ] ArgoCD admin 비밀번호 변경
- [ ] Kafka UI 인증 활성화
- [ ] Ingress TLS 인증서 설정
- [ ] RBAC 정책 검토
- [ ] Network Policy 적용
- [ ] Secret 암호화 (Sealed Secrets 또는 External Secrets)

## 트러블슈팅

### Pod가 Pending 상태
```bash
# 스토리지 클래스 확인
kubectl get storageclass

# PVC 상태 확인
kubectl get pvc -n <namespace>
```

### 메모리 부족 (OOMKilled)
리소스 limits 증가:
```yaml
resources:
  limits:
    memory: 2Gi  # 증가
```

### 디스크 공간 부족
스토리지 크기 증가 (PVC 확장):
```bash
kubectl edit pvc <pvc-name> -n <namespace>
# spec.resources.requests.storage 값 증가
```

## 참고 자료

- [ArgoCD Helm Chart](https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd)
- [Bitnami Kafka Chart](https://github.com/bitnami/charts/tree/main/bitnami/kafka)
- [Grafana Loki Chart](https://github.com/grafana/loki/tree/main/production/helm/loki)
- [Grafana Tempo Chart](https://github.com/grafana/helm-charts/tree/main/charts/tempo)
- [Grafana Mimir Chart](https://github.com/grafana/mimir/tree/main/operations/helm/charts/mimir-distributed)
