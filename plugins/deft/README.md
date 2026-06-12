# deft

bluehansl 개인 워크플로 도구 모음. Claude Code / Codex 양쪽에서 동일하게 **`deft:<skill>`** 로 호출한다.

## 스킬

| FQN | 동작 |
|---|---|
| `deft:multi-check` | Codex + Claude + Gemini 다중 AI **1회성** 교차검증/비교 (fan-out) |
| `deft:multi-round` | **여러 AI가 N라운드 양방향으로 토론·합의 도달** 하는 멀티턴 회의. 메시지 버스(브로드캐스트 보드 + 노크) 기반 — pane 시각화 + 자동 깨우기. [상세 가이드](skills/multi-round/GUIDE.md) |
| `deft:agent-teams` | **Claude 내장 팀 기능으로 다중 에이전트 팀(Lead+backend/frontend/qa 등) 운영**. 분담 구현·검증·리뷰. work-id 기반 영속 작업노트. [상세 가이드](skills/agent-teams/GUIDE.md) |
| `deft:session-relocate` | Claude Code 세션 로그를 다른 프로젝트 디렉토리로 이동(`/resume` 대상화) |
| `deft:set-statusline` | 터미널 상태줄(statusline) 설정 |
| `deft:restore-statusline` | 상태줄 복원 |

### 3-도구 비교 — 언제 어느 걸 쓸까

| 도구 | 통신 | AI 조합 | 의존성 | 한 줄 |
|---|---|---|---|---|
| `multi-check` | **1회성** fan-out | Codex/Claude/Gemini 동시 | CLI 직접 (MCP 무관) | "한 번 물어보고 답만 비교" |
| `multi-round` | **지속 N라운드 양방향** | Claude + Claudex mix | **메시지 버스 + cmux pane** | "의견 갈리는 문제 토론해서 합의" |
| `agent-teams` | 지속 multi-turn 협업 | Claude끼리만 | **Claude 내장 팀 기능** | "코드 분담 구현·검증·리뷰·작업노트 관리" |

→ **답이 하나면** `multi-check`, **답을 좁혀가야 하면** `multi-round`, **코드를 만져야 하면** `agent-teams`.

### 강한 트리거 — 이 문구가 들어가면 해당 skill 이 발동

| 입력에 포함된 문구 | 발동 skill | 비고 |
|---|---|---|
| **"회의"** / **"미팅"** | `multi-round` | "작업" 단독은 라우팅 안 함 |
| **"코딩 작업"** | `agent-teams` | "작업" 단독은 일상어라 제외 — "코딩 작업" 조합일 때만 |
| **"비교"** / **"교차 검증"** / **"멀티 체크"** | `multi-check` | |

두 트리거가 함께 나오면 (예: "코딩 작업 시작 전에 회의부터") 먼저 요구되는 쪽이 발동하고, 이어지는 단계는 같은 work-id 로 연계된다.

### 사용 예제 문구

**multi-check** — 1회 물어보고 답 비교:
```
이 설계 멀티 체크해줘
다른 AI한테도 물어봐서 교차 검증해줘
GPT랑 Claude 답 비교해줘
```

**multi-round** — N라운드 토론·합의:
```
결제 트랜잭션 격리 수준 어떻게 할지 회의 열어줘
REST vs GraphQL 이 주제로 미팅 진행해줘
IT-14610 인덱스 전략, 멀티 라운드로 합의될 때까지 토론시켜줘
(독립 토론) 이 주제 독립 토론으로 왔다갔다 토론해줘
```

**agent-teams** — 팀 분담 구현·검증:
```
IT-14610 코딩 작업 시작해줘
이 기능 코딩 작업해줘 — BE/FE 나눠서
에이전트 팀 만들어서 QA까지 붙여줘
어제 하던 IT-14610 코딩 작업 이어서 해줘   ← 같은 work-id 면 작업노트 자동 연속
```

**work-id 연계** — 두 skill 을 잇는 영속 키:
```
(최초 1회) work-id 규약 메뉴에서 선택 — 티켓번호/브랜치명/날짜-작업명/자유명/직접입력
(규약 변경) work-id 규약 바꿔줘
(연계 흐름) IT-14610 회의 열어줘 → 합의 → IT-14610 코딩 작업 시작해줘
            → 팀이 회의 합의 결과를 작업노트에 자동 반영
```

## 설치 (Claude Code)

```
/plugin marketplace add bluehansl/deft
/plugin install deft@bluehansl
```

## 사용자 데이터 경로 컨벤션

deft 플러그인의 모든 스킬은 사용자 데이터(세션·메타·hooks 등)를 다음 경로 하위에 **스킬별로 구분하여** 저장한다.

- **Claude 측**: `~/.claude/plugin-data/deft/<skill>/`
- **Codex 측**: `~/.codex/plugin-data/deft/<skill>/`

플러그인 cache 영역(`~/.claude/plugins/cache/...`, `~/.codex/plugins/cache/...`)에는 사용자 데이터를 두지 않는다.

## 마이그레이션 (개별 플러그인 → deft 통합)

기존 개별 플러그인 `multi-check` / `session-relocate` / `set-statusline` 은 단일 브랜드 `deft` 로 통합되었다. 네임스페이스 매핑:

| 구 (v1) | 신 (deft) |
|---|---|
| `multi-check:multi-check` | `deft:multi-check` |
| `session-relocate:session-relocate` | `deft:session-relocate` |
| `set-statusline:set-statusline` | `deft:set-statusline` |
| `set-statusline:restore-statusline` | `deft:restore-statusline` |

> 스킬명은 그대로 유지되고 플러그인 네임스페이스만 `deft` 로 통일되었다. 기존 사용자는 구 플러그인 3개를 제거한 뒤 `deft` 를 새로 설치하면 된다. (네임스페이스 변경 = breaking → `claude-2.0.0`)
## 워커 권한 모드 고지 (multi-round)

multi-round 회의 워커는 **승인 프롬프트 없이** 동작하도록 다음 모드로 spawn 된다 (해당 워커 인스턴스 한정 — 사용자 환경 설정 무변경):

- **claudex/codex 워커**: `--dangerously-bypass-approvals-and-sandbox`
- **claude 워커**: `--dangerously-skip-permissions`

두 모드 모두 해당 워커의 도구 호출 승인·sandbox 를 해제한다. **회의(발언 전용) 워커 용도에 한정**해 사용하며, 민감한 작업 디렉토리에서 회의를 열 때 원치 않으면 SKILL 의 spawn 명령에서 해당 플래그를 제거하고 도구별 "Allow for this session" 승인(회의당 2회)으로 진행할 수 있다.
## 세션 바이너리 keepalive 고지 (multi-check / agent-teams)

teammate spawn 은 Lead 세션과 같은 버전의 Claude Code 바이너리를 실행한다. 세션이 오래 떠 있는 동안 자동 업데이트가 그 버전을 삭제하면 spawn 이 `No such file or directory` 로 실패하므로, 두 스킬은 실행 시 `claude-bin-keepalive` 헬퍼로 **현재 버전 바이너리를 hardlink 보존**하고 삭제 시 복원한다.

- 보존 위치: `~/.claude/plugin-data/deft/bin-keepalive/` (실행 중 세션 버전 + 최신 2개 유지 — 버전당 약 220MB 점유 지속)
- 이미 바이너리가 삭제된 오래된 세션은 복원 불가 — 헬퍼가 경고를 출력하며, 해당 세션을 재시작(`/resume`)하면 현재 버전으로 재개되어 해소된다 (work-id 작업노트로 연속성 유지)
