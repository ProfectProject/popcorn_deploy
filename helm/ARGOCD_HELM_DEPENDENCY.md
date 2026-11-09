# ArgoCD Helm 의존성 관리 가이드

> 원본: Notion "ArgoCD Helm 의존성 관리 가이드" (Infra > 작업목록, CI/CD·K8s). 작성: 인프라·배포 설계 담당, 2026-02-13.

## 개요
ArgoCD가 Umbrella 차트와 로컬(`file://`) 의존성을 어떻게 해석하는지, 그리고 `Chart.lock`과 `charts/*.tgz`를 Git에 커밋해야 하는 이유를 설명한다.

## 1. 의존성 구조
```text
helm/
├── charts/
│   ├── common/                 # 라이브러리 차트
│   └── gateway/                # 서비스 차트 (common 의존)
│       ├── Chart.yaml
│       ├── Chart.lock
│       └── charts/common-1.0.0.tgz
└── popcorn-umbrella/
    ├── Chart.yaml              # 모든 서비스 의존성 (condition: <svc>.enabled)
    ├── Chart.lock
    ├── charts/*.tgz            # gateway, users, stores, order, payment, order-query, checkins, common ...
    ├── values.yaml
    ├── values-dev.yaml
    └── values-prod.yaml
```

```yaml
# helm/charts/gateway/Chart.yaml
apiVersion: v2
name: gateway
version: 1.0.0
dependencies:
  - name: common
    version: 1.0.0
    repository: file://../common
```

```yaml
# helm/popcorn-umbrella/Chart.yaml
apiVersion: v2
name: popcorn-umbrella
version: 1.0.0
dependencies:
  - name: gateway
    version: 1.0.0
    repository: file://../charts/gateway
    condition: gateway.enabled
  # ... 나머지 서비스
```

## 2. ArgoCD 처리 순서
1. Git 저장소 clone
2. `Chart.lock` 확인
   - 있으면: `charts/`의 `.tgz`를 그대로 사용(다운로드 생략, 빠르고 안정적)
   - 없으면: `helm dependency build` 시도 → `file://` 경로 해석 실패 가능성 높음
3. `helm template` 렌더링 (`values.yaml` + 환경별 values 병합)
4. 렌더된 매니페스트 적용

## 3. Chart.lock / charts/ 의 역할
- **Chart.lock**: 의존성 버전 고정(재현 가능한 빌드), digest로 무결성 검증, 다운로드 생략
- **charts/*.tgz**: 패키징된 하위 차트. 네트워크 없이 로컬 해석, `file://` 문제 회피, 에어갭 환경 지원, 버전 일관성

## 4. Application 설정 비교
| 항목 | dev (`popcorn-dev`) | prod (`popcorn-prod`) |
| --- | --- | --- |
| targetRevision | main | HEAD |
| valueFiles | values.yaml, values-dev.yaml | values.yaml, values-prod.yaml |
| automated.prune | true | false |
| automated.selfHeal | true | false |
| syncOptions | CreateNamespace, PrunePropagationPolicy=foreground, PruneLast | CreateNamespace, PrunePropagationPolicy=foreground |
| retry | limit 5, backoff 5s ×2, max 3m | 동일 |

## 5. 의존성 업데이트 워크플로우
```bash
# 1) 서비스 차트 수정 후 (필요 시) common 의존성 갱신
cd helm/charts/gateway && helm dependency update
# 2) Umbrella 의존성 갱신 → charts/*.tgz, Chart.lock 재생성
cd ../../popcorn-umbrella && helm dependency update
# 3) 로컬 검증
helm lint .
helm template test . -f values.yaml -f values-dev.yaml
# 4) 커밋 (Chart.lock, charts/ 포함)
git add helm/charts/gateway helm/popcorn-umbrella/Chart.lock helm/popcorn-umbrella/charts
git commit -m "feat: update gateway deployment configuration"
git push origin main
# 5) dev는 자동 sync(폴링 약 3분), prod는 수동 sync
argocd app get popcorn-dev
```

## 6. 문제 해결
| 증상 | 원인 | 해결 |
| --- | --- | --- |
| `failed to download "file://../charts/gateway"` | `Chart.lock`/`charts/`가 Git에 없음 | 두 경로를 커밋 |
| kubeVersion 비호환 / 버전 불일치 | lock과 tgz 불일치 | `rm -rf charts/ Chart.lock && helm dependency update` 후 커밋 |
| `ComparisonError ... error getting git files` | 저장소 권한, 브랜치·경로 오류 | Application `repoURL`/`targetRevision`/`path` 확인 |
| `nil pointer evaluating .Values.image.tag` | values 필수 값 누락 | `helm template --debug`로 확인 후 값 추가 |
| `0/3 nodes are available: Too many pods, Insufficient memory` | 노드 리소스 부족 | requests 축소 또는 `<svc>.enabled: false` |

## 7. 체크리스트
**새 서비스 추가**: 서비스 차트 생성 → common 의존성 추가 → `helm dependency update` → Umbrella `Chart.yaml`에 추가 → Umbrella `helm dependency update` → values 추가 → 렌더 테스트 → 커밋 → ArgoCD sync 확인

**차트 수정**: 수정 → 필요 시 의존성 갱신 → 렌더 테스트 → 커밋 → dev 자동 sync 검증 → prod 수동 sync
