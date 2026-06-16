---
name: agent-teams
description: 'Claude Code 내장 팀 기능으로 다중 Claude 에이전트 팀을 운영하는 skill. Lead가 역할별 팀원(backendDev/frontendDev/qa 등)을 spawn해 분석→구현→검증을 분담하고, 단계 게이트·역할 페르소나·work-id 기반 영속 작업노트로 일관성과 연속성을 보장한다. 강한 트리거 — "코딩 작업" 문구가 포함된 요청은 본 skill 로 발동 (예: "IT-14610 코딩 작업 시작", "이거 코딩 작업해줘", "코딩 작업 이어서"). 그 외 트리거 — "에이전트 팀", "팀으로 작업", "팀으로 구현", "역할 나눠서 해", "BE/FE 나눠서 해", "QA까지 붙여", "spawn a team". 단 "회의"/"미팅" 단어가 포함된 요청은 multi-round, 1발 비교는 multi-check 를 쓰세요.'
---

# Agent Teams Skill

Claude Code **내장 팀 기능**(`TeamCreate` + `Agent` + `SendMessage` + `Task*`)으로 다중 Claude 에이전트 팀을 구성·운영하는 skill. Lead(팀장 겸 기획)가 역할별 팀원(backendDev/frontendDev/qa 등)을 spawn해 분석→구현→검증을 분담하고, 단계 게이트·페르소나·영속 작업노트로 일관성과 연속성을 보장한다.

> **팀원 모델**: 모두 **Claude Opus (`opus`)** — 동질 시각, 컨벤션 강제 일관. Agent tool 호출 시 alias `opus` (§4-3).

> 본 skill은 **자기완결적**이다. 운영에 필요한 모든 규약(팀 구성·페르소나·작업 흐름·통신·파일 구조·회의 모드)이 이 패키지(SKILL.md + `agents/*.md` + `GUIDE.md`) 안에 들어있다. 외부 `AGENTS.md` 참조 없이 이 skill만으로 팀을 운영할 수 있다. 단, **프로젝트별 코드 컨벤션**(예: 특정 프레임워크 패턴)은 각 프로젝트의 `AGENTS.md`/`CLAUDE.md`가 소유하며, 페르소나는 "본인 cwd 프로젝트의 컨벤션을 준수"로 일반 참조한다(§7-3).

---

## 0. 시작 전 환경 검증 (Phase 0)

본 skill은 Claude Code의 **실험적 Agent Teams 기능**을 사용한다. 팀 spawn 전 다음을 확인한다.

### 0-1. 활성 조건

- 환경 변수 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` (실험 기능 — 기본 비활성)
- Claude Code **v2.1.32 이상**
- teammate가 활성화된 하니스에서 실행 (`cmux claude-teams`)

```bash
# Phase 0 환경 검증
[ "$CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" = "1" ] || echo "WARN: Agent Teams 실험 기능 미활성 — 활성화 또는 단일 Claude 모드로 진행"
# Claude Code 버전 v2.1.32+ 인지 사용자에게 확인
# cmux claude-teams 환경에서 실행 중인지 확인

# cmux-rebalancing 헬퍼 설치 확인 — 미설치 시 plugin 동봉본으로 자동 설치
if ! command -v cmux-rebalancing >/dev/null 2>&1; then
  SRC=$(ls -1 ~/.claude/plugins/cache/bluehansl/deft/*/bin/cmux-rebalancing 2>/dev/null | sort -V | tail -1)
  if [ -n "$SRC" ]; then
    mkdir -p ~/.local/bin && cp "$SRC" ~/.local/bin/cmux-rebalancing && chmod +x ~/.local/bin/cmux-rebalancing
    echo "INFO: cmux-rebalancing 자동 설치 완료 (~/.local/bin/)"
  else
    echo "WARN: cmux-rebalancing 미설치 + plugin 동봉본 없음 — pane 비율 자동 조정 비활성"
  fi
fi

# 세션 바이너리 keepalive — 오래된 세션에서 자동 업데이트로 세션 버전 바이너리가 삭제되면
# teammate spawn 이 "env: .../versions/<ver>: No such file or directory" 로 실패. 보존·복원으로 예방.
if ! command -v claude-bin-keepalive >/dev/null 2>&1; then
  SRC=$(ls -1 ~/.claude/plugins/cache/bluehansl/deft/*/bin/claude-bin-keepalive 2>/dev/null | sort -V | tail -1)
  [ -n "$SRC" ] && mkdir -p ~/.local/bin && cp "$SRC" ~/.local/bin/ && chmod +x ~/.local/bin/claude-bin-keepalive
fi
# deft 공용 모델 ID 헬퍼(deft-model) 설치 — 모델 차단·버전업 시 단일 관리 지점
if ! command -v deft-model >/dev/null 2>&1; then
  SRC=$(ls -1 ~/.claude/plugins/cache/bluehansl/deft/*/bin/deft-model 2>/dev/null | sort -V | tail -1)
  [ -n "$SRC" ] && mkdir -p ~/.local/bin && cp "$SRC" ~/.local/bin/ && chmod +x ~/.local/bin/deft-model
fi
if command -v claude-bin-keepalive >/dev/null 2>&1; then
  claude-bin-keepalive || echo "STOP_TEAM_SPAWN: 세션 바이너리 복원 불가(KEEPALIVE_HARDFAIL) — 이 세션의 teammate spawn 은 반드시 실패한다."
fi
```

**preflight 게이트 (필수)**: 위 출력에 `STOP_TEAM_SPAWN`(또는 `KEEPALIVE_HARDFAIL`)이 보이면, 팀 spawn(TeamCreate/Agent) 를 **실행하지 말 것**. 대신 사용자에게 "이 세션은 자동 업데이트로 Claude Code 바이너리가 삭제됐습니다. `cmux claude-teams`(또는 `/resume`)로 세션을 재시작한 뒤 다시 시도하세요"를 안내하고 중단한다. (work-id 영속 설계로 연속성은 유지됨.)

> **`cmux-rebalancing`**: 팀원 spawn 후 Lead 와 팀원 컬럼 비율을 정책대로 재조정하는 헬퍼. 모든 팀원 spawn 직후 자동 호출 (§2-2 끝).

### 0-2. cmux 외부 실행 시 (fallback)

팀원 시각화(pane 자동 분할, §2-2)는 `cmux claude-teams` 환경에서만 동작한다. **cmux 외부**에서 실행 중이면:

- **기본: 단일 Claude 모드로 degrade** — 팀 spawn을 skip하고 Lead 단독으로 §4 단계 게이트를 진행한다. 의견 토론·합의가 목적이면 `deft:multi-round`를 권유한다.
- **권장 안내: `cmux claude-teams` 재시작** — 팀 운영·시각화가 필요하면 사용자에게 재시작을 권한다.
- 사용자가 "시각화 없이 그냥 팀으로" 명시 요청한 경우에만, pane 분할 없이 `TeamCreate`/`Agent`를 진행하되 **"시각화 비활성" 상태임을 사용자에게 명시 보고**한다.

### 0-3. 운영 제약 (limitation)

| 제약 | 의미 | 대응 |
|---|---|---|
| **한 lead = 한 team** | 한 Lead가 동시에 여러 팀을 운영할 수 없다 | 작업을 한 팀 단위로 정리 |
| **nested team 불가** | 팀원이 그 안에서 다시 팀을 spawn할 수 없다 | 팀 구성은 Lead가 한 번에 결정 |
| **in-process teammate resume 불가** | 세션 재시작 시 팀원이 자동 복구되지 않음 → 새 team-name으로 다시 spawn 필요 | **work-id 영속 설계(§3)가 보완** — 같은 work-id로 `work.md`·`<role>.md` 연속 |
| **task status lag** | `TaskList` 갱신이 지연될 수 있음 | 팀원 idle/완료를 성급히 단정하지 않음 |
| **팀 네임스페이스 전역 공유** | `~/.claude/teams/`·`~/.claude/tasks/` 는 모든 세션 공유 — 같은 work-id 작업을 두 세션이 동시에 열면 team-name 충돌 (메시지 교차·정리 오발) | 한 작업은 한 세션 원칙. 충돌 의심 시 team-name 에 시각 suffix. **정리(TeamDelete/shutdown/rm) 전 본 세션 생성분인지 확인** — 프로세스 `--parent-session-id` 또는 생성 시점 대조. "이름이 같다 ≠ 내 것" |

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

본 skill은 Claude Code 내장 도구 4종으로만 동작한다.

| 도구 | 역할 |
|---|---|
| `TeamCreate` | 팀 + 공유 task list 생성 (`~/.claude/teams/<team-name>/`, `~/.claude/tasks/<team-name>/`) |
| `Agent` (`team_name`+`name`) | 팀원 spawn (역할별 페르소나 주입) |
| `SendMessage` | 팀원↔Lead, 팀원↔팀원 직접 통신 |
| `Task*` (TaskCreate/Update/List) | 작업 분배·진행 추적 (공유 task list) |

### 2-1. 자동 메시지 전달 — 폴링 불필요

내장 팀의 `SendMessage`는 **수신자에게 자동으로 전달**된다(상대의 다음 turn에 사용자 메시지처럼 도착). 팀원이 idle이어도 `SendMessage`를 보내면 깨어나 처리한다. 별도의 폴링 루프나 inbox 수동 확인이 필요 없다. **"팀원이 idle"은 정상 상태이며 에러가 아니다** — 성급히 재촉하지 않는다.

### 2-2. cmux pane 분할 — 자동

사용자는 Claude Code를 `cmux claude-teams`로 실행한다. 이 환경에서 `TeamCreate`+`Agent` spawn은 **cmux pane 분할까지 자동 처리**된다. Lead가 별도 분할 명령을 호출할 필요 없다. (cmux 외부 실행 시는 §0-2 fallback)

### 2-3. 첫 팀원 pane 분할 직후 비율 재조정 (Lead 직접 호출, 1회)

**첫 팀원의 pane 분할이 cmux 에 의해 끝난 직후, Lead pane 에서 `cmux-rebalancing` 을 한 번 호출**한다. 좌 Lead / 우 팀원 컬럼 비율이 정책대로 잡힌다. 마지막 팀원 spawn 까지 기다리지 않는다.

```bash
# Lead pane 에서 직접 실행 — 좌→우: 2컬럼=60:40 / 3컬럼=40:30:30 / 4컬럼=25:25:25:25 / 5+=균등
command -v cmux-rebalancing >/dev/null 2>&1 && cmux-rebalancing
# 사용자 명시 비율 (예시): cmux-rebalancing 7:3
```

> 두 번째 이후 팀원은 같은 우측 컬럼 안에서 **하단으로 수직 분할**되므로 좌우 비율은 유지된다. **추가 호출 불필요**.

⚠️ **첫 팀원 분할 직후 본 호출 누락 시** Lead pane 가독성 저하. cmux 외부 실행 (§0-2 fallback) 시 자동 skip.

---

## 3. 데이터 경로 & work-id 규약 & 연속성 (핵심)

### 3-1. 두 영역 — 내장(휘발 가능) vs 스킬 데이터(영속)

| 영역 | 경로 | 소유 | 성격 |
|---|---|---|---|
| **Claude Code 내장** | `~/.claude/teams/<team-name>/config.json` | Claude Code | TeamCreate 자동 관리. **위치·키는 Claude Code가 정한다**(이전 불가) |
| | `~/.claude/tasks/<team-name>/` | Claude Code | Task* 자동 관리 (이전 불가) |
| **스킬 작업 데이터** | `~/.claude/plugin-data/deft/agent-teams/` | **본 skill** | **영속 작업노트.** plugin update에도 안전 |

> ⚠️ 작업 데이터를 **plugin cache**(`~/.claude/plugins/cache/.../skills/agent-teams/`)에 두면 안 된다. cache는 version-locked·자동 관리 영역이라 plugin update 시 새 version으로 교체되며 **데이터가 소실**된다. 작업 데이터는 반드시 `~/.claude/plugin-data/deft/agent-teams/` 하위에 둔다.

### 3-2. work-id — 영속 작업 키 (연속성의 핵심)

`work-id`는 **하나의 작업을 세션·팀과 무관하게 식별하는 영속 키**다. 내장 `team-name`(매 세션 새로 지어질 수 있는 휘발 키)과 **분리**한다.

- **team-name** (내장): Claude Code가 관리. 매번 새로 지어도 무방.
- **work-id** (스킬 통제): 사용자가 부여하는 영속 키. **같은 작업이면 같은 work-id 재사용** → 같은 작업노트를 물어 연속성 유지.

→ 사용자가 팀을 **몇 번을 새로 띄우든, team-name이 무엇이든, 같은 work-id만 대면** 같은 작업노트(`work.md`)를 이어받는다. 내장 `TeamCreate`의 team-name 재사용 동작에 의존하지 않으므로 견고하다. (§0-3의 "in-process teammate resume 불가" 한계를 이 설계가 보완)

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

팀원 모두 **Claude Opus (`opus`)** — Agent tool 호출 시 alias `opus`. enum 제약(`sonnet`/`opus`/`haiku`/`opus`)으로 구체 모델 ID 는 인자에 직접 지정 불가.

```text
Agent(
  team_name: "<work-id 기반 team-name>",
  name: "<role>",                    # backendDev / frontendDev / qa 등
  subagent_type: "claude",
  model: "opus",                    # ← 모든 팀원 공통
  description: "<역할 한 줄 요약>",
  prompt: "<아래 task instruction 본문>"
)
```

#### task instruction 본문

`Agent` 도구로 팀원 spawn 시 다음을 task 에 포함한다.

```text
[역할/페르소나]
- 본인 역할: <role> (예: backendDev)
- 페르소나: 본 skill 패키지의 agents/<role>.md 를 Read 하여 적용
  (skill 경로는 plugin cache 하위 — Read 가능. 데이터는 절대 거기 쓰지 말 것)
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
6. TeamCreate → Agent로 팀원 spawn (§4-3 템플릿, agents/<role>.md 페르소나)
7. 팀원: Plan 보고 → Lead 승인 → 구현 → <role>.md 갱신 → DONE
8. Lead: git diff 검증 → work.md [O] → ★ 각 단계 사용자 컨펌
9. 검증·리뷰 → 결과 보고. 팀원 idle 유지(자동 종료 X)
```

상세 운영 예시·체크리스트는 `GUIDE.md` 참조.
