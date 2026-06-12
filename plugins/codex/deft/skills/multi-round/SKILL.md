---
name: multi-round
description: '여러 AI(Codex/Claudex/Claude)가 N라운드 양방향 토론으로 합의에 도달하는 멀티턴 회의 skill. 메시지 버스(브로드캐스트 보드 + 노크) 기반 — cmux 환경에선 pane 시각화 + 자동 깨우기, 통신 본문은 MCP 버스로. 강한 트리거 — "회의"/"미팅" 단어가 포함된 요청은 본 skill 로 발동 (예: "회의 열어줘", "이 주제로 미팅"). 그 외 트리거 — "멀티 라운드", "라운드 토론", "AI끼리 토론", "합의될 때까지", "클로덱스랑 토론", "multi round", "multi-round debate". 단 "코딩 작업" 문구가 포함된 요청은 파일 작업·장기 협업이므로 Codex 자체 task 실행, 1발 비교는 multi-check 를 쓰세요.'
---

# Multi-Round Skill (Codex)

여러 AI가 **여러 라운드에 걸쳐 양방향으로 의견을 주고받는** 토론·합의 도구. **메시지 버스 (브로드캐스트 보드 + cmux 노크)** 로 동작 — 워커는 pane 의 살아있는 TUI 본체(지속 대화), 통신 본문은 버스 보드, 깨우기는 한 줄 노크.

> 본 skill은 **Codex 포팅본**입니다. Claude Code용 동일 skill은 `plugins/deft/skills/multi-round/` 에 있습니다. 기본 워크플로는 동일하지만 사용자 데이터 경로·plugin cache 경로·cmux 외부 fallback에 차이가 있습니다.

## 3-도구 멘탈 모델

| 도구 | 통신 방식 | AI 조합 | 의존성·기반 | 언제 쓰는가 |
|---|---|---|---|---|
| `multi-check` | **1회성** fan-out (응답 비교) | Codex/Claude/Gemini 동시 | CLI 직접 호출 (MCP 무관) | "한 번 물어보고 답만 비교" |
| **`multi-round`** | **지속 통신** (N라운드 양방향) | **Codex + Claudex + Claude mix** | **메시지 버스 + cmux pane** | "의견 갈려서 여러 번 주고받으며 좁히고 싶다 / 토론" |
| Codex 자체 task 실행 | 단일 세션 내 multi-turn | Codex 단독 | codex CLI 자체 | "실제 코드 분담·구현·리뷰" (Claude Code 환경이면 Agent Teams로) |

판단 키워드: **답이 하나면 multi-check, 답을 좁혀가야 하면 multi-round, 단일 세션에서 끝낼 거면 codex 자체 task.**

## 회의 모드

| 모드 | 한 줄 설명 | 종료 조건 |
|---|---|---|
| `consult` | **단발 자문** — 한 번 답변 받고 종료 | 첫 응답 1회 + DONE |
| `dialogue` (기본) | **양방향 토론** — 의견 좁혀 합의 도달까지 N라운드 | `CONSENSUS` 양쪽 일치 또는 max-round 도달 (기본 5) |
| `collaborate` | **분담 협업** — 작업을 둘로 나눠 각자 진행하고 상호 리뷰 | 양쪽 `REVIEW_PASS` 교차 |
| `debate` | **반박 토론** — 한쪽이 항복할 때까지 의견 부딪치기 | 한쪽 `CONCEDE` 또는 max-round 도달 |

### 사용자에게 회의 모드 선택 메뉴 (Phase 1)

```
회의 형태를 골라 주세요:
  1. consult    — 단발 자문
  2. dialogue   — 양방향 토론 (기본 추천)
  3. collaborate — 분담 협업
  4. debate     — 반박 토론

번호 입력 (기본 2):
```

## 신호 프로토콜

기본: `ACK / STATUS / BLOCKED / DONE`
모드별 확장: `CONSENSUS / AGREED / DISSENT / CONCEDE / REVIEW_PASS / REVIEW_FAIL / VERDICT`

신호는 **버스 메시지 본문 안의 줄**로 표기한다 (예: 응답 마지막 줄 `DONE: ...`). pane 화면 캡처가 아니라 보드 본문으로 판정.

## 메시지 버스 아키텍처 (핵심)

### 통신 모델 — 브로드캐스트 보드 + 노크

```
[Lead pane (Codex TUI)]          [Worker1 pane (claudex TUI)]   [Worker2 pane ...]
        │  bin 헬퍼 shell 호출            │  MCP 도구                    │  MCP 도구
        ▼                                ▼                              ▼
   ┌─────────────────────────────────────────────────────────────────────────┐
   │                        메시지 버스 (SESSION_DIR 공유)                     │
   │  board.jsonl        — append-only 메시지 보드 (본문 전부. 전원 공개)        │
   │  participants.json  — 참가자 레지스트리 (이름 + cmux surface)              │
   │  cursors.json       — 참가자별 마지막 읽은 메시지 id                       │
   │  knocks.json        — 노크 디바운스 상태                                  │
   └─────────────────────────────────────────────────────────────────────────┘
        post 마다: 발신자 제외 전원의 pane 에 cmux send "[bus] 메시지 확인" 노크
```

**채널 분리** — 이 구조의 본질:

| 채널 | 매체 | 싣는 것 |
|---|---|---|
| **데이터** | 버스 보드 (`board.jsonl`, MCP 도구 / bin CLI 로 접근) | 본문 전부 — 줄바꿈·마크다운·길이 제한 없음 |
| **제어** | `cmux send` 노크 | `[bus] 메시지 확인` 한 줄만 |

→ `cmux send` 의 줄바꿈 조기 제출·sanitize·capture 노이즈 문제가 **구조적으로 사라진다**. pane 은 시각화·사용자 직접 개입 전용, 통신은 보드 전용.

### 6단계 메시지 흐름

1. Lead 가 pane 분할 → 워커 spawn (각 워커 TUI 에 버스 MCP 인라인 주입) + 참가자 레지스트리 등록
2. Lead 는 수신자(워커1)를 지정해 버스에 요청 게시 (`post`)
3. 버스는 게시 즉시 발신자 제외 전원에게 노크 — 보드는 전원 공개 (브로드캐스트)
4. 워커1: 노크 수신 → `check_messages` → 수신자=본인 → 작업 수행 → 응답을 버스에 게시 (수신자=요청자)
5. 워커2: 노크 수신 → `check_messages` → 수신자≠본인 → 컨텍스트로만 검토. 기여할 내용이 있으면 수신자를 지정해 자발 발언 가능
6. 워커1 의 응답 게시가 다시 전원에게 노크 → Lead 가 깨어나 `check` → 다음 라운드. 반복.

### push→pull 변환 (구현 원리)

표준 MCP 는 서버→클라이언트 push 가 불가하므로 "전달"을 두 단계로 변환:
- **게시(pull 대상)**: 보드에 append — 참가자가 `check_messages` 로 읽음
- **깨우기(push 대용)**: 버스가 레지스트리의 surface 로 노크 한 줄 send — TUI 입력창에 주입되어 참가자 턴이 발동

**디바운스 + aged 재노크**: 참가자별로 "마지막 노크 이후 아직 check 안 함" 상태면 추가 노크 skip — 단 그 노크가 60초 이상 경과했으면 다음 post 때 재노크한다 (sent ≠ consumed 보정). 깨어난 참가자는 미독 메시지를 한 번에 모두 읽으므로 노크 1회로 누적 처리된다. 노크 실패 participant 는 레지스트리에 stale 마킹되어 Lead 보고에 표시된다.

**단일 버스**: stdio MCP 서버는 워커마다 인스턴스가 따로 뜨지만 같은 `SESSION_DIR` 파일을 보므로 논리적으로 하나의 버스. 동시 쓰기는 lock 으로 직렬화. 노크는 post 를 접수한 인스턴스가 발사.

**한 코드 두 진입점**: 같은 `multi-round-bus` 스크립트가 — 워커에겐 `mcp` 서브커맨드(stdio MCP 서버, 도구 `post_message`/`check_messages`/`list_participants`), Lead 에겐 `post`/`check`/`register` CLI(shell 직접 호출). Lead 는 MCP 등록이 전혀 필요 없다.

## 통신 우선순위 매트릭스 (Phase 2 에서 결정)

| 참가자 구성 | 1순위 | 2순위 | 3순위 |
|---|---|---|---|
| **AI mix 또는 전원 claudex/codex** (cmux 환경) | **MCP 버스** (본 아키텍처) | send/capture 폴백 (§Phase 3-B) | `multi-check` 사용 안내 후 중단 |
| **전원 Claude** (Lead 까지 Claude — Codex 측 skill 에선 드묾) | Claude Code 환경으로 안내 (팀메이트 기능은 Claude 전용) | MCP 버스 | `multi-check` 사용 안내 후 중단 |
| cmux 외부 환경 | claudex MCP conversation (§Phase 3-C — stateful 지속 대화) | `multi-check` 사용 안내 후 중단 | — |

- 하위 순위로 내려가는 조건: 상위 경로의 전제(버스 스크립트·node·cmux)가 충족되지 않을 때. 내려갈 때마다 사용자에게 사유 1줄 보고.
- **헤드리스 1-shot + 컨텍스트 재전송 방식은 금지** — 멀티라운드는 지속 대화가 본질. 그 형태가 필요한 요구면 `multi-check` 가 올바른 도구이므로 안내 후 중단한다.

## 작업 디렉토리 표준 + work-id 연계 (skill 실행 시 사용)

skill 실행 시 사용하는 데이터·세션·hooks는 `~/.codex/plugin-data/deft/multi-round/` 하위에 저장한다.

### work-id 연계 — 기본값

회의는 **기본적으로 특정 작업(work-id)에 연계**된다. work-id 는 deft 플러그인 공통 영속 키 — Claude 측 `agent-teams` 의 작업노트와 같은 키로 산출물을 상호 참조한다.

- **work-id 명명 규약 (config 읽기 순서)**:
  1. `~/.codex/plugin-data/deft/config.json` (Codex 측)
  2. 없으면 `~/.claude/plugin-data/deft/config.json` (Claude 측에서 이미 결정했으면 그 규약을 Codex 측으로 복사 후 사용)
  3. 둘 다 없으면 최초 1회 규약 메뉴 출력 (티켓번호/브랜치명/날짜-작업명/자유명/직접입력 5지선다) 후 양쪽에 저장
- **work-id 값 확정**: 사용자 입력에서 감지 (예: "IT-14610 격리 수준 토론해줘" → `IT-14610`). 감지 안 되면 1회 질문.
- **독립 토론**: 사용자가 명시적으로 "독립 토론", "work-id 없이", "그냥 토론만" 이라고 밝힌 경우에만 work-id 없이 진행.

```
~/.codex/plugin-data/deft/
├── config.json           # work-id 규약 (deft 공통)
├── CONVENTION.md         # 규약 사람용 명시
└── multi-round/
    ├── README.md             # 작업 디렉토리 용도·정책
    ├── sessions/
    │   ├── <work-id>/                  # 연계 회의 (기본)
    │   │   └── <YYYYMMDD-HHMM-tag>/
    │   │       ├── board.jsonl         # 버스 보드 = 회의록 원본 (전 메시지)
    │   │       ├── participants.json   # 참가자 레지스트리
    │   │       ├── cursors.json        # 읽음 커서
    │   │       ├── knocks.json         # 노크 디바운스 상태
    │   │       ├── summary.md          # Phase 5 종합 결과
    │   │       └── state.sh            # LEAD_SURFACE, W_*_SURFACE 등
    │   └── standalone/                 # 독립 토론 (사용자 명시 시만)
    │       └── <YYYYMMDD-HHMM-tag>/
    ├── state/                # 영구 메타 (cumulative)
    └── hooks/                # skill 동작 훅 (필요 시)
```

skill 실행 시 다음 환경 변수 설정 후 모든 경로 이걸 통해 참조:

```bash
SKILL_BASE="$HOME/.codex/plugin-data/deft/multi-round"
SESSION_TAG="$(date +%Y%m%d-%H%M)-<주제slug>"
# 연계 회의 (기본):
SESSION_DIR="$SKILL_BASE/sessions/<work-id>/$SESSION_TAG"
# 독립 토론 (사용자 명시 시만):
# SESSION_DIR="$SKILL_BASE/sessions/standalone/$SESSION_TAG"
mkdir -p "$SESSION_DIR"
```

### agent-teams 작업노트 교차 참조 (연계 회의)

work-id 가 확정되면 회의 시작 전 같은 키의 작업노트를 확인한다. agent-teams 는 Claude 전용 skill 이므로 작업노트는 Claude 측 경로에 있다:

```
~/.claude/plugin-data/deft/agent-teams/<work-id>/work.md 존재?
  ├─ 있음 → Read → 요건분석·영향도·설계결정·작업계획을 라운드 1 prompt 에
  │         컨텍스트로 inject (워커들이 작업 배경을 알고 토론 시작)
  └─ 없음 → skip (회의만 단독 선행하는 경우 — 정상)
```

회의 종료 후 합의 결과는 `summary.md` + `board.jsonl` 로 보존되며, 이후 agent-teams 가 같은 work-id 로 시작될 때 회의록을 읽어 작업노트에 반영한다.

**금지**:
- 시스템 임시 경로(`/tmp/multi-round-session/` 등) 사용 금지
- 본업 프로젝트 cwd 안에 세션 파일 생성 금지 (`.gitignore` 누락 시 commit 위험)

## Workflow

### Phase 0: Preflight (참가자 환경 확인)

```bash
# A. 참가자 CLI 확인 + cmux 환경 여부 검출
HAVE_CLAUDE=0; HAVE_CLAUDEX=0; HAVE_CODEX=0; HAVE_CMUX=0
which claude   >/dev/null 2>&1 && HAVE_CLAUDE=1
which claudex  >/dev/null 2>&1 && HAVE_CLAUDEX=1
which codex    >/dev/null 2>&1 && HAVE_CODEX=1
which cmux     >/dev/null 2>&1 && cmux identify >/dev/null 2>&1 && HAVE_CMUX=1

if [ "$HAVE_CLAUDE" -eq 0 ] && [ "$HAVE_CLAUDEX" -eq 0 ] && [ "$HAVE_CODEX" -eq 0 ]; then
  echo "ABORT: 참가자 CLI(claude / claudex / codex) 중 1개 이상 설치 필요"; exit 1
fi

# 결과별 진행 모드
if   [ "$HAVE_CODEX" -eq 1 ] && [ "$HAVE_CLAUDE" -eq 1 ]; then
  PARTICIPANTS_MODE="mix"
elif [ "$HAVE_CODEX" -eq 1 ] && [ "$HAVE_CLAUDEX" -eq 1 ]; then
  PARTICIPANTS_MODE="mix"
elif [ "$HAVE_CODEX" -eq 1 ]; then
  PARTICIPANTS_MODE="codex-only"; echo "WARN: 단일 AI 진행 — 시각 다양성 ↓"
elif [ "$HAVE_CLAUDEX" -eq 1 ]; then
  PARTICIPANTS_MODE="claudex-only"
else
  PARTICIPANTS_MODE="claude-only"
fi
echo "참가자 모드: $PARTICIPANTS_MODE"
echo "cmux 환경: $([ "$HAVE_CMUX" -eq 1 ] && echo YES || echo NO)"

# B. 버스 가용성 — node + multi-round-bus 헬퍼 (미설치 시 plugin 동봉본 자동 설치)
HAVE_BUS=0
if command -v node >/dev/null 2>&1; then
  if ! command -v multi-round-bus >/dev/null 2>&1; then
    SRC=$(ls -1 ~/.codex/plugins/cache/bluehansl-codex/deft/*/bin/multi-round-bus 2>/dev/null | tail -1)
    [ -z "$SRC" ] && SRC=$(ls -1 ~/.claude/plugins/cache/bluehansl/deft/*/bin/multi-round-bus 2>/dev/null | tail -1)
    if [ -n "$SRC" ]; then
      mkdir -p ~/.local/bin && cp "$SRC" ~/.local/bin/multi-round-bus && chmod +x ~/.local/bin/multi-round-bus
      echo "INFO: multi-round-bus 자동 설치 완료 (~/.local/bin/)"
    fi
  fi
  command -v multi-round-bus >/dev/null 2>&1 && HAVE_BUS=1
else
  echo "WARN: node 미설치 — 메시지 버스 비활성 (send/capture 폴백)"
fi
BUS_BIN=$(command -v multi-round-bus 2>/dev/null)
echo "메시지 버스: $([ "$HAVE_BUS" -eq 1 ] && echo "YES ($BUS_BIN)" || echo NO)"

# C. cmux-rebalancing 헬퍼 설치 확인 — 미설치 시 plugin 동봉본으로 자동 설치
if ! command -v cmux-rebalancing >/dev/null 2>&1; then
  SRC=$(ls -1 ~/.codex/plugins/cache/bluehansl-codex/deft/*/bin/cmux-rebalancing 2>/dev/null | tail -1)
  [ -z "$SRC" ] && SRC=$(ls -1 ~/.claude/plugins/cache/bluehansl/deft/*/bin/cmux-rebalancing 2>/dev/null | tail -1)
  if [ -n "$SRC" ]; then
    mkdir -p ~/.local/bin && cp "$SRC" ~/.local/bin/cmux-rebalancing && chmod +x ~/.local/bin/cmux-rebalancing
    echo "INFO: cmux-rebalancing 자동 설치 완료 (~/.local/bin/)"
  else
    echo "WARN: cmux-rebalancing 미설치 + plugin 동봉본 없음 — pane 비율 자동 조정 비활성"
  fi
fi
```

**핵심**:
- 참가자 CLI 1개 이상 필수
- **`HAVE_CMUX` + `HAVE_BUS` 조합이 Phase 3 통신 경로를 결정** (§통신 우선순위 매트릭스):
  - `HAVE_CMUX=1 && HAVE_BUS=1` → **Phase 3-A (메시지 버스)** — 기본
  - `HAVE_CMUX=1 && HAVE_BUS=0` → Phase 3-B (send/capture 폴백)
  - `HAVE_CMUX=0` → Phase 3-C (claudex MCP conversation) 또는 multi-check 안내
- `~/.local/bin` 이 PATH 에 없으면 `BUS_BIN` 변수로 절대경로 호출.

### Phase 1: work-id + 회의 모드 + 참가자 결정

**1-0. work-id 확정 (기본 — 독립 토론 명시 시만 skip)**:
1. config 읽기 (§작업 디렉토리 표준의 읽기 순서: Codex 측 → Claude 측 fallback → 최초 메뉴)
2. 사용자 입력에서 work-id 감지. 감지 안 되면 1회 질문: "이 회의를 연계할 작업(work-id)을 알려주세요. 독립 토론이면 '독립'이라고 답해 주세요."
3. **"독립 토론" 명시** → `sessions/standalone/` 사용
4. work-id 확정 시 → `~/.claude/plugin-data/deft/agent-teams/<work-id>/work.md` 존재하면 Read → 라운드 1 prompt 컨텍스트로 inject

**1-1. 회의 모드**:
1. 사용자 요청에서 의도 추출 ("토론해줘"→dialogue, "분담해서"→collaborate 등)
2. 명확하지 않으면 4지선다 메뉴 출력
3. 기본값: **dialogue**

**Lead 시점**: 본 skill은 Codex 세션이 트리거할 때 발동. Lead = Codex (또는 Claudex). Worker는 mix가 default. 어느 쪽이 Lead 든 같은 버스 보드를 공유 — Lead 는 CLI 진입점, 워커는 MCP 도구.

**worker CLI 우선순위 (cmux 내 pane 띄울 때)**:
- ① `claudex` 가 설치되어 있으면 **claudex 우선**
- ② 없으면 `codex`
- ③ 둘 다 없고 `claude` 만 있으면 claude
  - 단, 본 skill은 Codex 측이므로 claudex/codex 가 1순위

### Phase 2: 통신 계층 확정

Phase 0 결과 + 참가자 구성으로 §통신 우선순위 매트릭스에서 경로 1개를 확정하고 사용자에게 1줄 보고:

```
통신 계층: MCP 버스 (cmux pane 워커 + 브로드캐스트 보드 + 자동 노크)
```

- **MCP 버스 경로**: 사용자 환경 파일(`~/.codex/config.toml`) 등록이 **불필요** — 버스 MCP 는 워커 spawn 명령에 인라인 주입된다 (Phase 3-A). 영구 등록이 아니므로 환경 파일 자동 write 금지 정책과도 충돌 없음.
- 어떤 경로도 불가하면: "현재 환경에선 지속 대화형 회의가 불가합니다. 1-shot 비교가 목적이면 `multi-check` 를 사용해 주세요." 안내 후 **중단** (1-shot 재전송 방식으로 우회하지 않는다).

### Phase 3: 워커 spawn + 버스 초기화

#### 3-A. 메시지 버스 경로 (`HAVE_CMUX=1 && HAVE_BUS=1` — 기본)

**(1) Lead surface 캡처 + Lead 등록**

```bash
LEAD_SURFACE=$(cmux identify 2>/dev/null | jq -r '.caller.surface_ref' 2>/dev/null)
[ -z "$LEAD_SURFACE" ] && LEAD_SURFACE="${CMUX_SURFACE_ID:-}"
# fallback 실패 시 사용자에게 직접 surface id 요청

"$BUS_BIN" register --session "$SESSION_DIR" --name lead --kind lead --surface "$LEAD_SURFACE"
```

Lead 도 레지스트리에 등록한다 — 워커가 post 하면 **Lead pane(Codex TUI 입력창)에도 노크가 주입**되어 Lead 턴이 자동 발동된다 (폴링 불필요).

**(2) pane 분할**

첫 워커: 우측 분할
```bash
SPLIT=$(cmux new-split right --focus false 2>&1)
W1_SURFACE=$(printf '%s' "$SPLIT" | grep -oE 'surface:[0-9]+' | head -1)
```

이후 워커: 아래 분할 (직전 워커 pane 기준)
```bash
SPLIT=$(cmux new-split down --pane "<prev_pane>" --focus false 2>&1)
W2_SURFACE=$(printf '%s' "$SPLIT" | grep -oE 'surface:[0-9]+' | head -1)
```

**(3) 첫 분할 직후 비율 재조정 (1회)**

```bash
# Lead pane 에서 직접 실행 — 좌→우: 2컬럼=60:40 / 3컬럼=40:30:30 / 4컬럼=25:25:25:25 / 5+=균등
command -v cmux-rebalancing >/dev/null 2>&1 && cmux-rebalancing
```

> 두 번째 이후 워커는 같은 우측 컬럼 안에서 하단 수직 분할이므로 **좌우 비율은** 유지 — 단 순차 down 분할은 **row 높이가 1/2·1/4·1/4 로 불균등**해진다 (실측). 워커가 2명 이상이면 **모든 분할 완료 후 `cmux-rebalancing` 을 1회 더** 호출해 row 를 균등화하고, `cmux focus-pane --pane "$(cmux identify | jq -r .caller.pane_ref)"` 로 Lead focus 를 복원한다.
> ⚠️ 첫 호출 누락 시 Lead 가 2:8 처럼 축소되어 가독성 저하.

**(3.5) pane 쉘 readiness 확인 (send 유실 가드 — 필수)**

cmux 는 surface 가 **화면에 실제 렌더될 때 쉘을 기동**한다 (lazy-init). 미기동 상태에 send 하면 입력이 조용히 유실되므로, 마커 파일로 쉘 기동을 확인한 뒤에만 본 명령을 보낸다:

```bash
cmux send --surface "$W1_SURFACE" "touch $SESSION_DIR/.ready-$WORKER_NAME"
cmux send-key --surface "$W1_SURFACE" Enter
for _ in $(seq 1 15); do [ -f "$SESSION_DIR/.ready-$WORKER_NAME" ] && break; sleep 1; done
[ -f "$SESSION_DIR/.ready-$WORKER_NAME" ] \
  || echo "WARN: 워커 pane 쉘 미기동 — cmux 창이 화면에 보이는 상태여야 합니다. 사용자에게 화면 확인 요청 후 재시도"
```

**(4) 워커 TUI 기동 — 버스 MCP 인라인 주입**

claudex/codex 워커:
```bash
# ⚠️ -c mcp_servers.* 인라인은 기존 등록 서버에 **병합**된다 (교체 아님 — 실측 확인).
#    격리를 위해 사용자 config 의 기존 서버들을 enabled=false 로 명시 비활성.
ENGINE=$([ "$HAVE_CLAUDEX" -eq 1 ] && echo claudex || echo codex)
DISABLE_ARGS=""
for NAME in $("$ENGINE" mcp list --json 2>/dev/null | jq -r '.[].name' 2>/dev/null); do
  DISABLE_ARGS="$DISABLE_ARGS -c mcp_servers.$NAME.enabled=false"
done

WORKER_NAME="worker1"   # 참가자 이름 (페르소나 역할 반영 권장 — 예: backend-claudex)
# --disable tool_call_mcp_elicitation + --dangerously-bypass-approvals-and-sandbox:
#   claudex/codex 는 MCP 도구 영구 신뢰 설정이 없어 (config 후보 키 전수 무효 — 실측) 호출마다 승인 다이얼로그가 뜸.
#   bypass 가 유일한 0회 승인 경로 (인스턴스 한정 — 사용자 config 무변경). 트레이드오프: 해당 워커의 명령 실행 승인·sandbox 도 해제되므로
#   회의 워커(발언 전용) 용도에 한정할 것. 승인 최소화로 충분하면 bypass 를 빼고 첫 호출 시 "Allow for this session" 을 도구당 1회 선택 (회의당 2회).
WORKER_CMD="$ENGINE -m gpt-5.5 --disable tool_call_mcp_elicitation --dangerously-bypass-approvals-and-sandbox $DISABLE_ARGS -c 'mcp_servers.bus={command=\"$BUS_BIN\",args=[\"mcp\"],env={MULTI_ROUND_SESSION_DIR=\"$SESSION_DIR\",BUS_PARTICIPANT=\"$WORKER_NAME\"}}'"
cmux send --surface "$W1_SURFACE" "$WORKER_CMD"
cmux send-key --surface "$W1_SURFACE" Enter
```

claude CLI 워커 (config 파일 방식 — 세션 디렉토리에 생성):
```bash
cat > "$SESSION_DIR/mcp-$WORKER_NAME.json" <<EOF
{"mcpServers":{"bus":{"type":"stdio","command":"$BUS_BIN","args":["mcp"],"env":{"MULTI_ROUND_SESSION_DIR":"$SESSION_DIR","BUS_PARTICIPANT":"$WORKER_NAME"}}}}
EOF
# --allowedTools: 버스 도구 사전 허용 — 누락 시 don't ask 등 제한 모드에서 post 가 자동 거부되어
#                "수신만 되고 발신 불가" 반쪽 참가자가 됨 (실측 — 회의 데드락의 직접 원인)
# --dangerously-skip-permissions: 승인 프롬프트 0회 (claudex 의 bypass 에 대응 — 회의 워커 한정).
#   --allowedTools 는 skip 미적용 환경 폴백 겸 이중 안전으로 유지.
WORKER_CMD="claude --model claude-fable-5 --dangerously-skip-permissions --strict-mcp-config --mcp-config $SESSION_DIR/mcp-$WORKER_NAME.json --allowedTools mcp__bus__check_messages,mcp__bus__post_message,mcp__bus__list_participants"
cmux send --surface "$W1_SURFACE" "$WORKER_CMD"
cmux send-key --surface "$W1_SURFACE" Enter
```

- `BUS_PARTICIPANT` 가 워커 MCP 인스턴스에 본인 이름을 고정 — 워커는 도구 호출 시 `from`/`as` 를 생략해도 된다.
- claude CLI 워커는 `--strict-mcp-config` 가 기존 MCP 를 완전 격리한다.
- 사용자 환경 파일은 건드리지 않는다 — 모든 오버라이드는 spawn 명령 인라인/세션 파일 주입뿐 (해당 워커 인스턴스에서만 유효).
- E2E 검증: claudex 0.138 기준 버스 MCP handshake(initialize/tools-list)·check_messages·post_message·Lead 노크 수신 전체 사이클 실측 확인.

**(5) 워커 등록 + 페르소나 주입**

```bash
"$BUS_BIN" register --session "$SESSION_DIR" --name "$WORKER_NAME" --surface "$W1_SURFACE"

sleep 3  # TUI readiness
# 페르소나 prompt — 짧게 유지 (상세는 버스 보드의 첫 메시지로 전달하므로)
PERSONA_BOOT="당신은 multi-round 회의 참가자 '$WORKER_NAME' 입니다. 버스 MCP 도구(check_messages/post_message)가 연결되어 있습니다. 지금 check_messages 를 호출해 첫 안내를 읽고 지침을 따르세요. 이후 '[bus] 메시지 확인' 입력을 받으면 항상 check_messages 부터 호출하세요."
cmux send --surface "$W1_SURFACE" "$PERSONA_BOOT"
cmux send-key --surface "$W1_SURFACE" Enter
```

부트 prompt 는 한 줄로 끝낸다 — **상세 페르소나·회의 모드·신호 프로토콜·라운드 1 의제는 Lead 가 버스에 첫 메시지로 게시** (`agents/codex-participant.md` 또는 `agents/claude-participant.md` 본문 + 의제). 줄바꿈 sanitize 걱정 없이 본문 전부 전달된다.

```bash
# 첫 메시지: 페르소나 + 의제 (수신자 = 해당 워커)
"$BUS_BIN" post --session "$SESSION_DIR" --from lead --to "$WORKER_NAME" --type request --inject \
  --content "$(cat <<'EOF'
<agents/ 페르소나 본문>

## 회의 정보
- 모드: dialogue / max-round: 5
- 참가자: lead(Codex), worker1(Claudex), ...

## 라운드 1 의제
<의제 본문>
EOF
)"
```

#### 3-B. send/capture 폴백 (`HAVE_CMUX=1 && HAVE_BUS=0`)

버스 불가 시 구형 경로 — pane TUI 에 직접 prompt 주입 + 화면 캡처로 응답 수집.

- TUI 기동: `claudex -m gpt-5.5 -c mcp_servers={}` (claudex 없으면 codex, 그것도 없으면 `claude --model claude-fable-5`)
- prompt 주입 시 **줄바꿈 sanitize 필수**: `PROMPT_SAFE=$(tr '\n' ' ' < file)` 후 `cmux send` + `cmux send-key Enter` (`\n` 은 Enter 로 해석되어 조기 제출됨)
- 긴 prompt 는 `$SESSION_DIR/round<N>-<worker>.md` 저장 후 "Read <경로>" 한 줄만 send
- 응답 감지 2단: ① `capture-pane --scrollback` 에서 `DONE:` 센티넬 grep ② idle-stable 폴링 (20줄 캡처 동일 반복 시 완료 간주, 8초 간격 최대 30회)

#### 3-C. cmux 외부 환경 — claudex MCP conversation

pane 시각화 불가 환경의 지속 대화 경로 (claudex 가 codex 에 MCP 로 등록되어 있을 때 — `codex mcp list` 로 확인):

```
claudex.codex(prompt: "<페르소나 + 라운드1>", model: "gpt-5.5", developer-instructions: "<agents/codex-participant.md 본문>")
→ conversationId 저장 (sessions/<tag>/state.sh). 이후 라운드는 claudex.codex-reply(conversationId, prompt) — stateful 지속 대화 (1-shot 재전송 아님)
```

claudex MCP 미등록·미설치면 multi-check 안내 후 중단. (등록은 사용자 수동 — `~/.codex/config.toml` 에 `[mcp_servers.claudex]` / `command = "claudex"` / `args = ["mcp-server", "-c", "mcp_servers={}"]` 스니펫 안내만 출력, 자동 write 금지.)

### Phase 4: 라운드 진행 (버스 기반)

#### 4-A. 기본 루프 — 노크가 턴을 굴린다

```
Lead post(요청, to=워커) ─→ 버스가 전원 노크 ─→ 워커들 check
   ▲                                              │
   │                          수신자 워커: 작업 → post(응답, to=lead)
   │                          비수신 워커: 검토만 (필요 시 자발 post)
   │                                              │
   └── Lead pane 에 "[bus] 메시지 확인" 주입 ←── 버스가 전원 노크
       → Lead check → 종료 조건 판정 → 다음 라운드 post
```

Lead 의 라운드 동작:
```bash
# 노크 수신("[bus] 메시지 확인" 입력이 들어옴) 시 — 새 메시지 회수
"$BUS_BIN" check --session "$SESSION_DIR" --as lead

# 종료 조건 미충족 → 다음 라운드 게시 (다른 워커 의견 요약 + Lead 입장 + 질문)
# 워커 응답에 대한 후속 요청이면 --reply-to <응답 id> 로 연결 (시퀀스 그래프 — 회의록에 ← #N 표기)
"$BUS_BIN" post --session "$SESSION_DIR" --from lead --to "$NEXT_WORKER" --type request --content "..."
```

- **미응답 요청 큐**: check 출력의 `⚠ 미응답 요청` 섹션은 "본인 대상 request 중 reply_to 응답이 없는 것"을 매번 재계산해 반복 노출한다 — 워커가 읽고 빠뜨린 요청도 응답할 때까지 계속 보임 (게시·응답 시점 교차 레이스에 의한 묻힘 방지). Lead 의 check 에도 동일 적용.
```bash
```

- **폴링 불필요**: 워커 응답 post 가 Lead 를 노크로 깨운다.
- **데드락 워치독 (필수)**: Lead 는 응답을 기다리는 post 직후 워치독을 백그라운드로 심는다 — Lead 는 노크로만 깨어나므로, 워커가 막히면(권한 거부·crash·무한 대기) 아무도 post 하지 않아 회의가 조용히 정지하는 구조적 공백을 메운다:

```bash
# run_in_background (또는 `&`) 로 실행 — 종료 자체가 Lead 를 깨우는 신호
"$BUS_BIN" watch --session "$SESSION_DIR" --to "$NEXT_WORKER" --message-id <방금 post 한 id> --timeout 300
# RESPONDED → 정상 (노크와 함께 도착). STALLED → 수신자 무응답: 재노크 자동 1회 + 커서 진단 출력
#   → Lead 는 해당 pane 의 권한 모드·프롬프트 상태를 점검하고 사용자에게 보고
```
- 본문은 길이·줄바꿈 제한 없음 (보드 경유) — 3-B 의 sanitize 패턴은 버스 경로에선 불필요.
- 3-C 경로는 `claudex.codex-reply` 호출 응답이 곧 라운드 응답 (노크 불필요).

#### 4-B. 워커 측 프로토콜 (페르소나에 명시 — agents/*.md)

1. `[bus] 메시지 확인` 입력 수신 → 즉시 `check_messages`
2. 새 메시지 각각에 대해:
   - **수신자 = 본인 (또는 all)** → 작업 수행 → `post_message`(to=요청자, type=response) 로 응답. 마지막 줄 `DONE:` 센티넬
   - **수신자 ≠ 본인** → 컨텍스트로만 검토 (작업 X). 논의에 기여할 내용이 있을 때만 수신자를 지정해 자발 발언 (`type=comment`)
3. 자발 발언은 라운드당 최대 1회 권장 (노이즈 방지)

#### 4-C. 라운드 진행 — 자동 진행 (사용자 질문 X)

**기본 정책**: 회의 종료 조건은 **'스폰된 모든 AI의 합의 (CONSENSUS)' 또는 '사용자 개입'**. Lead는 사용자에게 라운드별 계속/중단 여부를 묻지 않고 **자체적으로 라운드를 계속 진행**.

| 상황 | Lead 동작 |
|---|---|
| 모든 워커 응답에 CONSENSUS 신호 일치 | 회의 종료 → Phase 5 |
| 모든 워커 응답에 CONSENSUS 없음 | 다음 라운드 prompt 자동 작성 → 진행 |
| max-round (기본 5) 도달 | 회의 종료 → 미합의 항목 명시 |
| 사용자가 라운드 중 메시지 보냄 | 즉시 그 메시지를 반영 (모드 변경, 종료, 의견 추가) |

노크 입력(`[bus] 메시지 확인`)과 사용자 실제 입력은 문구로 구분한다.

#### 4-D. 사용자 pane 직접 개입

사용자는 언제든 워커 pane 으로 전환해 직접 대화할 수 있다 (워커 = 살아있는 TUI). 사용자 직접 지시로 워커 입장이 바뀌면 워커가 다음 post 에 반영 — 버스 보드가 단일 진실 소스이므로 Lead 흐름과 충돌하지 않는다.

### Phase 5: 종합 + 정리

#### 5-A. 결과 종합 (Lead 단독)

회의록 원본은 `board.jsonl` 전체. 종합은 `$SESSION_DIR/summary.md` 로 저장 + 사용자 보고:

```markdown
## Multi-Round Results

### 회의 정보
- 모드: {consult|dialogue|collaborate|debate}
- 참가자: {Codex(gpt-5.5), Claudex(GPT-5.5), Claude(Fable 5), ...}
- 진행 라운드: {N/M}
- 종료 사유: {CONSENSUS 도달 | max-round | 사용자 조기 종료}
- 실행 경로: {3-A 버스 | 3-B send/capture | 3-C MCP conversation}
- 회의록 원본: $SESSION_DIR/board.jsonl

### Consensus (합의된 부분)
- ...

### Unresolved (라운드 종료 시 미합의)
- 각 입장 + Lead 판단

### 결론
- 최종 권장안 (Lead 종합)
```

가독 회의록 자동 생성 (Lead 종합 직후 표준 호출 — `$SESSION_DIR/transcript.md` 자동 저장):

```bash
"$BUS_BIN" transcript "$SESSION_DIR"   # 즉석 확인: -o - / 주입문 전문: --full
```

회의록 전문 확인: `"$BUS_BIN" history --session "$SESSION_DIR"` (원본 audit 은 board.jsonl, 가독 파생물은 transcript.md, Lead 종합은 summary.md — 역할 분리)

#### 5-B. 정리 (워커 + pane)

- 종료 알림 게시: `"$BUS_BIN" post --session "$SESSION_DIR" --from lead --to all --type signal --content "VERDICT: 회의 종료. 참여 감사합니다."` (워커들이 마지막 노크로 종료 인지)
- **회의 종료 후 워커 pane 을 닫는다** (`cmux close-surface --surface surface:N`) — 회의록은 board.jsonl·transcript.md 로 보존되므로 관찰 손실 없음. 닫은 뒤 `cmux-rebalancing` 1회로 레이아웃 복원.
- 버스 MCP 서버 프로세스는 각 워커 TUI 의 자식 — pane 종료 시 함께 정리됨. 잔존 확인: `pgrep -f "multi-round-bus mcp"`
- 3-C 경로의 conversation 은 별도 종료 명령 없음 (다음 사용 시 새 conversationId)

## 보안 가드 요약

| # | 가드 | 위반 시 |
|---|---|---|
| 1 | Phase 0 참가자 CLI 1개 이상 설치 확인 | abort |
| 2 | 워커 MCP 는 버스만 인라인 주입 (`mcp_servers={bus=...}` / `--strict-mcp-config`) — downstream MCP 차단 | 의도와 다른 MCP 도구 노출 |
| 3 | 사용자 환경 파일(`~/.codex/config.toml`) 자동 write 금지 — 인라인/세션 파일 주입만 | 사용자 환경 임의 변경 |
| 4 | 3-B 폴백에서만 cmux send 줄바꿈 sanitize (버스 경로는 보드 경유라 불필요) | 조기 제출 / prompt 손상 |
| 5 | claudex/claude/codex 모두 없으면 명시 에러 (silent 실패 X) | 사용자 혼란 |
| 6 | Lead surface 캡처는 `cmux identify` 의 `.caller.surface_ref` 사용 | fallback 미작동 |
| 7 | 1-shot + history 재전송 방식 금지 — 불가 환경은 multi-check 안내 후 중단 | 지속 대화 원칙 위반 |

## Error Handling

| 시나리오 | 동작 |
|---|---|
| `claudex` 미설치 + `codex` 있음 | codex로 graceful fallback |
| `codex` + `claudex` 미설치 + `claude`만 있음 | `claude-only` 모드 + WARN (팀메이트 기능은 Claude Code 환경 전용 — Claude Code 사용 안내 검토) |
| 셋 다 미설치 | abort |
| node 미설치 또는 버스 헬퍼 없음 (`HAVE_BUS=0`) | Phase 3-B (send/capture) 폴백 + 사유 1줄 보고 |
| `HAVE_CMUX=0` | Phase 3-C (claudex MCP conversation). 불가 시 multi-check 안내 후 중단 |
| 노크 실패 (cmux send 에러) | 버스가 결과에 `failed` 로 보고 — 메시지는 보드에 안전하게 남아 다음 check 때 수신. Lead 는 timeout 시 수동 check |
| 라운드 timeout (기본 300s, 노크 안 옴) | Lead 수동 `check` 1회 + 해당 워커 pane 상태 확인 → 그래도 무응답이면 skip 하고 남은 워커로 종합 |
| 한 워커 BLOCKED | 사용자에게 즉시 보고 + 결정 위임 |
| max-round 도달 | Phase 5 종합 — 미합의 항목 명시 + Lead 권장안 1개 |

## Trigger 라우팅 규칙 (강한 키워드)

| 사용자 입력에 포함된 문구 | 발동 |
|---|---|
| **"회의"** / **"미팅"** | **`multi-round` (본 skill)** — 예: "회의 열어줘", "이 주제로 미팅" |
| **"코딩 작업"** | Codex 자체 task 실행 (파일 작업·장기 협업) — "작업" 단독은 라우팅 안 함 |
| "비교" / "교차 검증" | `multi-check` |

`multi-round` 가 매칭되어선 안 되는 어휘 (단독 사용 시):
- "한번 봐줘", "같이 봐줘", "검토해줘" (1발 검토 의도)
- "워커 띄워", "둘이서 얘기해봐" (의도 불명 — 1회 확인)

## worker prompt 표준 inject (버스 첫 메시지에 포함)

```
- 응답 언어: 한국어
- 통신: 버스 MCP 도구만 사용. '[bus] 메시지 확인' 입력 수신 시 즉시 check_messages → 수신자 본인이면 작업 후 post_message 응답 / 아니면 검토만 (자발 발언은 기여할 내용 있을 때 1회)
- 응답 마지막 줄에 'DONE:' 센티넬 (버스 메시지 본문 안에)
- 회의 모드: {consult|dialogue|collaborate|debate}
- 신호 프로토콜 사용 (ACK/STATUS/BLOCKED/DONE + 모드별 확장)
```

## 참가자 페르소나

상세 페르소나는 `agents/` 하위 파일 참조:
- `agents/codex-participant.md` — claudex/codex 워커용
- `agents/claude-participant.md` — claude CLI 워커용 (선택)
