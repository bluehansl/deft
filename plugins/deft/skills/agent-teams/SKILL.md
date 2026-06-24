---
name: agent-teams
description: 'Claude Code 내장 팀 기능으로 다중 Claude 에이전트 팀을 운영하는 skill. Lead가 역할별 팀원(backendDev/frontendDev/qa 등)을 spawn해 분석→구현→검증을 분담하고, 단계 게이트·역할 페르소나·work-id 기반 영속 작업노트로 일관성과 연속성을 보장한다. 강한 트리거 — "코딩 작업" 문구가 포함된 요청은 본 skill 로 발동 (예: "IT-14610 코딩 작업 시작", "이거 코딩 작업해줘", "코딩 작업 이어서"). 그 외 트리거 — "에이전트 팀", "팀으로 작업", "팀으로 구현", "역할 나눠서 해", "BE/FE 나눠서 해", "QA까지 붙여", "spawn a team". 단 "회의"/"미팅" 단어가 포함된 요청은 multi-round, 1발 비교는 multi-check 를 쓰세요.'
---

# Agent Teams Skill

Claude Code **내장 팀 기능**(`Agent` + `SendMessage` + `Task*` — 팀은 첫 `Agent` spawn 시 **암묵적으로 자동 생성**)으로 다중 Claude 에이전트 팀을 구성·운영하는 skill. Lead(팀장 겸 기획)가 역할별 팀원(backendDev/frontendDev/qa 등)을 spawn해 분석→구현→검증을 분담하고, 단계 게이트·페르소나·영속 작업노트로 일관성과 연속성을 보장한다.

> **팀 모델(현행 Claude Code)**: 과거의 명시적 `TeamCreate`/`TeamDelete` 도구는 폐지됐다. 현재는 첫 `Agent` spawn 시 `~/.claude/teams/session-<id>/` 팀이 **자동 생성**되고 **세션 종료 시 자동 삭제**된다(공식 문서 동작). `Agent` 의 `team_name` 인자는 deprecated(무시됨). 팀원 통신·정리 메커니즘(`SendMessage`·shutdown)은 그대로다.

> **팀원 모델**: 모두 **Claude Opus (`opus`)** — 동질 시각, 컨벤션 강제 일관. Agent tool 호출 시 alias `opus` (§4-3).

> 본 skill은 **자기완결적**이다. 운영에 필요한 모든 규약(팀 구성·페르소나·작업 흐름·통신·파일 구조·회의 모드)이 이 패키지(SKILL.md + `agents/*.md` + `GUIDE.md`) 안에 들어있다. 외부 `AGENTS.md` 참조 없이 이 skill만으로 팀을 운영할 수 있다. 단, **프로젝트별 코드 컨벤션**(예: 특정 프레임워크 패턴)은 각 프로젝트의 `AGENTS.md`/`CLAUDE.md`가 소유하며, 페르소나는 "본인 cwd 프로젝트의 컨벤션을 준수"로 일반 참조한다(§7-3).

---

## 0. 시작 전 환경 검증 (Phase 0)

본 skill은 Claude Code의 **실험적 Agent Teams 기능**을 사용한다. 팀 spawn 전 다음을 확인한다.

### 0-1. 활성 조건

- 환경 변수 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` (실험 기능 — 기본 비활성)
- Claude Code **v2.1.32 이상** (현행 빌드는 **암묵적 팀 모델** — `TeamCreate` 도구 없이 첫 `Agent` spawn 으로 팀 자동 생성)
- teammate가 활성화된 하니스에서 실행 (`cmux claude-teams`)

```bash
# Phase 0 환경 검증
[ "$CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" = "1" ] || echo "WARN: Agent Teams 실험 기능 미활성 — 활성화 또는 단일 Claude 모드로 진행"
# Claude Code 버전 v2.1.32+ 인지 사용자에게 확인
# cmux claude-teams 환경에서 실행 중인지 확인

# deft 헬퍼 동기 (갱신형 — 구버전 잔재 자동 최신화). 종전의 개별 `if ! command -v $H`(없으면 설치) 블록은
#   ~/.local/bin 구버전 잔재를 plugin update 후에도 갱신 못 하던 결함이 있어 deft-bin-sync 로 일원화(claude-2.34.0~).
#   deft-bin-sync 는 캐시 sort -V tail 최신본과 cmp 해 다르면 cp → cmux(shim)·cmux-rebalancing·rebalance-watch·
#   rebalance-guard·claude-bin-keepalive·deft-model·deft-log·deft-review 등 전체를 항상 최신화. 부트스트랩은 단순 cp.
DEFT_SYNC_SRC=$(ls -1 ~/.claude/plugins/cache/bluehansl/deft/*/bin/deft-bin-sync 2>/dev/null | sort -V | tail -1)
[ -z "$DEFT_SYNC_SRC" ] && DEFT_SYNC_SRC=$(ls -1 ~/.codex/plugins/cache/bluehansl-codex/deft/*/bin/deft-bin-sync 2>/dev/null | sort -V | tail -1)
if [ -n "$DEFT_SYNC_SRC" ]; then
  mkdir -p ~/.local/bin && cp "$DEFT_SYNC_SRC" ~/.local/bin/deft-bin-sync && chmod +x ~/.local/bin/deft-bin-sync
  deft-bin-sync
  command -v cmux >/dev/null 2>&1 || deft-bin-sync cmux 2>/dev/null   # cmux gap-fill 보강
else
  echo "WARN: deft-bin-sync 미발견(구버전 캐시) — 헬퍼 자동 동기 비활성"
fi

if command -v claude-bin-keepalive >/dev/null 2>&1; then
  claude-bin-keepalive || echo "STOP_TEAM_SPAWN: 세션 바이너리 복원 불가(KEEPALIVE_HARDFAIL) — 이 세션의 teammate spawn 은 반드시 실패한다."
fi
```

**preflight 게이트 (필수)**: 위 출력에 `STOP_TEAM_SPAWN`(또는 `KEEPALIVE_HARDFAIL`)이 보이면, 팀 spawn(`Agent`) 을 **실행하지 말 것**. 대신 사용자에게 "이 세션은 자동 업데이트로 Claude Code 바이너리가 삭제됐습니다. `cmux claude-teams`(또는 `/resume`)로 세션을 재시작한 뒤 다시 시도하세요"를 안내하고 중단한다. (work-id 영속 설계로 연속성은 유지됨.)

> **`cmux-rebalancing`**: Lead 와 팀원 컬럼 비율을 정책대로 재조정하는 헬퍼. **전체 팀원 spawn 후 1회** 호출 (§2-3).

### 0-2. cmux 외부 실행 시 (fallback)

팀원 시각화(pane 자동 분할, §2-2)는 `cmux claude-teams` 환경에서만 동작한다. **cmux 외부**에서 실행 중이면:

- **기본: 단일 Claude 모드로 degrade** — 팀 spawn을 skip하고 Lead 단독으로 §4 단계 게이트를 진행한다. 의견 토론·합의가 목적이면 `deft:multi-round`를 권유한다.
- **권장 안내: `cmux claude-teams` 재시작** — 팀 운영·시각화가 필요하면 사용자에게 재시작을 권한다.
- 사용자가 "시각화 없이 그냥 팀으로" 명시 요청한 경우에만, pane 분할 없이 `Agent` spawn을 진행하되 **"시각화 비활성" 상태임을 사용자에게 명시 보고**한다.

### 0-3. 운영 제약 (limitation)

| 제약 | 의미 | 대응 |
|---|---|---|
| **한 lead = 한 team** | 한 Lead가 동시에 여러 팀을 운영할 수 없다 | 작업을 한 팀 단위로 정리 |
| **nested team 불가** | 팀원이 그 안에서 다시 **팀/팀원**을 spawn할 수 없다 | 팀 구성은 Lead가 한 번에 결정. **단 `/workflows`(결정론 fan-out)는 팀원도 사용 가능** — 워크플로 서브에이전트는 '팀원'이 아니라 격리 서브에이전트라 중첩-팀 금지에 안 걸림(실측 확인, §7-5) |
| **in-process teammate resume 불가** | 세션 재시작 시 팀원이 자동 복구되지 않음 → 새 세션 팀(`session-<id>`)으로 다시 spawn 필요 (공식 문서 명시 한계) | **work-id 영속 설계(§3)가 보완** — 같은 work-id로 `work.md`·`<role>.md` 연속 |
| **task status lag** | `TaskList` 갱신이 지연될 수 있음 | 팀원 idle/완료를 성급히 단정하지 않음 |
| **팀은 세션별 자동 생성·삭제** | `~/.claude/teams/session-<id>/` 는 **세션마다 자동 생성, 세션 종료 시 자동 삭제**(공식 동작). 세션별로 분리되어 과거의 team-name 충돌 문제는 자연 회피됨 | 정리는 **팀원 shutdown(SendMessage shutdown_request) → Lead 정리 요청** 순. 다른 세션(`session-*`)의 팀원에게 shutdown 보내지 않도록 본 세션 소속(`--parent-session-id`)인지 확인. "이름이 같다 ≠ 내 것" |

---

## 1. 3-도구 멘탈 모델 (어떤 도구를 쓸지)

| 도구 | 통신 방식 | AI 조합 | 언제 쓰는가 |
|---|---|---|---|
| `deft:multi-check` | **1회성** fan-out (응답 비교) | Codex/Claude/Gemini 동시 | "한 번 물어보고 답만 비교" |
| `deft:multi-round` | **지속 통신** (N라운드 양방향 토론) | Claude + Claudex/Codex mix | "의견 갈려서 여러 번 주고받으며 좁히고 싶다 / 토론·합의" |
| **`deft:agent-teams`** (본 skill) | **지속 협업** (multi-turn 분담·구현·리뷰) | **Claude끼리** (내장 팀 기능) | **"실제 코드 분담·구현·검증·리뷰 루프·작업노트 관리"** |

판단 키워드: **답이 하나면 multi-check, 답을 좁혀가야 하면 multi-round, 코드를 만져야 하면 agent-teams.**

**강한 트리거 라우팅** (문구 포함 시 우선 적용):

| 사용자 입력에 포함된 문구 | 발동 skill |
|---|---|
| **"코딩 작업"** | **`agent-teams` (본 skill)** — 예: "IT-14610 코딩 작업 시작", "이거 코딩 작업해줘" |
| **"회의"** / **"미팅"** | `multi-round` — 예: "회의 열어줘", "이 주제로 미팅" |
| "비교" / "교차 검증" | `multi-check` |

> "작업" 단독은 일상어라 강한 트리거로 쓰지 않는다 (예: "파일 정리 작업"은 단순 요청). **"코딩 작업"** 조합일 때만 본 skill 강제 발동. 코딩 작업과 회의가 **함께** 나오면 (예: "코딩 작업 시작 전에 회의부터") 먼저 요구되는 쪽을 발동하고, 이어지는 단계는 같은 work-id 로 연계한다.

> **`multi-round collaborate` ↔ `agent-teams` 경계** — multi-round의 `collaborate` 모드는 **분담 검토·분담 설계·독립 의견 작성 후 상호 리뷰**까지다(실제 파일 수정·테스트는 하지 않는다). 실제 **파일 수정·테스트·작업노트·코드 분담 구현**이 필요하면 agent-teams다. → collaborate 진행 중 실제 코드 작업이 필요해지면 **agent-teams로 승격**한다.

### 1-1. 도구 선택 매트릭스 (팀 vs 단독)

| 상황 | 권장 | 이유 |
|---|---|---|
| 단순 작업 (파일 1~2개, 단일 모듈) | **단일 Claude** (팀 없이 §4 단계 게이트만) | 팀 spawn 오버헤드 > 이득 |
| 모듈 다수·병렬 가능·컨벤션 동질성 중요 | **Agent Teams** (본 skill, 모두 Claude) | 동질 시각, 자동 메시지 전달 |
| 다른 AI 시각·비편향 상호 리뷰가 핵심 | **multi-round** (Claude + Claudex mix) | AI mix 토론 |
| 큰 작업: 분석은 단독 → 구현은 팀 → 토론은 multi-round | **혼합 운영** (§7-4) | 단계별 적합 도구 |

---

## 2. 핵심 동작 원리 (내장 도구 기반)

본 skill은 Claude Code 내장 도구 3종 + 암묵적 팀으로 동작한다.

| 도구 | 역할 |
|---|---|
| **(암묵적 팀)** | 첫 `Agent` spawn 시 `~/.claude/teams/session-<id>/` + `~/.claude/tasks/session-<id>/` **자동 생성**. 세션 종료 시 자동 삭제. 별도 생성 호출 불필요 |
| `Agent` (`name`, `model:"opus"`) | 팀원 spawn (역할별 페르소나 주입). **`team_name` 인자는 deprecated(무시됨) — 넣지 않는다** |
| `SendMessage` | 팀원↔Lead, 팀원↔팀원 직접 통신 + 종료(shutdown_request) |
| `Task*` (TaskCreate/Update/List) | 작업 분배·진행 추적 (공유 task list) |

### 2-1. 자동 메시지 전달 — 폴링 불필요

내장 팀의 `SendMessage`는 **수신자에게 자동으로 전달**된다(상대의 다음 turn에 사용자 메시지처럼 도착). 팀원이 idle이어도 `SendMessage`를 보내면 깨어나 처리한다. 별도의 폴링 루프나 inbox 수동 확인이 필요 없다. **"팀원이 idle"은 정상 상태이며 에러가 아니다** — 성급히 재촉하지 않는다.

### 2-2. cmux pane 분할 — 자동

사용자는 Claude Code를 `cmux claude-teams`로 실행한다. 이 환경에서 `Agent` spawn은 **cmux pane 분할까지 자동 처리**된다. Lead가 별도 분할 명령을 호출할 필요 없다. (cmux 외부 실행 시는 §0-2 fallback)

### 2-3. pane 비율 재조정 — spawn 과 함께 rebalance 워처 발사

`Agent` 툴은 spawn 1회가 **pane 생성 + 팀원 기동을 원자적으로** 수행하고, cmux claude-teams 가 pane 을 **자동 배치**한다(스킬이 분할 제어 불가 — multi-round 처럼 `cmux new-split` 을 직접 호출하지 못함). 그리고 **각 spawn 마다 Lead pane 이 다시 찌부러진다**(cmux 가 Lead 기준 재분할 — 실측). rebalancing 은 pane geometry 만 정렬하는 **독립·비동기** 작업이라 팀원 작업과 무관하게 호출할 수 있다 → **spawn 묶음과 같은 메시지에서 `cmux-rebalance-watch` 를 백그라운드로 띄워, panes 가 다 생겨 settle 되는 즉시 1회 rebalance** 시킨다.

1. spawn **직전(=panes 생성 전)** 에 캡처: `LEAD_REF=$(cmux identify | jq -r .caller.pane_ref)` (focus 복원용) + `BASE=$(tmux list-panes -a -F '#{pane_id}' | wc -l | tr -d ' ')` (baseline) + 이번에 spawn 할 팀원 수 `N` → `EXPECTED=$((BASE+N))` (목표 최종 pane 수) + `FAST=$([ "$BASE" -eq 1 ] && echo 1 || echo 0)` (**clean Lead 워크스페이스 판정** — BASE==1 이면 빠른 경로).
2. **팀원 전부 + rebalance 워처를 한 메시지에 함께 발사** — 팀원은 `Agent`(병렬), 워처는 `cmux-rebalance-watch "$LEAD_REF" "$BASE" "$EXPECTED" "$FAST"` 를 **`run_in_background: true` Bash** 로. 워처가 panes 가 **EXPECTED 에 도달하는 즉시**(=모든 팀원 pane 등장 — panes 는 하나씩 순차 등장하므로 EXPECTED 도달이 가장 정확한 신호) rebalance(컬럼 60:40 + row 균등) + Lead focus 복원을 1회 실행한다. **`FAST=1`(clean Lead)이면 `cmux-rebalancing --fast`**(단발 push, ~2s), 아니면 robust `cmux-rebalancing`(~4s).

```text
# spawn 직전(panes 생성 전)에 캡처:
LEAD_REF=$(cmux identify | jq -r .caller.pane_ref)
BASE=$(tmux list-panes -a -F '#{pane_id}' | wc -l | tr -d ' ')
EXPECTED=$((BASE + N))                       # N = 이번에 spawn 하는 팀원 수
FAST=$([ "$BASE" -eq 1 ] && echo 1 || echo 0)   # BASE==1(Lead 단독) → clean-grid 빠른 경로
# spawn 직후 진행 로그 (관찰성 §2-4 — LOG_DIR 은 work-id 디렉토리):
deft-log "$LOG_DIR" STEP "팀원 $N명 spawn — rebalance 워처 발사 (EXPECTED=$EXPECTED, FAST=$FAST)"
# spawn 메시지에 팀원 Agent 들과 함께 포함 (run_in_background)
Bash(run_in_background: true): cmux-rebalance-watch "$LEAD_REF" "$BASE" "$EXPECTED" "$FAST"
# (권장) rebalance-guard 도 함께 발사 — watch 는 settle 즉시 1회지만, claude Agent 워커는 spawn 마다
#   ~1.4초 후 cmux 재계산이 Lead 를 다시 깎는다(실측 60%→26%). guard 가 0.1초 폴링으로 매 틀어짐을
#   ~1초 내 교정하고 마지막 spawn 후 5초 무틀어짐이면 자동 종료 → watch+guard 병행이 가장 안정적.
LEAD_WS=$(cmux identify | jq -r '.caller.workspace_ref // .focused.workspace_ref')
Bash(run_in_background: true): cmux-rebalance-guard "$LEAD_WS" 90 0.1 50 5
```
> **clean-grid vs robust**: `FAST=1`(BASE==1, Lead 단독)이면 단발 push 빠른 경로(squish 결정론·우측 행 이미 균등 — 실측), 기존 pane 이 있으면(BASE>1) robust 다회 수렴(섞임/비그리드/소유권 변형 위험 회피).
> ⚠️ **BASE/EXPECTED 는 반드시 spawn 전에 캡처해 넘긴다** — 워처가 자기 시작 시점(=panes 생성 후)에 baseline 을 잡으면 값이 부풀려져 감지가 안 돼 cap 까지 헛돈다(실측 버그 — claude-2.22.1 수정). panes 는 한꺼번에가 아니라 **하나씩 순차 등장**하므로 EXPECTED(목표 수) 도달을 종료 신호로 쓰는 게 가장 정확하다(2.22.2).

> **왜 워처인가 (타이밍 당김)**: 종전엔 "전부 spawn **반환** 후 Lead 가 별도 턴에서 `cmux-rebalancing` 수동 호출"이라, ① `Agent` 툴 반환 지연 ② Lead 턴 생성 지연이 끼어 rebalance 가 **팀원 부팅·작업 시작 이후**로 한참 늦게 떴다(사용자 실측). 워처를 spawn 과 동시에 띄우면 **panes 생성 직후(가장 이른 시점)** 정렬된다.
>
> ⚠️ **중간(첫 spawn 후) 호출이 무의미한 건 동일** — Agent-tool spawn 은 매번 Lead pane 을 재차 찌부러뜨린다(실측: 60%→26%→복원). 워처는 "증가가 멈춰 settle" 될 때까지 기다리므로 모든 spawn 이 끝난 시점을 자동으로 잡는다. 재spawn(죽은 팀원 교체)으로 pane 이 바뀌면 워처를 다시 발사.
>
> **폴백(워처 미설치 / cmux 외부 §0-2)**: 종전처럼 모든 spawn 반환 후 `cmux-rebalancing` 1회 수동 호출(좌→우: 2컬럼=60:40 / 3컬럼=40:30:30 / 4컬럼=25:25:25:25 / 5+=균등. 사용자 명시 비율: `cmux-rebalancing 7:3`) + `cmux focus-pane --pane "$LEAD_REF"`. cmux 외부 실행 시 자동 skip.

### 2-4. 진행 로그 (관찰성) — deft-log

팀 오케스트레이션(preflight 게이트·팀원 spawn·rebalance·단계 게이트·검증·정리)은 진행 신호가 SendMessage 보고와 pane 출력에 흩어져, "지금 전체가 어느 단계인지"를 한눈에 보기 어렵다(특히 spawn 직후·정리 구간). `deft-log` 헬퍼로 **work-id 단위 진행 로그**를 남겨 사용자가 실시간 관찰 + 사후 추적할 수 있게 한다(multi-round §진행 로그 와 동일 사상·동일 헬퍼).

- **로그 파일**: `~/.claude/plugin-data/deft/agent-teams/<work-id>/orchestration.log` (`deft-log` 가 기록 — §0-1 에서 설치. PATH 에 없으면 `~/.local/bin/deft-log` 절대경로). 이하 `LOG_DIR="$HOME/.claude/plugin-data/deft/agent-teams/<work-id>"`.
- **작업 시작 직후 사용자에게 `tail -f $LOG_DIR/orchestration.log` 를 안내**한다 (실시간 관찰 경로).
- 다음 마일스톤마다 `deft-log "$LOG_DIR" <LEVEL> "<무엇>"` 한 줄:
  - `STEP` preflight 통과 / 팀원 spawn / rebalance / 각 단계 게이트 진입(요건분석→영향도→Plan→체크리스트 단계N) / 검증 / 정리 진입·완료.
  - `WAIT` Lead 가 다음 액션을 못 하고 대기하는 5초+ 구간 · `DONE` 단계 완료 · `BLOCKED` 차단(preflight `STOP_TEAM_SPAWN`·사용자 개입 필요) · `WARN`/`ERROR`.
- **preflight 게이트 연동**: §0-1 의 `STOP_TEAM_SPAWN`/`KEEPALIVE_HARDFAIL` 감지 시 `deft-log "$LOG_DIR" BLOCKED "세션 바이너리 삭제 — teammate spawn 불가. 세션 재시작 필요"` 를 남기고 spawn 을 진행하지 않는다(무진행 침묵 금지).
- **팀원 idle 은 정상**(§2-1)이므로 `WAIT` 를 남발하지 않는다 — idle 대기 자체는 로그하지 않고, **Lead 의 단계 전환·게이트·정리**를 기록한다.
- 최근 로그 빠른 확인: `deft-log "$LOG_DIR" --tail`.

---

## 3. 데이터 경로 & work-id 규약 & 연속성 (핵심)

### 3-1. 두 영역 — 내장(휘발 가능) vs 스킬 데이터(영속)

| 영역 | 경로 | 소유 | 성격 |
|---|---|---|---|
| **Claude Code 내장** | `~/.claude/teams/session-<id>/config.json` | Claude Code | 암묵적 팀 자동 관리. **위치·키는 Claude Code가 정한다**(이전 불가). **세션 종료 시 자동 삭제** |
| | `~/.claude/tasks/session-<id>/` | Claude Code | Task* 자동 관리 (이전 불가) |
| **스킬 작업 데이터** | `~/.claude/plugin-data/deft/agent-teams/` | **본 skill** | **영속 작업노트.** plugin update에도 안전 |

> ⚠️ 작업 데이터를 **plugin cache**(`~/.claude/plugins/cache/.../skills/agent-teams/`)에 두면 안 된다. cache는 version-locked·자동 관리 영역이라 plugin update 시 새 version으로 교체되며 **데이터가 소실**된다. 작업 데이터는 반드시 `~/.claude/plugin-data/deft/agent-teams/` 하위에 둔다.

### 3-2. work-id — 영속 작업 키 (연속성의 핵심)

`work-id`는 **하나의 작업을 세션·팀과 무관하게 식별하는 영속 키**다. 내장 `team-name`(매 세션 새로 지어질 수 있는 휘발 키)과 **분리**한다.

- **team-name** (내장): Claude Code가 `session-<id>` 로 자동 관리. 세션마다 새로 생성되고 세션 종료 시 삭제됨.
- **work-id** (스킬 통제): 사용자가 부여하는 영속 키. **같은 작업이면 같은 work-id 재사용** → 같은 작업노트를 물어 연속성 유지.

→ 사용자가 팀을 **몇 번을 새로 띄우든, team-name이 무엇이든, 같은 work-id만 대면** 같은 작업노트(`work.md`)를 이어받는다. 내장 팀이 세션마다 새 `session-<id>` 로 생기고 세션 종료 시 사라져도(공식 동작), work-id만 같으면 작업노트를 이어받으므로 견고하다. (§0-3의 "in-process teammate resume 불가" 한계를 이 설계가 보완)

### 3-3. work-id 명명 규약 — 최초 1회 결정 + 영속 저장 (deft 플러그인 공통)

work-id를 **어떤 규칙으로 만들지**는 특정 값(예: 티켓번호)을 강요하지 않고, **사용자 환경마다 최초 1회 결정**한다. 이 규약은 본 skill 전용이 아니라 **deft 플러그인 공통** — `multi-round` 도 같은 규약·같은 config 를 사용한다 (어느 skill 이 먼저 실행되든 한 번 정하면 양쪽 공유).

**① 최초 실행 시 (규약 미설정이면):** 다음 메뉴를 출력하고 선택받는다.
```
이 환경의 work-id(작업 영속 키) 규약을 정해주세요:
  1. 외부 이슈/티켓 번호 (예: IT-14610, JIRA-123, #456)
  2. git 브랜치명
  3. 날짜-작업명 (예: 20260608-refactor-auth)
  4. 자유 작업명 (예: refactor-auth)
  5. 매번 직접 입력

번호 입력:
```

**② 결정을 영속 저장** (두 파일, **플러그인 공통 루트** — update-safe):
```
~/.claude/plugin-data/deft/
├── config.json     ← 기계용 SSOT (deft 공통 — agent-teams + multi-round 공유)
│   { "workIdConvention": "<선택값>", "example": "<예시>", "decidedAt": "<YYYY-MM-DD>" }
└── CONVENTION.md    ← 사람용 명시
    # work-id 규약 (현재)
    - 규약: <선택값 한국어 설명>
    - 예시: <예시>
    - 적용 skill: agent-teams (작업노트 키) / multi-round (회의 연계 키)
    - 변경하려면: 스킬에 "work-id 규약 바꿔" 요청  또는  이 파일 + config.json 직접 수정
```

**③ 이후 실행:** `config.json`/`CONVENTION.md`를 읽어 규약대로 work-id 생성·확인. **재질문하지 않는다.**

**④ 규약 변경:** 사용자가 `"work-id 규약 바꿔"`(또는 "규약 변경", "work-id 규칙 바꿔") 요청 시 → ①의 메뉴 재출력 → 선택 → `config.json` + `CONVENTION.md` **두 파일 갱신**. (기존 작업 디렉토리는 그대로 두고, 이후 신규 작업부터 새 규약 적용. multi-round 에도 즉시 반영됨 — 같은 config)

**⑤ 구버전 config 마이그레이션:** `~/.claude/plugin-data/deft/agent-teams/config.json` (skill 전용 위치 — 구버전) 이 존재하고 공통 위치에 없으면, 공통 위치로 **이동**(mv) 후 사용. 재질문하지 않는다.

> 규약 "값"은 plugin-data에 저장하고, 본 SKILL.md(=plugin cache)에는 규약 "값"을 적지 않는다 — cache는 update 시 교체되어 소실되기 때문. SKILL.md는 위 메커니즘·변경 절차만 정의한다.

### 3-4. 작업 디렉토리 구조 + 연속성 절차

```
~/.claude/plugin-data/deft/agent-teams/<work-id>/
├── work.md            ← (필수) Lead 단독 writer. 영속 작업노트 (SSOT)
├── team.md            ← (선택) 팀 운영 지침 (작업 특화)
├── <role>.md          ← 팀원별 (backendDev.md / frontendDev.md / qa.md, suffix 변형 허용: backendDev-sql.md)
└── (작업 부산물 자유 추가 — 배포 스크립트·성능테스트 폴더 등)
```

**연속성 절차 (스킬이 강제 — 세션 재시작 손실 방어 + 누락 방지):**
```
팀/작업 시작 시:
  1. work-id 확정 (§3-3 규약대로. 애매하면 1회 질문)
  2. <work-id>/work.md 존재?
     ├─ 있음 → 로드 → "## 완료 항목" 이후 "## 작업 계획"의 미완료 체크리스트부터 이어서
     └─ 없음 → §6-1 템플릿으로 신규 생성
  3. multi-round 회의록 교차 참조 (§3-5):
     ~/.claude/plugin-data/deft/multi-round/sessions/<work-id>/ 존재?
     ├─ 있음 → 최근 회의의 합의 결과(`summary.md` 우선, 없으면 `board.jsonl` 회의록 원본)를
     │         확인하고, 미반영 결정이 있으면 work.md `## 설계 결정` 에 반영 (Lead)
     └─ 없음 → skip
  4. 각 팀원도 본인 <role>.md 존재 시 미완료 항목부터 이어서 진행
  5. work.md `## META`에 "현재 team-name" 기록 (내장 team-name 추적용)
```

> `work.md`의 `## 작업 계획` 체크리스트가 **유일한 진행 상태 소스**다(누락 방지). 부산물 파일(배포 스크립트·성능테스트 폴더 등)은 같은 `<work-id>/` 하위에 자유롭게 둘 수 있다(강제 스키마 아님).

### 3-5. multi-round 와의 교차 참조 (같은 work-id)

`multi-round` 회의도 기본적으로 같은 work-id 에 연계된다 (multi-round SKILL 참조). 두 skill 의 산출물은 같은 키로 상호 참조 가능:

| 방향 | 시점 | 동작 |
|---|---|---|
| **회의 결과 → 팀** | 팀/작업 시작 시 (위 연속성 절차 3단계) | `multi-round/sessions/<work-id>/` 의 합의 결과를 work.md `## 설계 결정` 에 반영 |
| **팀 산출물 → 회의** | multi-round 회의 시작 시 | multi-round 가 `agent-teams/<work-id>/work.md` 를 읽어 워커 컨텍스트로 inject |
| **작업 중 토론 호출** | 팀 진행 중 결정이 갈릴 때 | Lead 가 같은 work-id 로 multi-round 호출 → 합의 후 work.md 에 결정 기록 → 팀 진행 재개 |

---

## 4. 작업 흐름 — 단계 게이트 (도구 무관 강제)

팀이든 단독이든 다음 단계 게이트를 따른다. **각 단계 사이 사용자 컨펌 없이 다음으로 자동 진행하지 않는다**(walk-away 모드 명시 시 예외).

```
1. 요건 분석        → 작업 목표·범위·요구사항 파악
2. 영향도 확인      → 변경이 닿는 레이어·모듈·데이터 흐름 분석
   → ★ 사용자 컨펌 (1+2 결과 보고 후 승인)
3. Plan 수립        → 구현 계획 + work.md `## 작업 계획` 체크리스트 작성
   → ★ 사용자 승인 (Plan 확정)
4. 체크리스트 진행  → 각 단계 구현·검증, 완료 시 [O] 갱신
   → ★ 각 단계 완료 시 사용자 컨펌 후 다음
5. 결과 보고
```

체크리스트 플래그: `[ ]` 미진행 / `[>]` 진행중 / `[!]` 보류(사유 필수) / `[O]` 완료 / `[X]` 취소(사유 필수).
상위 항목 상태는 하위 종합: 하위에 `[ ]` 있으면 상위 `[ ]`; `[ ]`없고 `[>]` 있으면 상위 `[>]`; 둘 다 없고 `[!]` 있으면 상위 `[!]`; 하위 모두 `[O]`/`[X]`면 상위 `[O]`.

### 4-1. 팀원 작업 시작 절차

팀원이 spawn되면:
1. 본 skill 패키지(SKILL.md + `agents/<role>.md`)를 숙지한다 (spawn task instruction에 경로 inject — §4-3).
2. `<work-id>/team.md` 가 있으면 필수 지침으로 준수.
3. `<work-id>/work.md`에서 `## 요건 분석` / `## 영향도 확인` / `## 설계 결정` / `## 작업 계획`(본인 담당 번호) 확인.
4. 본인 `<role>.md` 확인 — 있으면 미완료부터 이어서, 없으면 work.md 작업계획의 본인 담당 항목으로 생성.
5. **Plan 보고** (구현 전 필수): 담당 항목의 변경 요약·영향 범위·검증 방법을 Lead에 `SendMessage`.
6. Lead 승인 후 구현 시작.

### 4-2. Plan 게이트 (구현 전 필수)

- 팀원은 구현 전 **Plan을 Lead에 보고**하고 승인받는다. 승인 전 코드 수정·파일 생성 금지.
- Lead 승인 후 구현 → 완료 시 5-항목 형식(변경요약/핵심Diff/전체Diff/영향범위/검증방법)으로 재보고.
- Plan 보고 없이 코드 수정 시 Lead가 git diff로 감지 → 되돌리고 재작업 요청.

### 4-3. 팀원 spawn task instruction 템플릿

#### Agent 도구 호출 인자

팀원 모두 **Claude Opus (`opus`)**. **`model:"opus"` 명시 필수** — 미지정 시 팀원이 **차단된 `fable` 기본값**으로 떠서 조용히 실패한다(실측 확인). 팀원은 Lead의 모델을 상속하지 않는다(공식 문서). enum: `sonnet`/`opus`/`haiku`/`fable`.

```text
Agent(
  name: "<role>",                    # backendDev / frontendDev / qa 등 — SendMessage 호출 키
  subagent_type: "claude",           # 범용. 페르소나는 prompt 본문의 agents/<role>.md Read 로 주입(아래)
  model: "opus",                     # ← 필수. 미지정 시 fable(차단)로 떠서 실패
  description: "<역할 한 줄 요약>",
  prompt: "<아래 task instruction 본문>"
)
# team_name 인자는 넣지 않는다(deprecated/무시). 팀은 첫 spawn 시 session-<id> 로 자동 생성된다.
```

#### task instruction 본문

`Agent` 도구로 팀원 spawn 시 다음을 task 에 포함한다.

```text
[역할/페르소나]
- 본인 역할: <role> (예: backendDev)
- 페르소나: 본 skill 패키지의 `agents/<role>.md` 를 Read 하여 적용.
  경로는 **버전 독립 marketplace 우선, 없으면 최신 캐시**로 해석한다 (⚠️ 캐시 글롭은 `sort -V|tail -1` — `head -1` 은 ls 알파벳 정렬로 가장 오래된 버전을 집어 구버전 페르소나를 읽는다, 실측):
  - 1순위: `~/.claude/plugins/marketplaces/bluehansl/plugins/deft/skills/agent-teams/agents/<role>.md`
  - 2순위(캐시 전용 설치): `$(ls -d ~/.claude/plugins/cache/bluehansl/deft/*/skills/agent-teams/agents 2>/dev/null | sort -V | tail -1)/<role>.md`
  - skill 경로는 Read 전용 — **데이터는 절대 거기 쓰지 말 것**.
- 작업 특화 override: <work-id>/team.md 의 `## 팀원 기본 프롬프트 골격`에 본인 역할 항목 있으면 우선

[필수 컨텍스트 — 작업 시작 전 Read]
1. 본 SKILL.md (§4 작업 흐름·§5 통신·§6 파일 구조)
2. ~/.claude/plugin-data/deft/agent-teams/<work-id>/team.md (있으면)
3. ~/.claude/plugin-data/deft/agent-teams/<work-id>/work.md (요건분석/영향도/설계결정/작업계획)
4. ~/.claude/plugin-data/deft/agent-teams/<work-id>/<role>.md (있으면 미완료부터, 없으면 생성)

[강제 게이트]
- 구현 전 Plan 보고 → Lead 승인 후 진행 (§4-2)
- 각 작업 항목 완료 시 즉시 본인 <role>.md 갱신 (§5-3)
- work.md 직접 write 금지 — Lead 단독 (§6)
- 변경 제안 시 5-항목 형식 (요약/핵심Diff/전체Diff/영향범위/검증)
- 본인 cwd 프로젝트의 AGENTS.md/CLAUDE.md 컨벤션 강제 준수

[통신]
- Lead·상대 팀원과 SendMessage로 통신. 직접 통신 후 즉시 Lead에 보고.
- 신호: ACK / STATUS / BLOCKED / DONE (+ 회의 모드별 신호 §8-2)

[금지]
- work.md 직접 수정 금지
- 사용자 컨펌 없이 다음 체크리스트 단계로 진행 금지
- 본인 cwd 외 프로젝트 코드 임의 수정 금지
```

---

## 5. 통신 규칙

### 5-1. 통신 매핑 (내장 도구)

| 의도 | 도구 |
|---|---|
| 팀원 → Lead 보고 | `SendMessage(to="<lead-name>", ...)` |
| 팀원 → 팀원 직접 통신 | `SendMessage(to="<peer-name>", ...)` |
| 작업 분배·진행 추적 | `Task*` (공유 task list) |
| 통신 단절 폴백 | 본인 `<role>.md` `## 이슈/협의 필요` 섹션 누적 |

### 5-2. 팀원 간 직접 통신

- 팀원 간 직접 메시지 허용. 직접 통신 후 **즉시** Lead에 보고(마지막에 몰아서 X).
- 보고 내용이 팀원 간 불일치하면 Lead가 조율.
- Lead 크로스 체크: 특정 팀원만 보고한 내용은 Lead가 다른 팀원에게 확인.

### 5-3. 팀원 md 기록 규칙

1. 각 작업 항목 완료 시 **즉시** 본인 `<role>.md` 갱신(일괄 기록 X).
2. 계획에 없는 작업 필요 시 **구현 전** `<role>.md` 담당 계획에 먼저 추가.
3. **본인 `<role>.md`는 통신 단절·세션 재시작 시 진실의 단일 소스**. Lead 미응답 시 진행·전달 사항을 `## 이슈/협의 필요`에 누적. 복구 후 Lead가 Read → work.md `## 협의사항`으로 머지(머지 후 해당 항목 `[O→work.md]` 표시). 별도 임시파일 금지.

> **work.md 는 Lead 단독 writer.** 모든 팀원(qa 포함)은 **본인 `<role>.md`만** write 한다. 팀원의 산출물은 Lead가 work.md의 해당 섹션(예: `## QA`)으로 취합한다.

### 5-4. work.md 협의사항 `@{role}:` 태그

Lead가 work.md `## 협의사항`에 종합할 때 출처를 줄 단위로 `@{role}:` 태그(시간 옵셔널). `@Lead:`는 Lead 결정·조율. 한 thread는 시간순 누적(뒤집기 금지). work.md 단독 writer는 Lead — 태그는 출처 표기 수단이지 공동쓰기 허용 아님.

---

## 6. 파일 구조 & 템플릿

### 6-1. work.md 표준 구조 (Lead 단독 writer)

```markdown
# <work-id> - <제목>

## META
- work-id: <work-id>
- 현재 team-name: <team-name>   ← 내장 팀 추적
- 상태: <Draft | In Progress | Blocked | 검증중 | 완료>
- 작성일 / 최종 수정일: <YYYY-MM-DD>
- 대상 모듈/화면: <...>
- 핵심 파일: `<경로>` (<메서드/식별자>, 라인 <N~M>)
- 도구: <단일 Claude | Agent Teams | 혼합>

## 요건 분석
### 작업 목표 / 작업 범위(포함·제외) / 요구사항 상세 / 원인 분석(버그·튜닝 시)

## 영향도 확인
### <레이어별 — 예: Controller / Service / Mapper·SQL / Entity 등>

## 설계 결정
### 채택한 방식 / 미채택 대안 및 사유 / 미해결 결정사항
- [ ] {Q1} → 해결 시 [해결] {결론, YYYY-MM-DD}

## 완료 항목
<!-- 세션 재시작 시 여기까지는 끝난 것. 이후 작업계획 미완료부터 이어서 -->

## 작업 계획
<!-- 체크리스트가 유일한 진행 상태 소스 -->
### Phase 1: ...
- [ ] 1. {항목}
  - [ ] 1-1. {세부}
### Phase 2: ... ← (3번과 병렬)
- [ ] 2. {항목}

## 협의사항
<!-- @{role}: 태그로 인터페이스 협의·기획 변경 이력 누적 -->

## <역할별 취합>
<!-- FRONTEND / BACKEND / QA — 각 role.md 취합본 (Lead가 취합) -->

## REVIEW
<!-- 코드 리뷰 + 테스트 결과 -->

## 검증 이력
### <YYYY-MM-DD> <제목> — 목적 / 방식 / 결과 / 잔여물

## 롤백/복구
- 코드 롤백: <브랜치/커밋> / 데이터 롤백: <절차>
```

### 6-2. team.md 구조 (선택 — 작업 특화 팀 지침, Lead가 팀 생성 전 작성)

```markdown
# <work-id> - Team Guide

## 준수 지침 (우선순위)
1. 사용자 명시 지시
2. 본 파일 (team.md)
3. 프로젝트 컨벤션 (cwd의 AGENTS.md/CLAUDE.md)
4. 본 skill 공용 운영 규약 (SKILL.md)

## 팀 구성 (본 작업)
| 역할 이름 | 담당 | 페르소나 |
|---|---|---|
| backendDev | ... | agents/backendDev.md |
| frontendDev | ... | agents/frontendDev.md |
| qa | ... | agents/qa.md |

## 확정된 설계 결정 (Lead)
## Blocker 가정값
## 팀원 기본 프롬프트 골격
### <역할명> (override, 옵션)
- 기본: agents/<역할명>.md 적용
- 본 작업 특화: <...>   (override는 추가·강조·금지만, 페르소나 전체 재정의 금지)
```

### 6-3. 팀원 md 구조 (`<role>.md` 공통)

```markdown
# <work-id> - <Role>

## 담당 작업 계획
<!-- work.md 항목을 work#N 으로 참조, 자체 세부 번호는 독립 -->
### work#3. {작업 항목}
- [ ] 1. {세부}

## 구현 내용
### {항목} (YYYY-MM-DD)
- 수정 파일: `<경로>` (<식별자>, 라인 <N~M>)
- 변경 내용: {무엇을 어떻게}
- 사유: {왜} (비자명한 경우만)

## 이슈 / 협의 필요
<!-- 통신 단절 시 폴백 누적 영역 (§5-3) -->
- {YYYY-MM-DD HH:MM} {수신자} {내용}
- {YYYY-MM-DD HH:MM} [통신단절중] {Lead 응답 대기 누적분}
```

### 6-4. Lead의 diff 검증

팀원이 완료 보고 → Lead가 git diff로 계획 대비 확인 → 일치하면 work.md 체크리스트 `[O]` + 역할별 섹션 취합; 불일치/이슈면 재작업 요청. 리뷰 결과는 `## REVIEW`. 테스트 코드는 사용자 요청 시에만 작성.

---

## 7. 팀 구성 & 페르소나

### 7-1. 기본 구성 (3인 + 옵션)

| 역할 | 담당 | 페르소나 |
|---|---|---|
| **Lead** | 팀장 + 기획 (사용자 직접 소통, work.md 단독 writer) | `agents/lead.md` |
| `backendDev` | 백엔드 개발 | `agents/backendDev.md` |
| `frontendDev` | 프론트엔드 개발 | `agents/frontendDev.md` |
| `qa` | 테스트 시나리오·검증 | `agents/qa.md` |

- **기본 3인(BE/FE/QA) 자동 spawn**. 사용자가 "QA 없이" / "BE만" 명시 시 축소.
- 모두 Claude — 동질 시각, 컨벤션 강제 일관. Lead가 기획 겸임(별도 기획 팀원 X).

### 7-2. 추가 역할 (선택)

| 역할 | 추가 트리거 | 페르소나 |
|---|---|---|
| `designer` | 신규 화면·UI 변경·디자인 시스템 영향 | `agents/designer.md` |
| `architect` | 영향도·설계가 복잡 | `agents/architect.md` |
| `reviewer` | PR 사인오프(이중 리뷰) | `agents/reviewer.md` |
| `pm-{관점}` | 의사결정 양면 토론 (`pm-user`/`pm-eng`/`pm-ops`) | `agents/pm.md` |

### 7-3. 네이밍 & 페르소나 적용

- 동일 역할 복수: `{역할}-{담당영역}` (예: `backendDev-sql`, `frontendDev-modal`). 각 역할 최대 2명 권장.
- 모든 팀원은 spawn 시 `agents/<role>.md` 페르소나를 자동 적용. 작업 특화 조정은 `team.md` override(추가·강조·금지만).
- 페르소나는 **프로젝트 코드 컨벤션을 cwd의 `AGENTS.md`/`CLAUDE.md`로 일반 참조**한다(특정 프로젝트에 종속되지 않음).
- 팀원 이름은 항상 **name**으로 호출(SendMessage `to`, Task owner).

### 7-4. 혼합 운영

같은 작업 내 단계별로 다른 도구 허용. 예: 분석·Plan은 단일 Claude → 구현은 Agent Teams 3인 → 의사결정 토론은 multi-round. 도구 전환해도 work.md 체크리스트는 유지(writer는 항상 Lead). `## META 도구` 필드에 기록.

### 7-5. `/workflows` 대규모 fan-out 오프로드 (선택)

Lead 또는 **팀원**은 경계가 분명한 **대규모·결정론적 fan-out 작업**을 Claude Code의 `/workflows`(Workflow 도구)로 오프로드할 수 있다. 팀의 양방향 대화(SendMessage)와는 **직교**하는 별개 수단이다.

- **언제**: "이 변경의 호출부 50곳 병렬 감사", "N개 파일을 같은 규칙으로 변환", "주장 다건 독립 검증" 등 — 항목이 많고 서로 대화가 불필요한 작업.
- **왜 팀과 잘 맞나 (실측 확인)**:
  - 팀원도 Workflow 사용 가능 — 중첩-팀 금지에 안 걸림(워크플로 에이전트는 '팀원'이 아니라 격리 서브에이전트).
  - Lead가 활성 팀과 **동시에** Workflow 실행 가능.
  - 워크플로 서브에이전트는 **cmux 팀 pane을 만들지 않음** → 대화형 팀 pane을 안 어지럽히고 fan-out.
  - 중간 결과가 스크립트 변수에 머물러 **Lead 컨텍스트 절약**(구조화된 결과만 회수).
- **무엇이 아닌가**: Workflow 에이전트는 **서로 대화하지 않는다**. 팀원 간 양방향 협의가 필요한 일은 Workflow가 아니라 팀(SendMessage)·`multi-round` 다.
- **주의**: Workflow 는 사용자 명시 opt-in 이 필요한 무거운 도구. 팀 작업 중 자동 남발 금지 — 대규모 fan-out 이 실제로 이득일 때만 사용 보고 후 실행.

---

## 8. 회의 모드 & 페어/Trio 패턴

페어/Trio 등 팀원이 서로 의견을 주고받는 구조의 운영 모드. 신호는 `SendMessage` **본문 텍스트 규약**으로 표현한다.

### 8-1. 모드 분류

| 모드 | 종료 조건 | 적용 |
|---|---|---|
| **consult** | 팀원 DONE 1회 | 단발 정보 요청 |
| **dialogue** (페어 기본) | `CONSENSUS` 양쪽 일치 또는 max-round(기본 5) | PM 페어, FE-BE 인터페이스 협의 |
| **collaborate** | 양쪽 `REVIEW_PASS` 교차 | 동일 역할 2명 분담 협업 |
| **debate** | 한쪽 `CONCEDE` 또는 max-round(기본 7) | 의사결정 강한 양면 검증 |
| **cascade** | 마지막 단계 DONE | 3인 Trio (architect→backend→qa 순차) |
| **signoff** | 양쪽 `VERDICT: COMPREHENSIVELY_SATISFIED` | PR 이중 리뷰 |

### 8-2. 신호 프로토콜 (SendMessage 본문 규약)

기본 ACK / STATUS / BLOCKED / DONE 에 다음 추가:

| 신호 | 의미 | 모드 |
|---|---|---|
| `CONSENSUS: <합의>` | 양쪽 같은 결론 | dialogue/debate 종료 |
| `AGREED: <동의>` / `DISSENT: <이견+사유>` | 동의 / 이견(대화 계속) | dialogue |
| `CONCEDE: <항복+사유>` | 입장 철회 | debate 종료 |
| `DISTRIBUTE: <본인 분담 + 상대 분담안>` | 작업 분배 제안·합의 | collaborate |
| `REVIEW_PASS: <대상+코멘트>` / `REVIEW_FAIL: <대상+사유+재작업>` | 상호 리뷰 통과/불통과 | collaborate |
| `VERDICT: COMPREHENSIVELY_SATISFIED` / `VERDICT: NOT_SATISFIED: <사유>` | 사인오프 판정 | signoff |

### 8-3. 주요 패턴

| 패턴 | 구성 | 모드 | 흐름 요약 |
|---|---|---|---|
| **PM 페어** | Lead(`pm-eng`) + `pm-user` | dialogue | 같은 주제 양면 토론 → Lead 종합 → work.md `@pm-*:` 누적 → `@Lead:` 채택 |
| **FE-BE 페어** | frontendDev + backendDev | dialogue | 각자 인터페이스안(요청/응답 스키마·error code) → 상호 공유 → Lead가 `## 설계 결정` 확정 |
| **3인 Trio** | architect → backendDev → qa | cascade | 영향도→구현→검증 순차. 각 단계 DONE+사용자 컨펌 후 다음 |
| **동일역할 협업** | `backendDev-a` + `backendDev-b` | collaborate | 분배(DISTRIBUTE)→분담 구현(병렬, 각자 DONE)→상호 리뷰(REVIEW_PASS/FAIL)→양쪽 PASS면 종료 |
| **이중 리뷰** | Lead + `reviewer` | signoff | 각자 독립 VERDICT → 양쪽 SATISFIED면 사인오프, 한쪽 미만족이면 수정→재리뷰 |

> collaborate 상호 리뷰 시 **자기 분담은 본인이 점검 안 하고 상대가 리뷰**한다(편향 회피). `reviewer`는 가능하면 Lead와 시각이 겹치지 않는 독립 컨텍스트로 운영.

### 8-4. 회의 종료 절차 (공통)

종료 조건 충족 시: ① Lead가 work.md `## 협의사항`에 `@{role}:` 합의 누적 → ② 사용자에게 결과 보고(한국어 종합) → ③ 팀원은 idle 유지(§9 세션 관리, 자동 종료 X). 종료는 사용자가 명시할 때만(§9-1).

---

## 9. 세션 관리

- 팀원 세션을 자동 종료하지 않는다. 작업 완료 시 **idle 대기**(정상 상태). 추가 지시를 기다린다.
- **종료는 사용자가 자연어로 지시할 때만** 수행한다 — 예: "프론트 팀원 종료해", "팀 정리해", "팀 종료". Lead는 해당 팀원/팀의 종료를 처리한다.

### 9-1. 종료·정리 — 소유권 안전 (파괴 행위)

shutdown / `tmux kill-pane` 은 되돌릴 수 없다. **반드시 본 Lead 세션이 spawn 한 팀원만** 종료·정리한다. cmux 는 **다중 워크스페이스·다중 세션** 환경이므로 다른 세션/워크스페이스 pane·팀원을 **절대 건드리면 안 된다**.
- 대상: Lead 가 spawn 시 받은 `<name>@session-<id>` 의 그 이름·그 team-name, 본 세션 team config(`~/.claude/teams/session-<id>/config.json`) 등록 멤버만.
- **전체 tmux pane 순회·와일드카드 kill 금지.** 다른 이름/접미(`-N`)·다른 session-id 워커는 "잔재"로 단정 금지(`--parent-session-id` 로 소속 확인).
- 정리 진입 시 `deft-log "$LOG_DIR" STEP "팀/팀원 정리 시작"` 로 기록한다(관찰성 §2-4).

**① graceful 종료**: `SendMessage(to="<팀원이름>", message={type:"shutdown_request"})` → **`shutdown_approved`/`teammate_terminated` 가 자동주입될 때까지 기다린다**. graceful 은 느릴 수 있음(공식 "Shutdown can be slow" — 6초+, 느리면 수십 초).
- 🚫 **팀원(claude Agent, in-process)에 SIGTERM/`kill`/`pkill` 을 절대 쓰지 말 것.** claude 팀원은 in-process(별도 PID 없음 — `pgrep` 으로 안 잡힘)라 kill 이 통하지도 않고, 어설픈 kill 은 메인 세션 레지스트리에 **좀비 핸들**(`N teammate started` UI 잔재)을 남긴다 — SendMessage·Esc·TaskStop·kill 다 안 먹어 **Lead 세션 재시작만이 유일 해법**(실측 사고: SIGTERM 정리 → 10+ 좀비). 정상 흐름(`shutdown_request`→approved 대기)만 쓰면 좀비 0.
- `idle_notification` 은 "아직 처리 중" 신호일 뿐 — "안 죽었다"로 오판해 ②(pane 정리)로 성급히 넘어가지 말 것. **여러 명이면 shutdown 을 모두 보낸 뒤 한꺼번에 대기**(순차 kill 루프 금지). 정리 시간 단축이 필요하면 kill 이 아니라 shutdown 을 일찍·일괄 발송하고 그 사이 결과 취합을 진행한다.

**② orphan pane 정리** (프로세스는 죽었는데 pane 만 남은 경우 — cmux `close-surface` 는 orphan 을 못 닫음): **본 세션 team config 의 tmuxPaneId 로만**, 그 pane 이 아직 존재하고 프로세스가 죽은 것만 tmux 백엔드로 직접 닫는다.
```bash
TEAM_NAME="session-<id>"        # spawn 결과(@session-<id>)에서 획득 — 본 세션 팀
CFG=~/.claude/teams/$TEAM_NAME/config.json
EXIST=$(tmux list-panes -a -F '#{pane_id}' 2>/dev/null)   # 현재 존재하는 pane id 집합
# ⚠️ 반드시 본 세션 CFG 멤버의 tmuxPaneId 만 사용. 전체 tmux 순회·다른 세션 CFG·와일드카드 절대 금지.
for NAME in <종료할 본 세션 팀원 이름들>; do
  PANEID=$(python3 -c "import json;d=json.load(open('$CFG'));print(next((m.get('tmuxPaneId','') for m in d['members'] if m['name']=='$NAME'),''))" 2>/dev/null)
  # 프로세스 죽음 + pane 잔존인 orphan 만 정리. ⚠️ 앵커는 "--agent-id $NAME@$TEAM_NAME" (단일 토큰)
  #   — 전역 "--agent-name $NAME" 은 타 세션 동명 팀원/prefix(backendDev-sql 류)까지 매칭해 오판(false-negative).
  if [ -n "$PANEID" ] \
     && ! pgrep -f -- "--agent-id $NAME@$TEAM_NAME" >/dev/null 2>&1 \
     && printf '%s\n' "$EXIST" | grep -qx "$PANEID"; then
    tmux kill-pane -t "$PANEID" 2>/dev/null
  fi
done
```
> ⚠️ cmux 환경의 `tmux` 는 호환 shim 이라 `#{pane_dead}`/`#{pane_pid}` 는 **빈 값**을 반환한다(실측) — pane 생사 판정에 쓸 수 없다. 그래서 세션앵커 `pgrep`(프로세스 생사) + `tmux list-panes`(pane 존재) + `kill-pane`(shim 지원 확인됨)로만 판정한다. 정상 graceful 종료(팀원이 `shutdown_response{approve:true}` 호출) 시엔 cmux 가 pane 을 자동으로 닫으므로 ② 는 force-kill 등 비정상 종료의 안전망이다.

**③ 레이아웃 복원** — 팀원 pane 을 닫은 뒤(부분 종료 포함) 남은 컬럼·row 를 정렬하고 focus 를 Lead 로 복원한다(multi-round §5-B 와 동일 패턴). 부분 종료가 흔한 agent-teams 에서 빈 행 흡수·focus 튐을 정리한다:
```bash
command -v cmux-rebalancing >/dev/null 2>&1 && cmux-rebalancing
cmux focus-pane --pane "$(cmux identify | jq -r .caller.pane_ref)" 2>/dev/null
deft-log "$LOG_DIR" DONE "팀원 정리·레이아웃 복원 완료"
```

---

## 10. 보안

- 민감정보(API key·password·token) 평문 노출 금지(마스킹).
- 시스템 변경(`sudo`/`chmod`/shell rc/LaunchAgents) 사전 컨펌. destructive 명령(rm -rf·force push·DB drop) 사전 컨펌 + 롤백 절차 명시.
- 팀원은 본인 cwd 외 프로젝트 코드 임의 수정 금지.

---

## 11. 빠른 시작

```
0. Phase 0 환경 검증 (§0) — 실험 플래그·버전·cmux. cmux 외부면 §0-2 fallback
1. 사용자: "이 작업 팀으로 진행해" / "backend·frontend·qa 팀 만들어"
2. (최초 실행이면) work-id 규약 결정 메뉴 출력 → config.json + CONVENTION.md 저장 (§3-3)
3. work-id 확정 → <work-id>/work.md 로드(있으면 이어서) 또는 생성 (§3-4)
4. 요건분석 + 영향도 → ★ 사용자 컨펌 (§4)
5. Plan + work.md 작업계획 체크리스트 → ★ 사용자 승인
6. Agent로 팀원 spawn — 팀은 암묵적 자동 생성(별도 TeamCreate 불요) (§4-3 템플릿, agents/<role>.md 페르소나)
7. 팀원: Plan 보고 → Lead 승인 → 구현 → <role>.md 갱신 → DONE
8. Lead: git diff 검증 → work.md [O] → ★ 각 단계 사용자 컨펌
9. 검증·리뷰 → 결과 보고. 팀원 idle 유지(자동 종료 X)
```

상세 운영 예시·체크리스트는 `GUIDE.md` 참조.
