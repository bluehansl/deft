---
name: multi-round
description: 여러 AI(Claude/Claudex/Codex)가 N라운드 양방향 토론으로 의견을 좁혀 합의에 도달하는 멀티턴 회의 skill. cmux 환경에선 pane 시각화로, cmux 외부에선 MCP 경유로 동작. 강한 트리거 — "회의"/"미팅" 단어가 포함된 요청은 본 skill 로 발동 (예: "회의 열어줘", "미팅 진행해", "이 주제로 회의"). 그 외 트리거 — "멀티 라운드", "라운드 토론", "왔다갔다 토론", "AI끼리 토론시켜", "수렴할 때까지 주고받아", "multi round", "multi-round debate". 단 "코딩 작업" 문구가 포함된 요청은 agent-teams, 1발 비교는 multi-check 를 쓰세요.
---

# Multi-Round Skill

여러 AI가 **여러 라운드에 걸쳐 양방향으로 의견을 주고받는** 토론·합의 도구. **`claudex` 의 내장 `mcp-server` + cmux pane 제어** 조합으로 동작.

## 3-도구 멘탈 모델 (사용자 안내용)

| 도구 | 통신 방식 | AI 조합 | 의존성·기반 | 언제 쓰는가 |
|---|---|---|---|---|
| `multi-check` | **1회성** fan-out (응답 비교) | Codex/Claude/Gemini 동시 | CLI 직접 호출 (MCP 무관) | "한 번 물어보고 답만 비교" |
| **`multi-round`** | **지속 통신** (N라운드 양방향) | **Claude + Claudex (또는 Codex/Claude mix)** | **cmux 환경: pane 시각화 / cmux 외부: MCP 또는 codex 내부 fallback** | "의견 갈려서 여러 번 주고받으며 좁히고 싶다 / 토론" |
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
    │   │       ├── round1-<worker>.md
    │   │       ├── ...
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

회의 종료(Phase 5) 후 합의 결과는 transcript 로 보존된다. 이후 `agent-teams` 가 같은 work-id 로 시작/재개될 때 이 회의록을 읽어 work.md `## 설계 결정` 에 반영한다 (agent-teams SKILL §3-5).

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

# C. cmux-rebalancing 헬퍼 설치 확인 — 미설치 시 plugin 동봉본으로 자동 설치
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
- **`HAVE_CMUX` 값이 Phase 3 spawn 경로를 결정**한다:
  - `HAVE_CMUX=1` → **Phase 3-B (cmux pane)** 가 기본 — 사용자가 워커 활동을 시각으로 모니터링
  - `HAVE_CMUX=0` → Phase 3-A (MCP) 또는 Phase 3-C (codex 내부 fallback)
- **`cmux-rebalancing` 헬퍼**: cmux 환경에서 워커 spawn 후 pane 비율을 정책대로 재조정한다. PATH 상에 없으면 plugin 동봉본을 `~/.local/bin/` 로 자동 설치. Phase 3 spawn 종료 시점에 자동 호출 (§Phase 3 마지막).

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
- **`claude-only` / `claudex-only` / `codex-only`**: 설치된 한쪽만으로 N명 진행 (시각 다양성은 감소하지만 회의 자체는 가능)

#### 1-3. Lead는 누구인가 (양방향 가능)

- **본 skill은 Claude / Claudex 양쪽에서 시작 가능**.
- Claude Code에서 `/multi-round` 또는 트리거로 발동 → Lead = Claude
- Claudex CLI에서 동일 skill 발동 → Lead = Claudex
- **어느 쪽이 Lead든 동작 동일** (Phase 2의 MCP server를 매개로 통신)

#### 1-4. 권장 조합 (참가자 수)

- **2명 dialogue (기본)**: Lead + worker 1명
- **3명**: Lead + worker 2명 (양쪽 mix 시 시각 다양성↑)
- **4명+**: 인지·진행 부담 ↑. cmux pane 분할 한계 고려. 본질이 *토론*이라 4명 이상은 권장 X (그 경우 Agent Teams 전환 검토)

### Phase 2: MCP 서버 경유 — 양방향 통신 컨셉

#### 2-1. multi-round 통신 구조 (핵심)

```
[Lead (Claude 또는 Claudex)]
            │
            ▼
   ┌──────────────────┐
   │   claudex가 띄운  │
   │   mcp-server      │  ← 단일 MCP 서버. Lead가 어느 쪽이든 같은 서버 사용
   │   (stdio)         │
   └──────────────────┘
        │         │
        ▼         ▼
   [Worker A] [Worker B]
   (Claude 또는 Claudex 인스턴스 — mix가 default)
```

- **MCP server는 `claudex` 가 띄움** (`claudex mcp-server`).
- Lead가 **Claude 이든 Claudex 이든 동일한 MCP server를 통해 통신**.
- claudex 미설치 환경(`HAVE_CLAUDEX=0`)에서는 3-A 경로 사용 불가 — Phase 3-B/3-C 로만 동작.

#### 2-2. MCP 서버 등록 (사용자 환경 파일 — 자동 write 금지)

`~/.claude/settings.json` 은 사용자 환경 파일이므로 **자동 수정 금지**. 미등록 시 다음 스니펫을 출력하고 수동 등록을 요청한다.

```json
// ~/.claude/settings.json — mcpServers 키 추가
{
  "mcpServers": {
    "claudex": {
      "command": "claudex",
      "args": [
        "mcp-server",
        "-c", "mcp_servers={}"
      ]
    }
  }
}
```

또는 동등한 CLI 명령:

```bash
claude mcp add-json --scope user claudex '{"type":"stdio","command":"claudex","args":["mcp-server","-c","mcp_servers={}"]}'
```

**핵심**: `-c mcp_servers={}` 인자는 worker conversation 에 downstream MCP 가 함께 로드되지 않도록 **MCP 컨텍스트를 격리**한다. 누락 시 worker 가 의도와 다른 MCP 를 도구로 인식할 수 있음.

등록 확인:
```bash
claude mcp get claudex >/dev/null 2>&1 \
  || echo "WARN: claudex MCP 미등록 — settings.json 확인 + Claude Code 재시작 필요"
```

미등록 시 fallback 분기:
- `HAVE_CMUX=1` → Phase 3-B (cmux pane, 사용자 정책 기본 경로)
- `HAVE_CMUX=0` → 사용자에게 등록 안내 후 작업 중단 (3-C는 codex 환경 전용)

#### 2-3. Lead가 Claudex일 때

Claudex 자체가 MCP server 를 직접 띄움 (`claudex mcp-server`). Lead 의 conversation 이 그 server 에 직접 연결 → 외부 등록 불필요. 단 Phase 3-A 로 worker spawn 시 동일 패턴 적용.

### Phase 3: 워커 spawn — 환경별 경로

자동 분기 (사용자 정책 반영):

| 환경 | 권장 경로 |
|---|---|
| `HAVE_CMUX=1` (cmux 안) | **Phase 3-B (pane)** — 시각화 default. MCP 등록 여부 무관 |
| `HAVE_CMUX=0` + MCP 등록 | **Phase 3-A (MCP)** |
| `HAVE_CMUX=0` + MCP 미등록 | Phase 3-C (codex 자체 fallback) 또는 사용자 안내 후 중단 |

#### 3-A. claudex MCP 경유 (cmux 외부 stateful 경로)

각 워커별로 conversation 시작:
```
mcp__claudex__codex(
  prompt: "<페르소나 + 라운드 1 prompt>",
  model: "gpt-5.5",                  # claudex/codex worker 표준 모델
  cwd: "<원하는 cwd>",
  developer-instructions: "<페르소나 골격 — agents/codex-participant.md 본문>"
)
→ 반환된 conversationId를 워커별로 저장 ({backendDev-claudex: conv-uuid1, ...})
```

이후 라운드는 `codex-reply`로:
```
mcp__claudex__codex-reply(
  conversationId: "<해당 워커 conv id>",
  prompt: "<다음 라운드 prompt>"
)
```

특성: cmux 외부 환경 또는 사용자가 시각화 생략을 명시한 경우의 stateful MCP 경로. 자동 lifecycle (Claude Code 자식 프로세스).

#### 3-B. cmux pane + claudex TUI (cmux 환경 기본 경로)

`HAVE_CMUX=1` 일 때 기본 경로. 사용자가 워커 활동을 우측·아래 pane 으로 시각 모니터링하고 직접 개입 가능.

Lead surface 캡처:
```bash
LEAD_SURFACE=$(cmux identify 2>/dev/null | jq -r '.caller.surface_ref' 2>/dev/null)
[ -z "$LEAD_SURFACE" ] && LEAD_SURFACE="${CMUX_SURFACE_ID:-}"
# fallback 실패 시 사용자에게 직접 surface id 요청
```

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

워커 pane 에 TUI 기동 + 초기 prompt — **`claudex` 우선, 없으면 `codex`**. 모델 버전 명시:
```bash
# 워커 모델 표준 — claudex/codex: GPT-5.5 / claude: Claude Fable 5 (claude-fable-5)
if [ "$HAVE_CLAUDEX" -eq 1 ]; then
  WORKER_CMD="claudex -m gpt-5.5 -c mcp_servers={}"
elif [ "$HAVE_CODEX" -eq 1 ]; then
  WORKER_CMD="codex -m gpt-5.5 -c mcp_servers={}"
else
  WORKER_CMD="claude --model claude-fable-5"   # claude-only 환경
fi
cmux send --surface "$W1_SURFACE" "$WORKER_CMD"
cmux send-key --surface "$W1_SURFACE" Enter
sleep 3  # TUI readiness 확인 (capture-pane 으로 프롬프트 박스 출현 감지 권장)
```

#### 3-B-fin. 첫 pane 분할 직후 비율 재조정 (Lead 직접 호출, 1회)

**첫 워커의 우측 분할(`cmux new-split right`)이 끝난 직후 Lead pane 에서 `cmux-rebalancing` 을 한 번 호출**한다. 좌우 컬럼 비율이 바로 정책대로 잡힌다.

```bash
# Lead pane 에서 직접 실행 — 좌→우: 2컬럼=60:40 / 3컬럼=40:30:30 / 4컬럼=25:25:25:25 / 5+=균등
command -v cmux-rebalancing >/dev/null 2>&1 && cmux-rebalancing
# 사용자 명시 비율 (예시): cmux-rebalancing 7:3
```

> 두 번째 이후 워커는 같은 우측 컬럼 안에서 **하단으로 수직 분할**(`cmux new-split down`)되므로 좌우 비율은 유지된다. **추가 호출 불필요** — TUI 기동·prompt 전달 진행 중에도 비율은 그대로.

⚠️ **첫 분할 직후 본 호출 누락 시** Lead 가 2:8 처럼 축소되어 사용자 가독성 저하.

### Phase 4: 라운드 진행 (양방향 통신)

#### 4-A. prompt 주입 — 줄바꿈 sanitize 필수

⚠️ **`cmux send`의 `\n`은 Enter로 해석되어 다중 라인 prompt가 조기 제출**. 다음 패턴 강제:

```bash
# WRONG — 줄바꿈마다 조기 제출
cmux send --surface "$W1_SURFACE" "$(cat $SESSION_DIR/round1-claude.md)"

# RIGHT — 줄바꿈 공백 치환, 제출은 send-key 단독
PROMPT_SAFE=$(tr '\n' ' ' < "$SESSION_DIR/round1-claude.md")
cmux send --surface "$W1_SURFACE" "$PROMPT_SAFE"
cmux send-key --surface "$W1_SURFACE" Enter
```

긴 prompt는 `$SESSION_DIR/round<N>-<worker>.md` 파일로 저장 후 워커에 "Read $SESSION_DIR/round<N>-<worker>.md" 안내 — 본문 전송 자체를 줄여 안전성·재현성 확보.

#### 4-B. 응답 완료 감지 — 2단 폴링

(1) **DONE 센티넬 grep** (1차):
```bash
# 워커 페르소나에 "응답 마지막 줄에 'DONE:'으로 시작" 강제 (agents/*.md)
cmux capture-pane --surface "$W1_SURFACE" --scrollback --lines 200 \
  | grep -qE '^DONE:' && echo "WORKER_DONE"
```

(2) **idle-stable 폴링** (2차, 보조):
```bash
PREV=""
for _ in $(seq 1 30); do
  CUR=$(cmux capture-pane --surface "$W1_SURFACE" --lines 20)
  if [ "$CUR" = "$PREV" ]; then
    echo "IDLE_STABLE"; break
  fi
  PREV="$CUR"; sleep 8
done
```

⚠️ claudex TUI는 ANSI/스피너로 diff 노이즈 발생 → **센티넬이 1차, idle-stable은 2차 보조**.

#### 4-C. 라운드 진행 — 자동 진행 (사용자 질문 X)

**기본 정책**: 회의 종료 조건은 **'스폰된 모든 AI의 합의 (CONSENSUS)' 또는 '사용자 개입'**. Lead는 사용자에게 라운드별 계속/중단 여부를 묻지 않고 **자체적으로 라운드를 계속 진행**.

| 상황 | Lead 동작 |
|---|---|
| 모든 워커 응답에 CONSENSUS 신호 일치 | 회의 종료 → Phase 5 종합 |
| 모든 워커 응답에 CONSENSUS 없음 (DISSENT 등 이견 잔존) | 다음 라운드 prompt 자동 작성 → 진행 |
| max-round (기본 5) 도달 | 회의 종료 → 미합의 항목 명시한 채 Phase 5 종합 |
| 사용자가 라운드 중 메시지 보냄 | 즉시 그 메시지를 반영 (모드 변경, 종료 요청, 의견 추가 등) |

**전제**: Lead는 회의 수행 중에도 사용자 입력을 받을 수 있어야 한다. 사용자가 자발적으로 개입하면 즉시 처리.

**사용자 명시적 변경만 종료 조건 교체**:
- "max-round 10으로 늘려" → 그 시점부터 max-round=10
- "한쪽이 항복할 때까지" → 모드를 debate로 변경
- "지금 종료해줘" → 즉시 Phase 5 종합

별도 명시 없으면 위 기본 정책 유지.

#### 4-D. 다음 라운드 메시지 (MCP 경유의 경우)

```
mcp__claudex__codex-reply(
  conversationId: "<워커 conv id>",
  prompt: "<이전 라운드 다른 워커 의견 요약 + Lead 입장 + 질문>"
)
```

cmux 경로의 경우 4-A 패턴 반복.

### Phase 5: 종합 + 정리

#### 5-A. 결과 종합 (Lead Claude 단독)

```markdown
## Multi-Round Results

### 회의 정보
- 모드: {consult|dialogue|collaborate|debate}
- 참가자: {Claudex(GPT-5.5), Claude(Fable 5), ...}
- 진행 라운드: {N/M}
- 종료 사유: {CONSENSUS 도달 | max-round | 사용자 조기 종료}

### Consensus (합의된 부분)
- ...

### Unresolved (라운드 종료 시 미합의)
- 각 입장 + Lead 판단

### 결론
- 최종 권장안 (Lead 종합)
```

#### 5-B. 정리 (워커 + pane)

**MCP 경유 (3-A)**:
- conversation은 별도 종료 명령 없음. 다음 사용 시 새 conversationId로 시작
- 잔존 mcp-server 자식 프로세스 확인:
  ```bash
  pgrep -f "claudex mcp-server" 2>/dev/null
  ```
  (정상 시 Claude Code 종료 시 함께 정리됨. 강제종료 시 잔존 가능 — 수동 kill)

**cmux pane 경유 (3-B)**:
- 워커 pane은 release 시 자동 close 안 함 (관찰 보존)
- 회의 전체 종료 시 사용자에게 "워커 pane 닫을까요?" 컨펌 후 `cmux close-surface --surface surface:N`

## 보안 가드 요약

| # | 가드 | 위반 시 |
|---|---|---|
| 1 | Phase 0 참가자 CLI 1개 이상 설치 확인 (`claude` / `claudex` / `codex` 중) | abort |
| 2 | claudex mcp-server 기동 시 `-c mcp_servers={}` 강제 (worker MCP 컨텍스트 격리) | 의도와 다른 MCP 도구 노출 |
| 3 | cmux send 줄바꿈 sanitize | 조기 제출 / prompt 손상 |
| 4 | settings.json 자동 write 금지 (수동 가이드만) | 사용자 환경 임의 변경 |
| 5 | claudex/claude/codex 모두 없으면 명시 에러 (silent 실패 X) | 사용자 혼란 |
| 6 | Lead surface 캡처는 `cmux identify` 의 `.caller.surface_ref` 사용 | fallback 미작동 |

## Error Handling

| 시나리오 | 동작 |
|---|---|
| `claudex` 미설치 + `codex` 있음 | real codex로 graceful fallback + WARN 로그 |
| `claudex` + `codex` 미설치 + `claude`만 있음 | `claude-only` 모드 진행 + WARN ("mix 불가 — 시각 다양성 ↓") |
| `claude` 미설치 + `claudex` 또는 `codex` 있음 | 그 쪽만으로 진행 + WARN |
| 셋 다 미설치 | abort + "참가자 CLI 1개 이상 설치 필요" 보고 |
| `HAVE_CMUX=1` + MCP 등록 X | Phase 3-B (cmux pane + claudex/codex TUI) 경로로 자동 전환 |
| `HAVE_CMUX=0` + MCP 등록 X | 사용자에게 등록 안내 후 작업 중단 |
| 응답 timeout (라운드당 120s) | 해당 워커 skip, 남은 워커로 종합 |
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

## 워커 prompt 표준 inject (각 워커에게 전달)

각 워커 prompt 에 다음 라인 inject:
```
- 응답 언어: 한국어
- 응답 마지막 줄에 'DONE:' 센티넬 출력 (응답 완료 감지용)
- 회의 모드: {consult|dialogue|collaborate|debate}
- 신호 프로토콜 사용 (ACK/STATUS/BLOCKED/DONE + 모드별 확장)
```

## 참가자 페르소나

상세 페르소나는 `agents/` 하위 파일 참조:
- `agents/codex-participant.md` — claudex/codex 워커용
- `agents/claude-participant.md` — claude CLI 워커용 (선택)
