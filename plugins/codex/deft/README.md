# deft (Codex)

bluehansl 개인 워크플로 도구 모음의 Codex 포팅본. Codex에서 **`deft:<skill>`** 로 호출한다.

## Quick Start — 첫 실행 검증

**Prerequisites**

| 항목 | 구분 |
|---|---|
| Codex CLI (플러그인 지원 버전) | 필수 |
| cmux | 선택 — `multi-round`/`multi-check` 워커 pane 시각화 |
| claude·gemini CLI | 선택 — `multi-check` 3-AI 비교용 |

**설치·확인**

```
codex plugin marketplace add bluehansl/deft
codex plugin add deft@bluehansl-codex
```

`codex plugin list` 에 `deft` 가 보이면 설치 완료.

**첫 실행 예제 — `deft:set-statusline`** (저비용 · 결과 즉시 확인 · 원복 내장)

Codex TUI 에서 `deft:set-statusline` (또는 "statusline 적용") 입력.

- **성공 기준**: 점검·컨펌 후 `~/.codex/config.toml` 의 `[tui].status_line` 이 설정되고 TUI 하단 status line 에 모델·context·현재 디렉토리가 표시된다.
- **실패 시**: `deft:restore-statusline` 으로 설치 직전 상태 원복. 그 외 증상은 아래 워커 권한 모드 고지와 [CHANGELOG (단일 소스)](../../deft/CHANGELOG.md) 의 최근 Fixed 항목을 확인.

**버전·변경 이력** — 버전 숫자는 본 문서에 고정 기재하지 않는다.

- 현재 설치 버전: [.codex-plugin/plugin.json](.codex-plugin/plugin.json) 의 `version` · 변경 이력: [CHANGELOG (단일 소스)](../../deft/CHANGELOG.md) — Claude·Codex 공용, `codex-X.Y.Z` 엔트리 참조
- 버전 의존 동작은 도입 버전을 병기한다 — 예: `multi-round` 기본 워커 3명은 `codex-1.12.0+`.

## 스킬

| FQN | 동작 |
|---|---|
| `deft:multi-check` | Codex + Claude + Gemini 다중 AI **1회성** 교차검증/비교 (fan-out) |
| `deft:multi-round` | **여러 AI가 두 통신 모드로 협업하는 멀티턴**. ① **회의 모드** — N라운드 양방향 토론으로 합의 도달(board 브로드캐스트 + 노크). ② **작업 모드** — board 없는 NTP mesh 로 일 분담. 기본 워커 3명·주제 맞춤 페르소나(`codex-1.12.0+`). 메시지 버스 기반 — pane 시각화 + 자동 깨우기. [상세 가이드](skills/multi-round/GUIDE.md) |
| `deft:session-relocate` | 세션 로그를 다른 프로젝트 디렉토리로 이동(`/resume` 대상화) |
| `deft:set-statusline` | Codex TUI status line 설정 (`~/.codex/config.toml`) |
| `deft:restore-statusline` | status line 복원 |

### 강한 트리거 — 이 문구가 들어가면 해당 skill 이 발동

| 입력에 포함된 문구 | 발동 | 비고 |
|---|---|---|
| **"회의"** / **"미팅"** | `multi-round` | |
| **"코딩 작업"** | Codex 자체 task 실행 | agent-teams 는 Claude 전용 — Codex 에선 자체 task 로 처리 |
| **"비교"** / **"교차 검증"** / **"멀티 체크"** | `multi-check` | |

### 사용 예제 문구

**multi-check** — 1회 물어보고 답 비교:
```
이 설계 멀티 체크해줘
다른 AI한테도 물어봐서 교차 검증해줘
```

**multi-round** — N라운드 토론·합의:
```
결제 트랜잭션 격리 수준 어떻게 할지 회의 열어줘
REST vs GraphQL 이 주제로 미팅 진행해줘
(독립 토론) 이 주제 독립 토론으로 진행해줘
```

**work-id 연계** — 회의를 작업에 묶는 영속 키:
```
(최초 1회) work-id 규약 메뉴에서 선택 — Claude 측에서 이미 정했으면 그 규약 재사용
(연계 흐름) IT-14610 회의 열어줘 → 합의 → Claude 측 agent-teams 가 같은 work-id 로
            회의 결과를 작업노트에 반영
```

## 사용자 데이터 경로 컨벤션

deft 플러그인의 모든 스킬은 사용자 데이터(세션·메타·hooks 등)를 다음 경로 하위에 **스킬별로 구분하여** 저장한다.

- **Codex 측**: `~/.codex/plugin-data/deft/<skill>/`
- **Claude 측**: `~/.claude/plugin-data/deft/<skill>/`

플러그인 cache 영역(`~/.codex/plugins/cache/...`, `~/.claude/plugins/cache/...`)에는 사용자 데이터를 두지 않는다.

## 마이그레이션 (개별 플러그인 → deft 통합)

기존 `multi-check` / `session-relocate` / `set-statusline` 3개 Codex 플러그인이 단일 `deft` 로 통합되었다. 스킬명은 유지되고 네임스페이스만 `deft` 로 통일. 네임스페이스 변경 = breaking → `codex-1.0.0`. 기존 사용자는 구 3개 제거 후 `deft` 재설치.

## 워커 권한 모드 고지 (multi-round)

multi-round 회의 워커는 **승인 프롬프트 없이** 동작하도록 다음 모드로 spawn 된다 (해당 워커 인스턴스 한정 — 사용자 환경 설정 무변경):

- **claudex/codex 워커**: `--dangerously-bypass-approvals-and-sandbox`
- **claude 워커**: `--dangerously-skip-permissions`

두 모드 모두 해당 워커의 도구 호출 승인·sandbox 를 해제한다. **회의(발언 전용) 워커 용도에 한정**해 사용하며, 민감한 작업 디렉토리에서 회의를 열 때 원치 않으면 SKILL 의 spawn 명령에서 해당 플래그를 제거하고 도구별 "Allow for this session" 승인(회의당 2회)으로 진행할 수 있다.
