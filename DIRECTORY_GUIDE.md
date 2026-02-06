# 디렉터리 가이드

Popcorn Deploy 프로젝트의 디렉터리 구조와 각 디렉터리의 용도를 설명합니다.

## 전체 구조 개요

```
popcorn_deploy/
├── helm/                      # 애플리케이션 배포
├── infrastructure/            # 인프라 설치
└── applications/              # ArgoCD 배포 정의
```

## 상세 구조

### 1. `/helm` - 애플리케이션 Helm Charts

**용도**: Popcorn MSA 애플리케이션의 Helm Chart

```
helm/
├── charts/                    # 개별 서비스 차트
│   ├── common/               # 공통 라이브러리
│   ├── gateway/              # API Gateway
│   ├── users/                # User Service
│   ├── stores/               # Store Service
│   ├── order/                # Order Service
│   ├── payment/              # Payment Service
│   ├── orderQuery/           # Order Query Service
│   └── checkIns/             # CheckIn Service
└── popcorn-umbrella/         # 통합 관리 차트
    ├── values.yaml           # 기본 설정
    ├── values-dev.yaml       # 개발 환경
    └── values-prod.yaml      # 운영 환경
```

**특징**:
- 각 마이크로서비스를 독립적으로 배포 가능
- Umbrella Chart로 전체 서비스 통합 관리
- 공통 라이브러리로 템플릿 재사용

### 2. `/infrastructure` - 인프라 컴포넌트

**용도**: Kubernetes 클러스터에 필요한 인프라 설치

```
infrastructure/
├── lgtm/                      # 관찰성 스택
│   ├── loki/                 # 로그 수집
│   ├── grafana/              # 시각화
│   ├── tempo/                # 분산 추적
│   └── mimir/                # 메트릭 저장
├── kafka/                     # 이벤트 스트리밍
│   ├── kafka/                # Kafka
│   └── kafka-ui/             # Kafka UI
├── argocd/                    # GitOps 도구
│   ├── values.yaml           # ArgoCD 설치 설정
│   ├── values-dev.yaml
│   └── values-prod.yaml
└── scripts/                   # 설치 스크립트
    ├── install-argocd.sh
    ├── install-kafka.sh
    ├── install-lgtm.sh
    ├── install-all.sh
    └── uninstall-all.sh
```

**특징**:
- Helm values 파일로 각 OSS 설정 관리
- 환경별(dev, prod) 설정 분리
- 자동화 스크립트 제공

### 3. `/applications` - ArgoCD Application CRD

**용도**: ArgoCD로 애플리케이션을 배포하기 위한 정의

```
applications/
├── dev/
│   └── application.yaml      # 개발 환경 배포 정의
└── prod/
    └── application.yaml      # 운영 환경 배포 정의
```

**특징**:
- Kubernetes CRD (Custom Resource Definition)
- Git 저장소와 Helm Chart 연결
- 자동 동기화 정책 정의

## 디렉터리별 사용 시나리오

### 시나리오 1: 새로운 환경 구축

```bash
# 1. 인프라 설치
cd infrastructure/scripts
./install-all.sh prod

# 2. ArgoCD Application 생성
kubectl apply -f ../../applications/prod/application.yaml

# 3. ArgoCD가 자동으로 애플리케이션 배포
# (helm/popcorn-umbrella 차트 사용)
```

### 시나리오 2: 애플리케이션 설정 변경

```bash
# helm/popcorn-umbrella/values-prod.yaml 수정
vim helm/popcorn-umbrella/values-prod.yaml

# Git에 커밋 및 푸시
git add helm/popcorn-umbrella/values-prod.yaml
git commit -m "Update production values"
git push

# ArgoCD가 자동으로 감지하고 배포
```

### 시나리오 3: 인프라 설정 변경

```bash
# infrastructure/kafka/kafka/values-prod.yaml 수정
vim infrastructure/kafka/kafka/values-prod.yaml

# Helm으로 직접 업그레이드
helm upgrade kafka bitnami/kafka \
  --namespace kafka \
  --values infrastructure/kafka/kafka/values.yaml \
  --values infrastructure/kafka/kafka/values-prod.yaml
```

### 시나리오 4: 새로운 서비스 추가

```bash
# 1. 새 서비스 차트 생성
mkdir -p helm/charts/new-service
cp -r helm/charts/users/* helm/charts/new-service/

# 2. Umbrella Chart에 추가
vim helm/popcorn-umbrella/Chart.yaml
# dependencies에 new-service 추가

# 3. Values 설정
vim helm/popcorn-umbrella/values.yaml
# new-service 설정 추가

# 4. Git 커밋 및 푸시
git add helm/
git commit -m "Add new service"
git push

# ArgoCD가 자동으로 새 서비스 배포
```

## 헷갈리기 쉬운 부분

### ArgoCD 관련 디렉터리

❌ **혼동하기 쉬운 점**:
- `/infrastructure/argocd`와 `/applications`가 모두 ArgoCD 관련

✅ **명확한 구분**:

| 디렉터리 | 용도 | 내용 | 사용 시점 |
|---------|------|------|----------|
| `/infrastructure/argocd` | ArgoCD 설치 | Helm values | 클러스터 초기 구축 |
| `/applications` | 애플리케이션 배포 | Application CRD | ArgoCD 설치 후 |

**예시**:
```bash
# 1단계: ArgoCD 설치 (infrastructure/argocd 사용)
helm install argocd argo/argo-cd \
  --values infrastructure/argocd/values-prod.yaml

# 2단계: 애플리케이션 배포 (applications 사용)
kubectl apply -f applications/prod/application.yaml
```

### Helm Chart vs Helm Values

❌ **혼동하기 쉬운 점**:
- `/helm`과 `/infrastructure`가 모두 Helm 관련

✅ **명확한 구분**:

| 디렉터리 | 내용 | 관리 대상 |
|---------|------|----------|
| `/helm` | 자체 개발 Chart | Popcorn MSA 서비스 |
| `/infrastructure` | 외부 Chart의 Values | OSS (Kafka, Grafana 등) |

## 파일 명명 규칙

### Values 파일
- `values.yaml`: 기본 설정 (모든 환경 공통)
- `values-dev.yaml`: 개발 환경 오버라이드
- `values-prod.yaml`: 운영 환경 오버라이드

### 스크립트 파일
- `install-*.sh`: 설치 스크립트
- `uninstall-*.sh`: 제거 스크립트

### Application 파일
- `application.yaml`: ArgoCD Application CRD

## 권장 워크플로우

### 개발 환경
```
1. 로컬에서 Helm Chart 수정
2. Git 커밋 및 푸시
3. ArgoCD 자동 동기화 (dev 환경)
4. 테스트 및 검증
```

### 운영 환경
```
1. 개발 환경에서 검증 완료
2. Git 태그 생성 (v1.0.0)
3. ArgoCD에서 수동 동기화
4. 배포 확인 및 모니터링
```

## 참고 문서

- [README.md](README.md): 프로젝트 개요
- [STRUCTURE.md](STRUCTURE.md): 상세 디렉터리 구조
- [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md): 배포 가이드
- [infrastructure/README.md](infrastructure/README.md): 인프라 가이드
- [applications/README.md](applications/README.md): Application CRD 가이드
