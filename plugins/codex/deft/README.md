# deft (Codex)

bluehansl 개인 워크플로 도구 모음의 Codex 포팅본. Codex에서 **`deft:<skill>`** 로 호출한다.

## 스킬

| FQN | 동작 |
|---|---|
| `deft:multi-check` | Codex + Claude + Gemini 다중 AI **1회성** 교차검증/비교 (fan-out) |
| `deft:multi-round` | **여러 AI가 N라운드 양방향으로 토론·합의 도달** 하는 멀티턴 회의. 메시지 버스(브로드캐스트 보드 + 노크) 기반 — pane 시각화 + 자동 깨우기. [상세 가이드](skills/multi-round/GUIDE.md) |
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

## 설치 (Codex)

```
codex plugin marketplace add bluehansl/deft
codex plugin add deft@bluehansl-codex
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
