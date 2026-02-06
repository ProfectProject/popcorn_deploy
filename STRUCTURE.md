# Popcorn Deploy 디렉터리 구조

## 전체 구조

```
popcorn_deploy/
│
├── helm/                                    # 애플리케이션 Helm Charts
│   │
│   ├── charts/                              # 개별 서비스 차트
│   │   │
│   │   ├── common/                          # 공통 라이브러리 차트
│   │   │   ├── Chart.yaml
│   │   │   └── templates/
│   │   │       ├── _helpers.tpl             # 헬퍼 함수
│   │   │       ├── _deployment.yaml         # 공통 Deployment 템플릿
│   │   │       ├── _service.yaml            # 공통 Service 템플릿
│   │   │       ├── _hpa.yaml                # 공통 HPA 템플릿
│   │   │       └── _serviceaccount.yaml     # 공통 ServiceAccount 템플릿
│   │   │
│   │   ├── gateway/                         # API Gateway
│   │   │   ├── Chart.yaml
│   │   │   ├── values.yaml
│   │   │   └── templates/
│   │   │       ├── deployment.yaml
│   │   │       ├── service.yaml
│   │   │       ├── serviceaccount.yaml
│   │   │       ├── hpa.yaml
│   │   │       ├── configmap.yaml
│   │   │       └── ingress.yaml
│   │   │
│   │   ├── users/                           # User Service
│   │   │   ├── Chart.yaml
│   │   │   ├── values.yaml
│   │   │   └── templates/
│   │   │       ├── deployment.yaml
│   │   │       ├── service.yaml
│   │   │       ├── serviceaccount.yaml
│   │   │       ├── hpa.yaml
│   │   │       └── configmap.yaml
│   │   │
│   │   ├── stores/                          # Store Service
│   │   │   ├── Chart.yaml
│   │   │   ├── values.yaml
│   │   │   └── templates/
│   │   │
│   │   ├── order/                           # Order Service (Command)
│   │   │   ├── Chart.yaml
│   │   │   ├── values.yaml
│   │   │   └── templates/
│   │   │
│   │   ├── payment/                         # Payment Service
│   │   │   ├── Chart.yaml
│   │   │   ├── values.yaml
│   │   │   └── templates/
│   │   │
│   │   ├── orderQuery/                      # Order Query Service (CQRS)
│   │   │   ├── Chart.yaml
│   │   │   ├── values.yaml
│   │   │   └── templates/
│   │   │
│   │   └── checkIns/                        # CheckIn Service (QR 포함)
│   │       ├── Chart.yaml
│   │       ├── values.yaml
│   │       └── templates/
│   │
│   └── popcorn-umbrella/                    # Umbrella Chart (통합 관리)
│       ├── Chart.yaml                       # 의존성 정의
│       ├── values.yaml                      # 기본 설정
│       ├── values-dev.yaml                  # 개발 환경 오버라이드
│       └── values-prod.yaml                 # 운영 환경 오버라이드
│
├── infrastructure/                          # 인프라 컴포넌트
│   │
│   ├── lgtm/                                # LGTM Stack (Observability)
│   │   ├── README.md
│   │   ├── loki/                            # 로그 수집 및 저장
│   │   │   ├── values.yaml
│   │   │   ├── values-dev.yaml
│   │   │   └── values-prod.yaml
│   │   ├── grafana/                         # 시각화 및 대시보드
│   │   │   ├── values.yaml
│   │   │   ├── values-dev.yaml
│   │   │   └── values-prod.yaml
│   │   ├── tempo/                           # 분산 추적
│   │   │   ├── values.yaml
│   │   │   ├── values-dev.yaml
│   │   │   └── values-prod.yaml
│   │   └── mimir/                           # 메트릭 저장
│   │       ├── values.yaml
│   │       ├── values-dev.yaml
│   │       └── values-prod.yaml
│   │
│   ├── kafka/                               # Kafka Ecosystem
│   │   ├── README.md
│   │   ├── kafka/                           # Kafka (KRaft 모드)
│   │   │   ├── values.yaml
│   │   │   ├── values-dev.yaml
│   │   │   └── values-prod.yaml
│   │   └── kafka-ui/                        # Kafka 관리 UI
│   │       ├── values.yaml
│   │       ├── values-dev.yaml
│   │       └── values-prod.yaml
│   │
│   ├── argocd/                              # ArgoCD (GitOps)
│   │   ├── README.md
│   │   ├── values.yaml
│   │   ├── values-dev.yaml
│   │   └── values-prod.yaml
│   │
│   ├── scripts/                             # 설치 스크립트
│   │   ├── install-argocd.sh               # ArgoCD 설치
│   │   ├── install-kafka.sh                # Kafka 설치
│   │   ├── install-lgtm.sh                 # LGTM Stack 설치
│   │   ├── install-all.sh                  # 전체 설치
│   │   └── uninstall-all.sh                # 전체 제거
│   │
│   └── README.md                            # 인프라 가이드
│
├── argocd/                                  # ArgoCD Application 정의
│   ├── dev/
│   │   └── application.yaml                # 개발 환경 Application
│   └── prod/
│       └── application.yaml                # 운영 환경 Application
│
├── README.md                                # 프로젝트 개요
├── DEPLOYMENT_GUIDE.md                      # 배포 가이드
└── STRUCTURE.md                             # 이 문서

```

## 주요 디렉터리 설명

### 1. helm/charts/
개별 마이크로서비스의 Helm Chart를 관리합니다. 각 서비스는 독립적으로 배포 가능하며, 공통 라이브러리 차트를 재사용합니다.

### 2. helm/popcorn-umbrella/
모든 마이크로서비스를 하나의 릴리스로 관리하는 Umbrella Chart입니다. 환경별 values 파일로 설정을 오버라이드합니다.

### 3. infrastructure/
Kubernetes 클러스터에 필요한 인프라 컴포넌트(모니터링, 메시징, GitOps)를 관리합니다.

### 4. argocd/
ArgoCD Application 리소스 정의로, GitOps 기반 자동 배포를 설정합니다.

## 파일 명명 규칙

### Values 파일
- `values.yaml`: 기본 설정 (모든 환경 공통)
- `values-dev.yaml`: 개발 환경 오버라이드
- `values-prod.yaml`: 운영 환경 오버라이드

### 스크립트 파일
- `install-*.sh`: 설치 스크립트
- `uninstall-*.sh`: 제거 스크립트

## 배포 흐름

```
1. 인프라 설치
   └─> infrastructure/scripts/install-all.sh

2. ArgoCD Application 생성
   └─> kubectl apply -f argocd/prod/application.yaml

3. Git Push
   └─> ArgoCD가 자동으로 감지하고 배포

4. 모니터링
   └─> Grafana 대시보드에서 확인
```

## 환경별 네임스페이스

- `popcorn-dev`: 개발 환경 애플리케이션
- `popcorn-prod`: 운영 환경 애플리케이션
- `monitoring`: LGTM Stack
- `kafka`: Kafka 및 Kafka UI
- `argocd`: ArgoCD

## 참고 자료

- [Helm 공식 문서](https://helm.sh/docs/)
- [ArgoCD 공식 문서](https://argo-cd.readthedocs.io/)
- [Grafana LGTM](https://grafana.com/oss/)
- [Apache Kafka](https://kafka.apache.org/)
