# 📚 Documentation Index

Popcorn Deploy 프로젝트의 모든 문서 목록과 위치입니다.

## 🗂️ 문서 구조

```
popcorn_deploy/
│
├── 📄 README.md                          ⭐ 프로젝트 개요 (시작점)
├── 📄 DIRECTORY_GUIDE.md                 📖 디렉터리 구조 상세 가이드
├── 📄 STRUCTURE.md                       📖 전체 파일 구조
├── 📄 DEPLOYMENT_GUIDE.md                🚀 배포 가이드
├── 📄 README_INDEX.md                    📚 이 문서 (문서 인덱스)
├── 📁 docs/                              # 운영/튜닝 문서 모음
│   ├── 📄 README.md                      📖 운영 문서 인덱스
│   ├── 📄 node-cost-review-prod-2026-02-18.md   📖 노드 비용 효율성 검토
│   └── 📄 resource-tuning-step1-prod-2026-02-18.md   📖 리소스 튜닝 실행 내역
│
├── 📁 helm/                              # 애플리케이션 Helm Charts
│   ├── 📄 README.md                      📖 Helm Chart 사용 가이드
│   └── 📁 charts/
│       └── 📄 README.md                  📖 개별 서비스 차트 가이드
│
├── 📁 infrastructure/                    # 인프라 컴포넌트
│   ├── 📄 README.md                      📖 인프라 설치 가이드
│   ├── 📄 VALUES_SUMMARY.md              📊 Values 설정 요약
│   ├── 📁 argocd/
│   │   └── 📄 README.md                  📖 ArgoCD 설치 가이드
│   ├── 📁 kafka/
│   │   └── 📄 README.md                  📖 Kafka 설치 가이드
│   └── 📁 lgtm/
│       └── 📄 README.md                  📖 LGTM Stack 설치 가이드
│
└── 📁 applications/                      # ArgoCD Application CRD
    └── 📄 README.md                      📖 Application 사용 가이드
```

## 📖 문서별 용도

### 🎯 시작 문서

#### [README.md](README.md) ⭐
**대상**: 모든 사용자  
**내용**: 프로젝트 개요, 빠른 시작, 서비스 목록  
**읽는 시점**: 프로젝트를 처음 접할 때

#### [DIRECTORY_GUIDE.md](DIRECTORY_GUIDE.md)
**대상**: 프로젝트 구조를 이해하고 싶은 사용자  
**내용**: 디렉터리별 상세 설명, 사용 시나리오, 헷갈리기 쉬운 부분  
**읽는 시점**: 프로젝트 구조를 파악하고 싶을 때

#### [STRUCTURE.md](STRUCTURE.md)
**대상**: 전체 파일 구조를 보고 싶은 사용자  
**내용**: 트리 형태의 전체 파일 구조  
**읽는 시점**: 특정 파일의 위치를 찾을 때

### 🚀 배포 관련

#### [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)
**대상**: 배포 담당자  
**내용**: 배포 방법, 환경별 설정, 트러블슈팅  
**읽는 시점**: 실제 배포를 수행할 때

#### [applications/README.md](applications/README.md)
**대상**: ArgoCD 사용자  
**내용**: ArgoCD Application CRD 사용법, 디렉터리 구분  
**읽는 시점**: ArgoCD로 애플리케이션을 배포할 때

### 🎨 Helm Chart 관련

#### [helm/README.md](helm/README.md)
**대상**: Helm Chart 사용자  
**내용**: Helm Chart 구조, 사용법, 커스터마이징  
**읽는 시점**: Helm Chart를 사용하거나 수정할 때

#### [helm/charts/README.md](helm/charts/README.md)
**대상**: 개별 서비스 차트 개발자  
**내용**: 서비스별 차트 구조, 새 서비스 추가 방법  
**읽는 시점**: 새로운 서비스를 추가하거나 차트를 수정할 때

### 🏗️ 인프라 관련

#### [infrastructure/README.md](infrastructure/README.md)
**대상**: 인프라 관리자  
**내용**: 인프라 컴포넌트 개요, 설치 순서  
**읽는 시점**: 인프라를 처음 구축할 때

#### [infrastructure/VALUES_SUMMARY.md](infrastructure/VALUES_SUMMARY.md)
**대상**: 인프라 설정 담당자  
**내용**: 모든 OSS의 values 설정 요약, 환경별 리소스  
**읽는 시점**: Values 파일을 수정하거나 리소스를 조정할 때

#### [infrastructure/argocd/README.md](infrastructure/argocd/README.md)
**대상**: ArgoCD 설치 담당자  
**내용**: ArgoCD 설치 방법, 접속 정보  
**읽는 시점**: ArgoCD를 설치할 때

#### [infrastructure/kafka/README.md](infrastructure/kafka/README.md)
**대상**: Kafka 관리자  
**내용**: Kafka 설치 방법, 토픽 관리  
**읽는 시점**: Kafka를 설치하거나 관리할 때

#### [infrastructure/lgtm/README.md](infrastructure/lgtm/README.md)
**대상**: 모니터링 담당자  
**내용**: LGTM Stack 설치 방법, 데이터 소스 구성  
**읽는 시점**: 모니터링 스택을 설치할 때

### 📈 운영/튜닝

#### [docs/node-cost-review-prod-2026-02-18.md](docs/node-cost-review-prod-2026-02-18.md)
**대상**: 운영자  
**내용**: 노드 사용량, 요청량, 비용 효율성 판단 및 1순위 실행 체크  
**읽는 시점**: 비용/성능 튜닝이 필요할 때

#### [docs/resource-tuning-step1-prod-2026-02-18.md](docs/resource-tuning-step1-prod-2026-02-18.md)
**대상**: 운영자  
**내용**: 1순위 리소스 튜닝 대상과 적용값, 검증 체크리스트 정리  
**읽는 시점**: prod 자원 조정이 필요할 때

#### [docs/README.md](docs/README.md)
**대상**: 문서 이용자  
**내용**: 운영 문서 카테고리 조회  
**읽는 시점**: 운영 문서를 빠르게 찾고 싶을 때

## 🎯 시나리오별 문서 가이드

### 시나리오 1: 처음 프로젝트를 접하는 경우
```
1. README.md                    # 프로젝트 개요 파악
2. DIRECTORY_GUIDE.md           # 구조 이해
3. DEPLOYMENT_GUIDE.md          # 배포 방법 학습
```

### 시나리오 2: 새로운 환경 구축
```
1. infrastructure/README.md     # 인프라 개요
2. infrastructure/argocd/README.md
3. infrastructure/kafka/README.md
4. infrastructure/lgtm/README.md
5. applications/README.md       # 애플리케이션 배포
```

### 시나리오 3: Helm Chart 수정
```
1. helm/README.md               # Helm Chart 구조 이해
2. helm/charts/README.md        # 개별 차트 구조
3. 해당 서비스 차트 수정
```

### 시나리오 4: 새로운 서비스 추가
```
1. helm/charts/README.md        # 새 서비스 추가 방법
2. helm/README.md               # Umbrella Chart 수정
3. DEPLOYMENT_GUIDE.md          # 배포 테스트
```

### 시나리오 5: 인프라 설정 변경
```
1. infrastructure/VALUES_SUMMARY.md  # 현재 설정 확인
2. 해당 OSS의 README.md             # 설정 방법 확인
3. values 파일 수정
```

### 시나리오 6: 트러블슈팅
```
1. DEPLOYMENT_GUIDE.md          # 일반적인 문제 해결
2. 해당 컴포넌트의 README.md    # 특정 컴포넌트 문제
3. infrastructure/VALUES_SUMMARY.md  # 설정 확인
```

### 시나리오 7: 운영 리소스 최적화
```
1. docs/node-cost-review-prod-2026-02-18.md  # 노드 사용량 분석
2. docs/resource-tuning-step1-prod-2026-02-18.md  # 1순위 튜닝 내역
3. docs/README.md  # 운영 문서 인덱스
```

## 📊 문서 완성도

| 디렉터리 | README 존재 | 내용 완성도 | 비고 |
|---------|------------|-----------|------|
| `/` | ✅ | ⭐⭐⭐⭐⭐ | 프로젝트 개요 |
| `/helm` | ✅ | ⭐⭐⭐⭐⭐ | Helm Chart 가이드 |
| `/helm/charts` | ✅ | ⭐⭐⭐⭐⭐ | 개별 차트 가이드 |
| `/infrastructure` | ✅ | ⭐⭐⭐⭐⭐ | 인프라 개요 |
| `/infrastructure/argocd` | ✅ | ⭐⭐⭐⭐⭐ | ArgoCD 설치 |
| `/infrastructure/kafka` | ✅ | ⭐⭐⭐⭐⭐ | Kafka 설치 |
| `/infrastructure/lgtm` | ✅ | ⭐⭐⭐⭐⭐ | LGTM 설치 |
| `/applications` | ✅ | ⭐⭐⭐⭐⭐ | Application CRD |

## 🔍 빠른 검색

### 설치 관련
- ArgoCD 설치: [infrastructure/argocd/README.md](infrastructure/argocd/README.md)
- Kafka 설치: [infrastructure/kafka/README.md](infrastructure/kafka/README.md)
- LGTM 설치: [infrastructure/lgtm/README.md](infrastructure/lgtm/README.md)
- 전체 설치: [infrastructure/README.md](infrastructure/README.md)

### 배포 관련
- Helm 배포: [helm/README.md](helm/README.md)
- ArgoCD 배포: [applications/README.md](applications/README.md)
- 배포 가이드: [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)

### 설정 관련
- Values 요약: [infrastructure/VALUES_SUMMARY.md](infrastructure/VALUES_SUMMARY.md)
- Helm Values: [helm/README.md](helm/README.md)
- 환경별 설정: [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)

### 운영/튜닝
- 노드 비용 검토: [docs/node-cost-review-prod-2026-02-18.md](docs/node-cost-review-prod-2026-02-18.md)
- 리소스 튜닝 실행: [docs/resource-tuning-step1-prod-2026-02-18.md](docs/resource-tuning-step1-prod-2026-02-18.md)
- 운영 문서 카테고리: [docs/README.md](docs/README.md)

### 구조 관련
- 디렉터리 가이드: [DIRECTORY_GUIDE.md](DIRECTORY_GUIDE.md)
- 파일 구조: [STRUCTURE.md](STRUCTURE.md)
- 프로젝트 개요: [README.md](README.md)

## 💡 문서 작성 원칙

1. **계층적 구조**: 상위 디렉터리에서 하위로 점진적 상세화
2. **명확한 목적**: 각 문서는 명확한 대상과 목적을 가짐
3. **상호 참조**: 관련 문서 간 링크 제공
4. **실용성**: 실제 사용 시나리오 기반 작성
5. **최신성**: 코드 변경 시 문서도 함께 업데이트

## 🤝 기여 가이드

새로운 문서를 추가하거나 수정할 때:
1. 이 인덱스 파일 업데이트
2. 관련 문서에 상호 참조 링크 추가
3. 시나리오별 가이드에 추가 (필요시)

## 📞 도움이 필요한 경우

1. 먼저 [README.md](README.md)를 읽어보세요
2. [DIRECTORY_GUIDE.md](DIRECTORY_GUIDE.md)에서 구조를 파악하세요
3. 특정 작업은 시나리오별 가이드를 따라하세요
4. 그래도 해결되지 않으면 팀에 문의하세요
