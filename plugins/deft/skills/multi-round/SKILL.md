---
name: multi-round
description: '여러 AI(Claude/Claudex/Codex)가 N라운드 양방향 토론으로 의견을 좁혀 합의에 도달하는 멀티턴 회의 skill. 메시지 버스(브로드캐스트 보드 + 노크) 기반 — cmux 환경에선 pane 시각화 + 자동 깨우기, 통신 본문은 MCP 버스로. 강한 트리거 — "회의"/"미팅" 단어가 포함된 요청은 본 skill 로 발동 (예: "회의 열어줘", "미팅 진행해", "이 주제로 회의"). 그 외 트리거 — "멀티 라운드", "라운드 토론", "왔다갔다 토론", "AI끼리 토론시켜", "수렴할 때까지 주고받아", "multi round", "multi-round debate". 단 "코딩 작업" 문구가 포함된 요청은 agent-teams, 1발 비교는 multi-check 를 쓰세요.'
---

# Multi-Round Skill

여러 AI가 **여러 라운드에 걸쳐 양방향으로 의견을 주고받는** 토론·합의 도구. **메시지 버스 (브로드캐스트 보드 + cmux 노크)** 로 동작 — 워커는 pane 의 살아있는 TUI 본체(지속 대화), 통신 본문은 버스 보드, 깨우기는 한 줄 노크.

## 3-도구 멘탈 모델 (사용자 안내용)

| 도구 | 통신 방식 | AI 조합 | 의존성·기반 | 언제 쓰는가 |
|---|---|---|---|---|
| `multi-check` | **1회성** fan-out (응답 비교) | Codex/Claude/Gemini 동시 | CLI 직접 호출 (MCP 무관) | "한 번 물어보고 답만 비교" |
| **`multi-round`** | **지속 통신** (N라운드 양방향) | **Claude + Claudex (또는 Codex/Claude mix)** | **메시지 버스 + cmux pane** | "의견 갈려서 여러 번 주고받으며 좁히고 싶다 / 토론" |
| `agent-teams` | **지속 통신** (multi-turn 협업) | **Claude끼리만** | **Claude 팀 기능 베이스** | "실제 코드 분담·구현·리뷰·작업노트" |

판단 키워드: **답이 하나면 `multi-check`, 답을 좁혀가야 하면 `multi-round`, 코드를 만져야 하면 `agent-teams`.**

> `multi-round` 의 `collaborate` 모드는 **분담 검토 / 분담 설계 / 독립 의견 작성 후 상호 리뷰** 까지. 실제 파일 수정·테스트·작업노트 가 필요한 순간은 `agent-teams` 로 승격.

### 도구 선택 기준 — 사용자 입력 예시 매핑

| 사용자 입력 예시 | 발동 도구 | 이유 |
|---|---|---|
| "GPT랑 Claude 답 비교해" / "한 번 물어보고 답 모아" | `multi-check` | 1회성 비교 의도 |
| "**멀티 라운드로** 백엔드 로직 어떻게 짤지 논의해줘" | `multi-round` | 명시적 트리거 |
| "결제 트랜잭션 격리 수준 두 AI랑 토론해서 정해" | `multi-round` | 합의 도달 의도 |
| "REST vs GraphQL — Claude랑 Codex 의견 좁혀줘" | `multi-round` | 양방향 좁히기 |
| "AI끼리 합의될 때까지 주고받아" | `multi-round` | 합의 종료 조건 명시 |
| "기능 X 만들어 — backend·frontend·qa 셋 만들어 분담" | Agent Teams | 코드 분담·파일 작업 |
| "이 PR 두 명 시각으로 사인오프받아" | Agent Teams (review-fix-signoff-loop) | 사인오프 루프 |

## 회의 모드

| 모드 | 한 줄 설명 (사용자 노출용) | 종료 조건 |
|---|---|---|
| `consult` | **단발 자문** — 한 번 답변 받고 종료. 빠른 사실 확인용 | 첫 응답 1회 + DONE |
| `dialogue` (기본) | **양방향 토론** — 의견 좁혀 합의 도달까지 N라운드 주고받기 | `CONSENSUS` 양쪽 일치 또는 max-round 도달 (기본 5) |
| `collaborate` | **분담 협업** — 작업을 둘로 나눠 각자 진행하고 상호 리뷰 사이클 | 양쪽 `REVIEW_PASS` 교차 |
| `debate` | **반박 토론** — 강한 검증, 한쪽이 항복할 때까지 의견 부딪치기 | 한쪽 `CONCEDE` 또는 max-round 도달 |

### 사용자에게 회의 모드 선택 메뉴 (Phase 1에서 노출)

회의 모드가 사용자 요청에서 명확하지 않으면 다음 메뉴를 그대로 출력하고 1~4 입력 받음:

```
회의 형태를 골라 주세요:
  1. consult    — 단발 자문. 한 번 답변 받고 종료. 빠른 사실 확인용
  2. dialogue   — 양방향 토론. 의견 좁혀 합의 도달까지 N라운드 주고받기 (기본 추천)
  3. collaborate — 분담 협업. 작업을 둘로 나눠 각자 진행하고 상호 리뷰
  4. debate     — 반박 토론. 강한 검증, 한쪽이 항복할 때까지

번호 입력 (기본 2):
```

사용자가 "1~4"를 명시하지 않더라도 입력 문맥에서 의도 추출 가능하면 그 모드로 진행 (예: "토론해줘" → dialogue, "분담해서" → collaborate).

## 신호 프로토콜

기본: `ACK / STATUS / BLOCKED / DONE`
모드별 확장: `CONSENSUS / AGREED / DISSENT / CONCEDE / REVIEW_PASS / REVIEW_FAIL / VERDICT`

신호는 **버스 메시지 본문 안의 줄**로 표기한다 (예: 응답 마지막 줄 `DONE: ...`). pane 화면 캡처가 아니라 보드 본문으로 판정.

## 메시지 버스 아키텍처 (핵심)

### 통신 모델 — 브로드캐스트 보드 + 노크

```
[Lead pane (Claude Code TUI)]      [Worker1 pane (claudex TUI)]   [Worker2 pane ...]
        │  bin 헬퍼 Bash 호출               │  MCP 도구                    │  MCP 도구
        ▼                                   ▼                              ▼
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

**한 코드 두 진입점**: 같은 `multi-round-bus` 스크립트가 — 워커에겐 `mcp` 서브커맨드(stdio MCP 서버, 도구 `post_message`/`check_messages`/`list_participants`), Lead 에겐 `post`/`check`/`register` CLI(Bash 직접 호출). Lead 는 MCP 등록이 전혀 필요 없다.

## 통신 우선순위 매트릭스 (Phase 2 에서 결정)

| 참가자 구성 | 1순위 | 2순위 | 3순위 |
|---|---|---|---|
| **AI mix 또는 전원 claudex/codex** (cmux 환경) | **MCP 버스** (본 아키텍처) | send/capture 폴백 (§Phase 3-B) | `multi-check` 사용 안내 후 중단 |
| **전원 Claude** (Lead + 워커 모두 Claude) | **팀메이트 기능** (Claude 팀 기능 — agent-teams 통신 모델) | MCP 버스 | `multi-check` 사용 안내 후 중단 |
| cmux 외부 환경 | claudex MCP conversation (§Phase 3-C — stateful 지속 대화) | `multi-check` 사용 안내 후 중단 | — |

- 하위 순위로 내려가는 조건: 상위 경로의 전제(버스 스크립트·node·cmux·팀 기능)가 충족되지 않을 때. 내려갈 때마다 사용자에게 사유 1줄 보고.
- **헤드리스 1-shot + 컨텍스트 재전송 방식은 금지** — 멀티라운드는 지속 대화가 본질. 그 형태가 필요한 요구면 `multi-check` 가 올바른 도구이므로 안내 후 중단한다.

## 작업 디렉토리 표준 + work-id 연계 (skill 실행 시 사용)

skill 실행 시 사용하는 데이터·세션·hooks는 `~/.claude/plugin-data/deft/multi-round/` 하위에 저장한다.

### work-id 연계 — 기본값

회의는 **기본적으로 특정 작업(work-id)에 연계**된다. work-id 는 `agent-teams` 와 공유하는 **deft 플러그인 공통 영속 키** — 같은 키로 두 skill 의 산출물(작업노트 ↔ 회의록)을 상호 참조한다.

- **work-id 명명 규약**: `~/.claude/plugin-data/deft/config.json` (플러그인 공통). 미설정이면 최초 1회 메뉴로 결정 — 규약 메커니즘·메뉴·변경 절차는 agent-teams SKILL §3-3 과 동일 (어느 skill 이 먼저 실행되든 한 번 정하면 양쪽 공유).
- **work-id 값 확정**: 사용자 입력에서 감지 (예: "IT-14610 격리 수준 토론해줘" → `IT-14610`). 감지 안 되면 1회 질문.
- **독립 토론**: 사용자가 명시적으로 "독립 토론", "work-id 없이", "그냥 토론만" 이라고 밝힌 경우에만 work-id 없이 진행.

```
~/.claude/plugin-data/deft/
├── config.json           # work-id 규약 (deft 공통 — agent-teams 와 공유)
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
SKILL_BASE="$HOME/.claude/plugin-data/deft/multi-round"
SESSION_TAG="$(date +%Y%m%d-%H%M)-<주제slug>"   # 예: 20260610-1430-api-design
# 연계 회의 (기본):
SESSION_DIR="$SKILL_BASE/sessions/<work-id>/$SESSION_TAG"
# 독립 토론 (사용자 명시 시만):
# SESSION_DIR="$SKILL_BASE/sessions/standalone/$SESSION_TAG"
mkdir -p "$SESSION_DIR"
```

### agent-teams 작업노트 교차 참조 (연계 회의)

work-id 가 확정되면 회의 시작 전 같은 키의 작업노트를 확인한다:

```
~/.claude/plugin-data/deft/agent-teams/<work-id>/work.md 존재?
  ├─ 있음 → Read → 요건분석·영향도·설계결정·작업계획을 라운드 1 prompt 에
  │         컨텍스트로 inject (워커들이 작업 배경을 알고 토론 시작)
  └─ 없음 → skip (회의만 단독 선행하는 경우 — 정상)
```

회의 종료(Phase 5) 후 합의 결과는 `summary.md` + `board.jsonl` 로 보존된다. 이후 `agent-teams` 가 같은 work-id 로 시작/재개될 때 이 회의록을 읽어 work.md `## 설계 결정` 에 반영한다 (agent-teams SKILL §3-5).

**금지**:
- 시스템 임시 경로(`/tmp/multi-round-session/` 등) 사용 금지 (재부팅 시 손실, 다른 skill과 경계 모호)
- 본업 프로젝트 cwd 안에 세션 파일 생성 금지 (`.gitignore` 누락 시 commit 위험)

## Workflow

### Phase 0: Preflight (참가자 환경 확인)

회의 시작 전 다음을 확인:

```bash
# A. 참가자 CLI 확인 — claude / claudex / codex
HAVE_CLAUDE=0
HAVE_CLAUDEX=0
HAVE_CODEX=0
which claude   >/dev/null 2>&1 && HAVE_CLAUDE=1
which claudex  >/dev/null 2>&1 && HAVE_CLAUDEX=1
which codex    >/dev/null 2>&1 && HAVE_CODEX=1

if [ "$HAVE_CLAUDE" -eq 0 ] && [ "$HAVE_CLAUDEX" -eq 0 ] && [ "$HAVE_CODEX" -eq 0 ]; then
  echo "ABORT: 참가자 CLI(claude / claudex / codex) 중 1개 이상 설치 필요"; exit 1
fi

# 결과별 진행 모드
if   [ "$HAVE_CLAUDE" -eq 1 ] && [ "$HAVE_CLAUDEX" -eq 1 ]; then
  PARTICIPANTS_MODE="mix"      # default — claude + claudex 양쪽 mix
elif [ "$HAVE_CLAUDE" -eq 1 ] && [ "$HAVE_CODEX" -eq 1 ]; then
  PARTICIPANTS_MODE="mix"      # claude + codex mix (claudex 없어도 codex로 대체)
elif [ "$HAVE_CLAUDE" -eq 1 ]; then
  PARTICIPANTS_MODE="claude-only";  echo "WARN: claudex/codex 미설치 — claude만으로 진행"
elif [ "$HAVE_CLAUDEX" -eq 1 ]; then
  PARTICIPANTS_MODE="claudex-only"; echo "WARN: claude 미설치 — claudex만으로 진행"
else
  PARTICIPANTS_MODE="codex-only";   echo "WARN: claude/claudex 미설치 — real codex만으로 진행"
fi
echo "참가자 모드: $PARTICIPANTS_MODE"

# B. cmux 환경 검출 — spawn 정책 분기
HAVE_CMUX=0
which cmux >/dev/null 2>&1 && cmux identify >/dev/null 2>&1 && HAVE_CMUX=1
echo "cmux 환경: $([ "$HAVE_CMUX" -eq 1 ] && echo YES || echo NO)"

# C. 버스 가용성 — node + multi-round-bus 헬퍼 (미설치 시 plugin 동봉본 자동 설치)
HAVE_BUS=0
if command -v node >/dev/null 2>&1; then
  if ! command -v multi-round-bus >/dev/null 2>&1; then
    SRC=$(ls -1 ~/.claude/plugins/cache/bluehansl/deft/*/bin/multi-round-bus 2>/dev/null | tail -1)
    [ -z "$SRC" ] && SRC=$(ls -1 ~/.codex/plugins/cache/bluehansl/deft/*/bin/multi-round-bus 2>/dev/null | tail -1)
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

# D. cmux-rebalancing 헬퍼 설치 확인 — 미설치 시 plugin 동봉본으로 자동 설치
if ! command -v cmux-rebalancing >/dev/null 2>&1; then
  SRC=$(ls -1 ~/.claude/plugins/cache/bluehansl/deft/*/bin/cmux-rebalancing 2>/dev/null | tail -1)
  [ -z "$SRC" ] && SRC=$(ls -1 ~/.codex/plugins/cache/bluehansl/deft/*/bin/cmux-rebalancing 2>/dev/null | tail -1)
  if [ -n "$SRC" ]; then
    mkdir -p ~/.local/bin && cp "$SRC" ~/.local/bin/cmux-rebalancing && chmod +x ~/.local/bin/cmux-rebalancing
    echo "INFO: cmux-rebalancing 자동 설치 완료 (~/.local/bin/)"
  else
    echo "WARN: cmux-rebalancing 미설치 + plugin 동봉본 없음 — pane 비율 자동 조정 비활성"
  fi
fi
```

**핵심**:
- **참가자 CLI**: 어느 쪽이든 Lead 가 될 수 있음. mix 가 default. 한쪽만 있으면 그쪽만으로 진행 (abort 안 함. WARN 후 계속).
- **`HAVE_CMUX` + `HAVE_BUS` 조합이 Phase 3 통신 경로를 결정** (§통신 우선순위 매트릭스):
  - `HAVE_CMUX=1 && HAVE_BUS=1` → **Phase 3-A (메시지 버스)** — 기본
  - `HAVE_CMUX=1 && HAVE_BUS=0` → Phase 3-B (send/capture 폴백)
  - `HAVE_CMUX=0` → Phase 3-C (claudex MCP conversation) 또는 multi-check 안내
- `~/.local/bin` 이 PATH 에 없으면 `BUS_BIN` 변수로 절대경로 호출.

### Phase 1: work-id + 회의 모드 + 참가자 결정

#### 1-0. work-id 확정 (기본 — 독립 토론 명시 시만 skip)

1. `~/.claude/plugin-data/deft/config.json` 읽기. 미설정이면 최초 1회 규약 메뉴 출력 (agent-teams SKILL §3-3 메커니즘 동일) 후 저장
2. 사용자 입력에서 work-id 감지 (규약 형식 매칭 — 예: 티켓 번호 패턴). 감지 안 되면 1회 질문: "이 회의를 연계할 작업(work-id)을 알려주세요. 독립 토론이면 '독립'이라고 답해 주세요."
3. **사용자가 "독립 토론" 명시** → work-id 없이 `sessions/standalone/` 사용
4. work-id 확정 시 → `agent-teams/<work-id>/work.md` 존재하면 Read → 라운드 1 prompt 컨텍스트로 inject (§작업 디렉토리 표준 참조)

#### 1-1. 회의 모드

1. 사용자 요청에서 의도 추출 — "토론해줘", "분담해서", "합의될 때까지" 등 키워드 매핑
2. 의도 명확하지 않으면 **위 회의 모드 선택 메뉴 (4지선다)** 그대로 출력 + 사용자 입력 1~4 받음
3. 기본값(사용자가 입력 없이 진행 요청): **dialogue**

#### 1-2. 참가자 (Phase 0의 `PARTICIPANTS_MODE` 따라)

- **`mix` (default)**: Lead가 Claude면 worker는 Claudex 우선 / Lead가 Claudex면 worker는 Claude. **양쪽 시각 mix가 multi-round의 핵심 가치**
- **`claude-only`**: Lead + 워커 전원 Claude → **§통신 우선순위 매트릭스의 "전원 Claude" 행 적용** — 팀메이트 기능 1순위 (agent-teams 의 통신 모델 차용. 단 본 skill 의 회의 모드·신호 프로토콜·라운드 정책은 그대로 적용)
- **`claudex-only` / `codex-only`**: 설치된 한쪽만으로 N명 진행 (시각 다양성은 감소하지만 회의 자체는 가능)

#### 1-3. Lead는 누구인가 (양방향 가능)

- **본 skill은 Claude / Claudex 양쪽에서 시작 가능**.
- Claude Code에서 `/multi-round` 또는 트리거로 발동 → Lead = Claude
- Claudex CLI에서 동일 skill 발동 → Lead = Claudex
- **어느 쪽이 Lead든 동작 동일** — Lead 는 버스의 bin CLI 진입점을 Bash 로 호출하고, 워커는 MCP 도구로 같은 버스에 접근.

#### 1-4. 권장 조합 (참가자 수)

- **2명 dialogue (기본)**: Lead + worker 1명
- **3명**: Lead + worker 2명 (양쪽 mix 시 시각 다양성↑). **워커 2명부터 버스의 진가** — 수신자 아닌 워커도 보드를 보며 자발 발언 가능 (회의실 메타포)
- **4명+**: 인지·진행 부담 ↑. cmux pane 분할 한계 고려. 본질이 *토론*이라 4명 이상은 권장 X (그 경우 Agent Teams 전환 검토)

### Phase 2: 통신 계층 확정

Phase 0 결과 + 참가자 구성으로 §통신 우선순위 매트릭스에서 경로 1개를 확정하고 사용자에게 1줄 보고:

```
통신 계층: MCP 버스 (cmux pane 워커 + 브로드캐스트 보드 + 자동 노크)
```

- **MCP 버스 경로**: 사용자 환경 파일(`~/.claude/settings.json`, `~/.codex/config.toml`) 등록이 **불필요** — 버스 MCP 는 워커 spawn 명령에 인라인 주입된다 (Phase 3-A). 영구 등록이 아니므로 환경 파일 자동 write 금지 정책과도 충돌 없음.
- **전원 Claude 구성**: 팀메이트 기능 1순위. 팀 기능 불가 시 MCP 버스로 강등 (claude CLI 워커도 인라인 `--mcp-config` 로 버스 주입 가능).
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

Lead 도 레지스트리에 등록한다 — 워커가 post 하면 **Lead pane(Claude Code 입력창)에도 노크가 주입**되어 Lead 턴이 자동 발동된다 (폴링 불필요).

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

> 두 번째 이후 워커는 같은 우측 컬럼 안에서 하단 수직 분할이므로 좌우 비율 유지 — 추가 호출 불필요.
> ⚠️ 누락 시 Lead 가 2:8 처럼 축소되어 가독성 저하.

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
# --disable tool_call_mcp_elicitation: MCP 도구 호출마다 승인 프롬프트가 뜨는 것을 방지 (이 워커 인스턴스 한정)
WORKER_CMD="$ENGINE -m gpt-5.5 --disable tool_call_mcp_elicitation $DISABLE_ARGS -c 'mcp_servers.bus={command=\"$BUS_BIN\",args=[\"mcp\"],env={MULTI_ROUND_SESSION_DIR=\"$SESSION_DIR\",BUS_PARTICIPANT=\"$WORKER_NAME\"}}'"
cmux send --surface "$W1_SURFACE" "$WORKER_CMD"
cmux send-key --surface "$W1_SURFACE" Enter
```

claude CLI 워커 (config 파일 방식 — `--strict-mcp-config` 가 기존 MCP 완전 격리):
```bash
cat > "$SESSION_DIR/mcp-$WORKER_NAME.json" <<EOF
{"mcpServers":{"bus":{"type":"stdio","command":"$BUS_BIN","args":["mcp"],"env":{"MULTI_ROUND_SESSION_DIR":"$SESSION_DIR","BUS_PARTICIPANT":"$WORKER_NAME"}}}}
EOF
# --allowedTools: 버스 도구 사전 허용 — 누락 시 don't ask 등 제한 모드에서 post 가 자동 거부되어
#                "수신만 되고 발신 불가" 반쪽 참가자가 됨 (실측 — 회의 데드락의 직접 원인)
WORKER_CMD="claude --model claude-fable-5 --strict-mcp-config --mcp-config $SESSION_DIR/mcp-$WORKER_NAME.json --allowedTools mcp__bus__check_messages,mcp__bus__post_message,mcp__bus__list_participants"
cmux send --surface "$W1_SURFACE" "$WORKER_CMD"
cmux send-key --surface "$W1_SURFACE" Enter
```

- `BUS_PARTICIPANT` 가 워커 MCP 인스턴스에 본인 이름을 고정 — 워커는 도구 호출 시 `from`/`as` 를 생략해도 된다.
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
"$BUS_BIN" post --session "$SESSION_DIR" --from lead --to "$WORKER_NAME" --type request \
  --content "$(cat <<'EOF'
<agents/ 페르소나 본문>

## 회의 정보
- 모드: dialogue / max-round: 5
- 참가자: lead(Claude), worker1(Claudex), ...

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

pane 시각화 불가 환경의 지속 대화 경로 (claudex 가 Claude Code 에 MCP 로 등록되어 있을 때):

```
mcp__claudex__codex(prompt: "<페르소나 + 라운드1>", model: "gpt-5.5", developer-instructions: "<agents/codex-participant.md 본문>")
→ conversationId 저장. 이후 라운드는 mcp__claudex__codex-reply(conversationId, prompt) — stateful 지속 대화 (1-shot 재전송 아님)
```

claudex MCP 미등록·미설치면 multi-check 안내 후 중단.

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
"$BUS_BIN" post --session "$SESSION_DIR" --from lead --to "$NEXT_WORKER" --type request --content "..."
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
| 모든 워커 응답에 CONSENSUS 신호 일치 | 회의 종료 → Phase 5 종합 |
| 모든 워커 응답에 CONSENSUS 없음 (DISSENT 등 이견 잔존) | 다음 라운드 prompt 자동 작성 → 진행 |
| max-round (기본 5) 도달 | 회의 종료 → 미합의 항목 명시한 채 Phase 5 종합 |
| 사용자가 라운드 중 메시지 보냄 | 즉시 그 메시지를 반영 (모드 변경, 종료 요청, 의견 추가 등) |

**전제**: Lead는 회의 수행 중에도 사용자 입력을 받을 수 있어야 한다. 사용자가 자발적으로 개입하면 즉시 처리. 노크 입력(`[bus] 메시지 확인`)과 사용자 실제 입력은 문구로 구분한다.

**사용자 명시적 변경만 종료 조건 교체**:
- "max-round 10으로 늘려" → 그 시점부터 max-round=10
- "한쪽이 항복할 때까지" → 모드를 debate로 변경
- "지금 종료해줘" → 즉시 Phase 5 종합

별도 명시 없으면 위 기본 정책 유지.

#### 4-D. 사용자 pane 직접 개입

사용자는 언제든 워커 pane 으로 전환해 직접 대화할 수 있다 (워커 = 살아있는 TUI). 사용자 직접 지시로 워커 입장이 바뀌면 워커가 다음 post 에 반영 — 버스 보드가 단일 진실 소스이므로 Lead 흐름과 충돌하지 않는다.

### Phase 5: 종합 + 정리

#### 5-A. 결과 종합 (Lead 단독)

회의록 원본은 `board.jsonl` 전체. 종합은 `$SESSION_DIR/summary.md` 로 저장 + 사용자 보고:

```markdown
## Multi-Round Results

### 회의 정보
- 모드: {consult|dialogue|collaborate|debate}
- 참가자: {Claudex(GPT-5.5), Claude(Fable 5), ...}
- 진행 라운드: {N/M}
- 종료 사유: {CONSENSUS 도달 | max-round | 사용자 조기 종료}
- 회의록 원본: $SESSION_DIR/board.jsonl

### Consensus (합의된 부분)
- ...

### Unresolved (라운드 종료 시 미합의)
- 각 입장 + Lead 판단

### 결론
- 최종 권장안 (Lead 종합)
```

회의록 전문 확인: `"$BUS_BIN" history --session "$SESSION_DIR"`

#### 5-B. 정리 (워커 + pane)

- 종료 알림 게시: `"$BUS_BIN" post --session "$SESSION_DIR" --from lead --to all --type signal --content "VERDICT: 회의 종료. 참여 감사합니다."` (워커들이 마지막 노크로 종료 인지)
- 워커 pane 은 자동 close 안 함 (관찰 보존). 사용자에게 "워커 pane 닫을까요?" 컨펌 후 `cmux close-surface --surface surface:N`
- 버스 MCP 서버 프로세스는 각 워커 TUI 의 자식 — pane 종료 시 함께 정리됨. 잔존 확인: `pgrep -f "multi-round-bus mcp"`
- 3-C 경로의 conversation 은 별도 종료 명령 없음 (다음 사용 시 새 conversationId)

## 보안 가드 요약

| # | 가드 | 위반 시 |
|---|---|---|
| 1 | Phase 0 참가자 CLI 1개 이상 설치 확인 (`claude` / `claudex` / `codex` 중) | abort |
| 2 | 워커 MCP 는 버스만 인라인 주입 (`mcp_servers={bus=...}` / `--strict-mcp-config`) — downstream MCP 차단 | 의도와 다른 MCP 도구 노출 |
| 3 | 사용자 환경 파일(`settings.json`, `config.toml`) 자동 write 금지 — 인라인/세션 파일 주입만 | 사용자 환경 임의 변경 |
| 4 | 3-B 폴백에서만 cmux send 줄바꿈 sanitize (버스 경로는 보드 경유라 불필요) | 조기 제출 / prompt 손상 |
| 5 | claudex/claude/codex 모두 없으면 명시 에러 (silent 실패 X) | 사용자 혼란 |
| 6 | Lead surface 캡처는 `cmux identify` 의 `.caller.surface_ref` 사용 | fallback 미작동 |
| 7 | 1-shot + history 재전송 방식 금지 — 불가 환경은 multi-check 안내 후 중단 | 지속 대화 원칙 위반 |

## Error Handling

| 시나리오 | 동작 |
|---|---|
| `claudex` 미설치 + `codex` 있음 | real codex로 graceful fallback + WARN 로그 |
| `claudex` + `codex` 미설치 + `claude`만 있음 | `claude-only` 모드 — 팀메이트 기능 1순위, 불가 시 버스 (claude CLI 워커) |
| `claude` 미설치 + `claudex` 또는 `codex` 있음 | 그 쪽만으로 진행 + WARN |
| 셋 다 미설치 | abort + "참가자 CLI 1개 이상 설치 필요" 보고 |
| node 미설치 또는 버스 헬퍼 없음 (`HAVE_BUS=0`) | Phase 3-B (send/capture) 폴백 + 사유 1줄 보고 |
| `HAVE_CMUX=0` | Phase 3-C (claudex MCP conversation). 불가 시 multi-check 안내 후 중단 |
| 노크 실패 (cmux send 에러) | 버스가 결과에 `failed` 로 보고 — 메시지는 보드에 안전하게 남아 다음 check 때 수신. Lead 는 timeout 시 수동 check |
| 라운드 timeout (기본 300s, 노크 안 옴) | Lead 수동 `check` 1회 + 해당 워커 pane 상태 확인 → 그래도 무응답이면 skip 하고 남은 워커로 종합 |
| 한 워커 BLOCKED | 사용자에게 즉시 보고 + 결정 위임 |
| max-round 도달 (기본 5) | Phase 5 종합 — 미합의 항목 명시 + Lead 권장안 1개 제시 |

## Trigger 라우팅 규칙 (강한 키워드)

| 사용자 입력에 포함된 문구 | 발동 skill |
|---|---|
| **"회의"** / **"미팅"** | **`multi-round` (본 skill)** — 예: "회의 열어줘", "이 주제로 미팅" |
| **"코딩 작업"** | **`agent-teams`** — 예: "IT-14610 코딩 작업 시작", "이거 코딩 작업해줘" |
| "비교" / "교차 검증" | `multi-check` |

> "작업" 단독은 일상어라 라우팅 안 함 — **"코딩 작업"** 조합일 때만. 회의·미팅과 코딩 작업이 **함께** 나오면 (예: "코딩 작업 시작 전에 회의부터") 문맥상 먼저 요구되는 쪽을 발동하고, 이어지는 단계는 work-id 로 연계한다.

`multi-round` 가 매칭되어선 안 되는 어휘 (단독 사용 시):
- "한번 봐줘", "같이 봐줘", "검토해줘" (1발 검토 의도 — multi-check 또는 단독)
- "워커 띄워", "둘이서 얘기해봐" (의도 불명 — 1회 확인)

## 워커 prompt 표준 inject (버스 첫 메시지에 포함)

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
