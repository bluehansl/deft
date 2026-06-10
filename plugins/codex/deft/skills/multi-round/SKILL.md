---
name: multi-round
description: 여러 AI(Codex/Claudex/Claude)가 N라운드 양방향 토론으로 합의에 도달하는 멀티턴 회의 skill. cmux 환경에서는 pane 시각화를 우선 사용하고, cmux 외부에서는 claudex MCP 또는 codex 내부 병렬 처리로 진행한다. 1발 비교는 multi-check, 파일 작업·장기 협업은 Codex 자체 task 실행을 쓰세요. 트리거 — "멀티 라운드", "라운드 토론", "AI끼리 토론", "합의될 때까지", "클로덱스랑 토론", "multi round", "multi-round debate".
---

# Multi-Round Skill (Codex)

여러 AI가 **여러 라운드에 걸쳐 양방향으로 의견을 주고받는** 토론·합의 도구. cmux 환경에서는 **cmux pane 시각화**를 우선 사용하고, cmux 외부에서는 **claudex MCP 경유** 또는 **codex 내부 병렬 처리**로 동작한다.

> 본 skill은 **Codex 포팅본**입니다. Claude Code용 동일 skill은 `plugins/deft/skills/multi-round/` 에 있습니다. 기본 워크플로는 동일하지만 사용자 데이터 경로·MCP 등록 위치·cmux 외부 fallback에 차이가 있습니다.

## 3-도구 멘탈 모델

| 도구 | 통신 방식 | AI 조합 | 의존성·기반 | 언제 쓰는가 |
|---|---|---|---|---|
| `multi-check` | **1회성** fan-out (응답 비교) | Codex/Claude/Gemini 동시 | CLI 직접 호출 (MCP 무관) | "한 번 물어보고 답만 비교" |
| **`multi-round`** | **지속 통신** (N라운드 양방향) | **Codex + Claudex + Claude mix** | cmux pane 또는 MCP/codex 내부 병렬 | "의견 갈려서 여러 번 주고받으며 좁히고 싶다 / 토론" |
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

## 작업 디렉토리 표준 (skill 실행 시 사용)

skill 실행 시 사용하는 데이터·세션·hooks는 `~/.codex/plugin-data/deft/multi-round/` 하위에 저장한다.

```
~/.codex/plugin-data/deft/multi-round/
├── README.md             # 작업 디렉토리 용도·정책
├── sessions/             # 회의별 prompt·state·transcript (회의 종료 후도 보존)
│   └── <YYYYMMDD-HHMM-tag>/
│       ├── round1-<worker>.md
│       ├── round2-<worker>.md
│       ├── ...
│       └── state.sh      # LEAD_SURFACE, W_*_SURFACE, W_*_PANE, W_*_CONV_ID 등
├── state/                # 영구 메타 (cumulative)
└── hooks/                # skill 동작 훅 (필요 시)
```

skill 실행 시 다음 환경 변수 설정 후 모든 경로 이걸 통해 참조:

```bash
SKILL_BASE="$HOME/.codex/plugin-data/deft/multi-round"
SESSION_TAG="$(date +%Y%m%d-%H%M)-<주제slug>"
SESSION_DIR="$SKILL_BASE/sessions/$SESSION_TAG"
mkdir -p "$SESSION_DIR"
```

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
- 참가자 CLI 1개 이상 + (cmux 환경이면 pane 경로, 외부면 codex 내부 fallback)
- `HAVE_CMUX` 값이 Phase 3 분기 결정
- `cmux-rebalancing` 헬퍼는 Phase 3 spawn 종료 시점에 자동 호출 (cmux 환경 한정)

### Phase 1: 회의 모드 + 참가자 결정

1. 사용자 요청에서 의도 추출 ("토론해줘"→dialogue, "분담해서"→collaborate 등)
2. 명확하지 않으면 4지선다 메뉴 출력
3. 기본값: **dialogue**

**Lead 시점**: 본 skill은 Codex 세션이 트리거할 때 발동. Lead = Codex (또는 Claudex). Worker는 mix가 default.

**worker CLI 우선순위 (cmux 내 pane 띄울 때)**:
- ① `claudex` 가 설치되어 있으면 **claudex 우선**
- ② 없으면 `codex`
- ③ 둘 다 없고 `claude` 만 있으면 claude
  - 단, 본 skill은 Codex 측이므로 claudex/codex 가 1순위

### Phase 2: MCP 서버 등록 가이드 (자동 write 금지 — 사용자 정책 §6-3)

`~/.codex/config.toml` 은 사용자 환경 파일이므로 **자동 수정 금지**. 미등록 시 사용자에게 다음 스니펫을 출력하고 수동 등록을 요청한다.

```toml
# ~/.codex/config.toml — [mcp_servers.claudex] 섹션 추가
[mcp_servers.claudex]
command = "claudex"
args = ["mcp-server", "-c", "mcp_servers={}"]
```

**핵심**: `-c mcp_servers={}` 인자가 worker 쪽 MCP 컨텍스트를 비워, 현재 회의에 필요한 claudex MCP만 분리해서 사용하게 한다.

등록 확인:
```bash
# codex 재시작 후
codex mcp list 2>/dev/null | grep -q '^claudex' || echo "WARN: claudex MCP 미등록 — config.toml 확인 + codex 재시작 필요"
```

3-A 사용 조건:
- `claudex` 설치 + `[mcp_servers.claudex]` 등록이 모두 필요하다.
- `claudex` 미설치(codex-only) 환경에서는 3-A를 사용하지 않고 3-B 또는 3-C로 진행한다.

미등록/미설치 시 fallback:
- `HAVE_CMUX=1` → Phase 3-B (cmux pane + claudex/codex TUI 직접 spawn)
- `HAVE_CMUX=0` → Phase 3-C (codex 내부 병렬 처리)

### Phase 3: 워커 spawn — 환경별 경로

자동 분기 우선순위:

| 환경 | 권장 경로 |
|---|---|
| `HAVE_CMUX=1` | **3-B. cmux pane** — MCP 등록 여부와 무관하게 시각화 우선 |
| `HAVE_CMUX=0` + claudex MCP 등록 | **3-A. MCP 경유** |
| `HAVE_CMUX=0` + claudex MCP 미등록/미설치 | **3-C. codex 내부 병렬 처리** |

> cmux 환경에서 3-A를 쓰는 것은 사용자가 명시적으로 "시각화 생략"을 요청한 경우에만 허용한다.

#### 3-A. claudex MCP 경유 (cmux 외부 stateful 경로)

`HAVE_CMUX=0` 이고 claudex MCP가 등록된 경우 사용하는 stateful 통신 경로. Codex가 lead일 때 MCP tool 호출 (실제 tool name은 codex의 MCP 명세에 따름 — 예: `claudex.codex` / `claudex.codex-reply`):

각 워커별 conversation 시작:
```
claudex.codex(
  prompt: "<페르소나 + 라운드 1 prompt>",
  model: "gpt-5.5",                  # claudex/codex worker 표준 모델
  cwd: "<원하는 cwd>",
  developer-instructions: "<페르소나 골격 — agents/codex-participant.md 본문>"
)
→ 반환된 conversationId를 워커별로 저장 (sessions/<tag>/state.sh)
```

이후 라운드:
```
claudex.codex-reply(
  conversationId: "<해당 워커 conv id>",
  prompt: "<다음 라운드 prompt>"
)
```

장점: cmux 외부에서도 conversationId 기반 stateful 라운드 진행 가능.
단점: pane 시각화 없음 — Lead 출력으로 진행 표시.

#### 3-B. cmux pane + claudex/codex TUI (cmux 환경에서만)

`HAVE_CMUX=1` 일 때 기본 적용. cmux 외부면 skip하고 3-A 또는 3-C로 진행한다.

Lead surface 캡처:
```bash
LEAD_SURFACE=$(cmux identify 2>/dev/null | jq -r '.caller.surface_ref' 2>/dev/null)
[ -z "$LEAD_SURFACE" ] && LEAD_SURFACE="${CMUX_SURFACE_ID:-}"
```

첫 워커: 우측 분할
```bash
SPLIT=$(cmux new-split right --focus false 2>&1)
W1_SURFACE=$(printf '%s' "$SPLIT" | grep -oE 'surface:[0-9]+' | head -1)
```

이후 워커: 아래 분할
```bash
SPLIT=$(cmux new-split down --pane "<prev_pane>" --focus false 2>&1)
W2_SURFACE=$(printf '%s' "$SPLIT" | grep -oE 'surface:[0-9]+' | head -1)
```

워커 pane에 TUI 기동 — **claudex 우선, 없으면 codex**. 모델 버전 명시:
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
sleep 3
```

##### 3-B-fin. 첫 pane 분할 직후 비율 재조정 (Lead 직접 호출, 1회)

**첫 워커의 우측 분할(`cmux new-split right`)이 끝난 직후 Lead pane 에서 `cmux-rebalancing` 을 한 번 호출**한다. 좌우 컬럼 비율이 바로 정책대로 잡힌다. 마지막 워커 분할까지 기다리지 않는다.

```bash
# Lead pane 에서 직접 실행 — 좌→우: 2컬럼=60:40 / 3컬럼=40:30:30 / 4컬럼=25:25:25:25 / 5+=균등
command -v cmux-rebalancing >/dev/null 2>&1 && cmux-rebalancing
# 사용자 명시 비율 (예시): cmux-rebalancing 7:3
```

> 두 번째 이후 워커는 같은 우측 컬럼 안에서 **하단으로 수직 분할**(`cmux new-split down`)되므로 좌우 비율은 유지된다. **추가 호출 불필요**.

⚠️ **첫 분할 직후 본 호출 누락 시** Lead pane 가독성 저하.

#### 3-C. codex 내부 병렬 처리 (cmux 외부 fallback)

`HAVE_CMUX=0` + 3-A의 MCP 미등록/미설치 시 사용하는 background 경량 모드. Codex가 자체적으로 worker 인스턴스를 background process로 spawn해서 라운드별 응답을 수집.

```bash
# worker 1 — claudex 우선. CLI 별 1-shot 실행 형식과 모델 버전이 다름에 주의:
#   claudex/codex: exec -m gpt-5.5 - < <file>      (stdin)
#   claude:        claude -p - --model claude-fable-5 < <file>   (exec 서브명령 없음)
if [ "$HAVE_CLAUDEX" -eq 1 ]; then WORKER_A_CMD=(claudex exec -m gpt-5.5 -)
else                               WORKER_A_CMD=(codex   exec -m gpt-5.5 -); fi
if [ "$HAVE_CLAUDE" -eq 1 ];  then WORKER_B_CMD=(claude -p - --model claude-fable-5 --permission-mode dontAsk --output-format text)
else                               WORKER_B_CMD=("${WORKER_A_CMD[@]}"); fi

# 라운드별 — background로 동시 실행 (병렬), 응답을 파일로 캡처
"${WORKER_A_CMD[@]}" < "$SESSION_DIR/round1-A.md" > "$SESSION_DIR/round1-A.out" 2>&1 &
PID_A=$!
"${WORKER_B_CMD[@]}" < "$SESSION_DIR/round1-B.md" > "$SESSION_DIR/round1-B.out" 2>&1 &
PID_B=$!

wait "$PID_A" "$PID_B"
```

> codex / claudex 는 stdin 기반 1-shot 실행에 `exec -m gpt-5.5 - < <file>` 형식을 사용한다. **`claude` CLI 에는 `exec` 서브명령이 없으므로 `claude -p - --model claude-fable-5` 형식**을 사용한다.

라운드 양방향성 유지:
- worker 응답 history를 `$SESSION_DIR/worker-A.history.md` 에 누적
- 다음 라운드 prompt에 history 본문을 포함시켜 stateless CLI에서도 양방향 토론 모사
- conversationId 기반 stateful 통신은 3-A 경로에서만 가능

장점: cmux 외부에서도 동작, codex 단독 환경에서도 가능
단점: stateless라 매 라운드 history 누적 → context 길이 부담. max-round 5 권장.

### Phase 4: 라운드 진행

#### 4-A. prompt 주입 — cmux 경로 (3-B)

⚠️ **`cmux send`의 `\n`은 Enter로 해석되어 다중 라인 prompt가 조기 제출**. 다음 패턴 강제:

```bash
PROMPT_SAFE=$(tr '\n' ' ' < "$SESSION_DIR/round1-claude.md")
cmux send --surface "$W1_SURFACE" "$PROMPT_SAFE"
cmux send-key --surface "$W1_SURFACE" Enter
```

긴 prompt는 `$SESSION_DIR/round<N>-<worker>.md` 파일로 저장 후 워커에 "Read $SESSION_DIR/round<N>-<worker>.md" 안내.

#### 4-B. 응답 완료 감지 — 경로별

**3-A (MCP)**: tool 호출 응답이 도착하면 완료. 별도 폴링 X.

**3-B (cmux pane)**:
```bash
# DONE 센티넬 grep (1차)
cmux capture-pane --surface "$W1_SURFACE" --scrollback --lines 200 \
  | grep -qE '^DONE:' && echo "WORKER_DONE"

# idle-stable 폴링 (2차 보조)
PREV=""
for _ in $(seq 1 30); do
  CUR=$(cmux capture-pane --surface "$W1_SURFACE" --lines 20)
  [ "$CUR" = "$PREV" ] && { echo "IDLE_STABLE"; break; }
  PREV="$CUR"; sleep 8
done
```

**3-C (codex 내부)**: `wait $PID` 로 종료 대기. 응답 파일(`*.out`) read 후 마지막 줄 `^DONE:` 확인.

#### 4-C. 라운드 진행 — 자동 진행 (사용자 질문 X)

**기본 정책**: 회의 종료 조건은 **'스폰된 모든 AI의 합의 (CONSENSUS)' 또는 '사용자 개입'**. Lead는 사용자에게 라운드별 계속/중단 여부를 묻지 않고 **자체적으로 라운드를 계속 진행**.

| 상황 | Lead 동작 |
|---|---|
| 모든 워커 응답에 CONSENSUS 신호 일치 | 회의 종료 → Phase 5 |
| 모든 워커 응답에 CONSENSUS 없음 | 다음 라운드 prompt 자동 작성 → 진행 |
| max-round (기본 5) 도달 | 회의 종료 → 미합의 항목 명시 |
| 사용자가 라운드 중 메시지 보냄 | 즉시 그 메시지를 반영 (모드 변경, 종료, 의견 추가) |

#### 4-D. 다음 라운드 메시지

- **3-A**: `claudex.codex-reply(conversationId, prompt)` 호출
- **3-B**: 4-A 패턴 반복
- **3-C**: history 누적된 새 prompt 파일로 worker 재실행 (`"${WORKER_X_CMD[@]}" < round<N>-*.md` — 3-C 의 CLI 별 명령 배열 재사용)

### Phase 5: 종합 + 정리

#### 5-A. 결과 종합 (Lead Codex 단독)

```markdown
## Multi-Round Results

### 회의 정보
- 모드: {consult|dialogue|collaborate|debate}
- 참가자: {Codex(gpt-5.5), Claudex(GPT-5.5), Claude(Fable 5), ...}
- 진행 라운드: {N/M}
- 종료 사유: {CONSENSUS 도달 | max-round | 사용자 조기 종료}
- 실행 경로: {3-A MCP | 3-B cmux | 3-C codex-internal}

### Consensus (합의된 부분)
- ...

### Unresolved (라운드 종료 시 미합의)
- 각 입장 + Lead 판단

### 결론
- 최종 권장안 (Lead 종합)
```

#### 5-B. 정리

**3-A (MCP)**: conversation 별도 종료 X. 잔존 mcp-server 자식 프로세스:
```bash
pgrep -f "claudex mcp-server" 2>/dev/null
```

**3-B (cmux pane)**: 워커 pane 자동 close 안 함 (관찰 보존). 회의 전체 종료 시 사용자 컨펌 후 `cmux close-surface --surface surface:N`.

**3-C (codex 내부)**: background process 자동 종료 확인 (`wait`로 보장). `$SESSION_DIR/*.out` 보존.

## 보안 가드 요약

| # | 가드 | 위반 시 |
|---|---|---|
| 1 | Phase 0 참가자 CLI 1개 이상 설치 확인 | abort |
| 2 | claudex mcp-server 기동 시 `-c mcp_servers={}` 강제 | worker MCP 컨텍스트 오염 |
| 3 | cmux send 줄바꿈 sanitize (3-B 경로) | 조기 제출 / prompt 손상 |
| 4 | `~/.codex/config.toml` 자동 write 금지 (수동 가이드만) | 사용자 환경 임의 변경 |
| 5 | claudex/claude/codex 모두 없으면 명시 에러 (silent 실패 X) | 사용자 혼란 |
| 6 | cmux 환경에서는 3-B 우선, cmux 외부일 때만 3-A/3-C | spawn 정책 위반 |

## Error Handling

| 시나리오 | 동작 |
|---|---|
| `claudex` 미설치 + `codex` 있음 | codex로 graceful fallback |
| `codex` + `claudex` 미설치 + `claude`만 있음 | `claude-only` 모드 + WARN |
| 셋 다 미설치 | abort |
| `HAVE_CMUX=1` | MCP 등록 여부와 무관하게 Phase 3-B 우선 |
| `HAVE_CMUX=0` + claudex MCP 등록 | Phase 3-A로 진행 |
| `HAVE_CMUX=0` + claudex MCP 미등록/미설치 | Phase 3-C로 자동 전환 |
| 응답 timeout (라운드당 120s) | 해당 워커 skip, 남은 워커로 종합 |
| 한 워커 BLOCKED | 사용자에게 즉시 보고 + 결정 위임 |
| max-round 도달 | Phase 5 종합 — 미합의 항목 명시 + Lead 권장안 1개 |

## Trigger 회피 매트릭스 (오발동 방지)

`multi-round`가 매칭되어선 안 되는 어휘:
- "회의", "회의 좀 해줘", "한번 봐줘", "같이 봐줘"
- "검토해줘", "워커 띄워", "둘이서 얘기해봐"

## worker prompt 자동 inject

각 워커 prompt에 다음 라인 inject:
```
- 응답 언어: 한국어 (~/AGENTS.md §1)
- 응답 마지막 줄에 'DONE:' 센티넬 출력
- 회의 모드: {consult|dialogue|collaborate|debate}
- 신호 프로토콜 사용 (ACK/STATUS/BLOCKED/DONE + 모드별 확장)
```

## 참가자 페르소나

상세 페르소나는 `agents/` 하위 파일 참조:
- `agents/codex-participant.md` — claudex/codex 워커용
- `agents/claude-participant.md` — claude CLI 워커용 (선택)
