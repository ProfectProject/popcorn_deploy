# Individual Service Charts

개별 마이크로서비스의 Helm Chart 모음입니다.

## 차트 목록

### 1. common
**타입**: Library Chart  
**용도**: 모든 서비스가 재사용하는 공통 템플릿

**제공 템플릿**:
- `common.deployment`: Deployment 리소스
- `common.service`: Service 리소스
- `common.hpa`: HorizontalPodAutoscaler 리소스
- `common.serviceaccount`: ServiceAccount 리소스
- `common.labels`: 공통 레이블
- `common.selectorLabels`: Selector 레이블

### 2. gateway
**서비스**: API Gateway  
**기술**: Spring Cloud Gateway  
**포트**: 8080  
**ECR**: goorm-popcorn-api-gateway

**특징**:
- 모든 마이크로서비스 라우팅
- CORS 설정
- Ingress 지원

### 3. users
**서비스**: User Service  
**기술**: Spring Boot  
**포트**: 8080  
**ECR**: goorm-popcorn-user

**특징**:
- 사용자 인증 및 관리
- JWT 토큰 발급

### 4. stores
**서비스**: Store Service  
**기술**: Spring Boot  
**포트**: 8080  
**ECR**: goorm-popcorn-store

**특징**:
- 팝업 스토어 관리
- 스토어 정보 CRUD

### 5. order
**서비스**: Order Service (Command)  
**기술**: Spring Boot  
**포트**: 8080  
**ECR**: goorm-popcorn-order

**특징**:
- 주문 생성 및 처리
- CQRS 패턴의 Command 측
- Kafka 이벤트 발행

### 6. payment
**서비스**: Payment Service  
**기술**: Spring Boot  
**포트**: 8080  
**ECR**: goorm-popcorn-payment

**특징**:
- 결제 처리
- 외부 결제 게이트웨이 연동

### 7. orderQuery
**서비스**: Order Query Service  
**기술**: Spring Boot  
**포트**: 8080  
**ECR**: goorm-popcorn-order-query

**특징**:
- 주문 조회 최적화
- CQRS 패턴의 Query 측
- Kafka 이벤트 소비

### 8. checkIns
**서비스**: CheckIn Service  
**기술**: Spring Boot  
**포트**: 8080  
**ECR**: goorm-popcorn-checkin

**특징**:
- 체크인 처리
- QR 코드 생성 및 검증

## 차트 구조

각 서비스 차트는 동일한 구조를 따릅니다:

```
service-name/
├── Chart.yaml              # 차트 메타데이터
│   ├── name: service-name
│   ├── version: 1.0.0
│   └── dependencies:
│       └── common (library chart)
│
├── values.yaml             # 기본 설정
│   ├── replicaCount: 1
│   ├── image:
│   │   ├── repository: ECR 주소
│   │   └── tag: latest
│   ├── service:
│   │   └── port: 8080
│   ├── resources:
│   │   ├── requests
│   │   └── limits
│   └── healthCheck:
│       └── path: /actuator/health
│
└── templates/
    ├── deployment.yaml     # {{- include "common.deployment" . }}
    ├── service.yaml        # {{- include "common.service" . }}
    ├── serviceaccount.yaml # {{- include "common.serviceaccount" . }}
    ├── hpa.yaml           # {{- include "common.hpa" . }}
    └── configmap.yaml     # 서비스별 환경 변수
```

## 공통 설정

모든 서비스는 다음 공통 설정을 가집니다:

### 이미지
```yaml
image:
  repository: 375896310755.dkr.ecr.ap-northeast-2.amazonaws.com/goorm-popcorn-{service}
  pullPolicy: IfNotPresent
  tag: latest
```

### 서비스
```yaml
service:
  type: ClusterIP
  port: 8080
```

### 헬스체크
```yaml
healthCheck:
  enabled: true
  path: /actuator/health
  livenessPath: /actuator/health/liveness
  readinessPath: /actuator/health/readiness
  initialDelaySeconds: 60
  periodSeconds: 10
```

### 리소스
```yaml
resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

## 개별 차트 사용

### 단일 서비스 배포
```bash
helm upgrade --install users ./users \
  --namespace popcorn-dev \
  --create-namespace
```

### 설정 오버라이드
```bash
helm upgrade --install users ./users \
  --namespace popcorn-dev \
  --set image.tag=v1.2.3 \
  --set replicaCount=3
```

### Values 파일 사용
```bash
# custom-values.yaml 생성
cat > custom-values.yaml <<EOF
replicaCount: 3
image:
  tag: v1.2.3
resources:
  requests:
    cpu: 200m
    memory: 512Mi
EOF

helm upgrade --install users ./users \
  --namespace popcorn-dev \
  --values custom-values.yaml
```

## 새로운 서비스 추가

### 1. 기존 서비스 복사
```bash
cp -r users new-service
```

### 2. Chart.yaml 수정
```yaml
apiVersion: v2
name: new-service
description: New Service Description
type: application
version: 1.0.0
appVersion: "1.0.0"

dependencies:
- name: common
  version: "1.0.0"
  repository: "file://../common"
```

### 3. values.yaml 수정
```yaml
image:
  repository: 375896310755.dkr.ecr.ap-northeast-2.amazonaws.com/goorm-popcorn-new-service
  tag: latest

# 나머지 설정...
```

### 4. configmap.yaml 수정
서비스별 환경 변수 설정

### 5. Umbrella Chart에 추가
```yaml
# ../popcorn-umbrella/Chart.yaml
dependencies:
- name: new-service
  version: "1.0.0"
  repository: "file://../charts/new-service"
  condition: new-service.enabled
```

## 모범 사례

### 1. 버전 관리
- Chart 버전과 앱 버전 분리
- Semantic Versioning 사용

### 2. 리소스 설정
- 항상 requests와 limits 설정
- 실제 사용량 기반으로 조정

### 3. 헬스체크
- liveness와 readiness 분리
- 적절한 initialDelaySeconds 설정

### 4. ConfigMap 사용
- 환경 변수는 ConfigMap으로 관리
- 민감 정보는 Secret 사용

### 5. 레이블 및 어노테이션
- 공통 레이블 사용
- 메타데이터 일관성 유지

## 참고 자료

- [Common Chart 템플릿](common/templates/)
- [Umbrella Chart](../popcorn-umbrella/)
- [Helm Chart 개발 가이드](https://helm.sh/docs/chart_template_guide/)
