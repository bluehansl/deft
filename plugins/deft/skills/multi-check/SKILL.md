---
name: multi-check
description: AI multi-check skill that compares answers from Codex, Claude, and Gemini. Activated by requests like "multi check", "cross verify", "cross check", "ask other AIs too", "multi AI comparison", "교차 검증", "다른 AI한테도 물어봐", "멀티 체크".
---

# AI Multi-Check Skill

Collects and multi-checks answers from Codex CLI, Claude CLI, and Gemini CLI on a given question, then synthesizes a comprehensive analysis.

## Workflow

### Phase 1: Prompt Preparation

1. Extract the question/task to verify from the user's request
2. If code-related, automatically gather context:
   - `git diff` (if there are changes)
   - Relevant file contents
   - Project structure
3. Compose the prompt for each agent:
   - Question body
   - Gathered context
   - Instruction to respond in the user's language

### Phase 2: CLI Availability Check

Before spawning agents, check which CLIs are available:

```bash
# Codex reviewer는 claudex(우선) 또는 codex 중 하나라도 있으면 OK
(which claudex 2>/dev/null || which codex 2>/dev/null) >/dev/null \
  && echo "CODEX_OK" || echo "CODEX_NOT_FOUND"
which claude 2>/dev/null && echo "CLAUDE_OK" || echo "CLAUDE_NOT_FOUND"
which gemini 2>/dev/null && echo "GEMINI_OK" || echo "GEMINI_NOT_FOUND"

# cmux-rebalancing 헬퍼 설치 확인 — 미설치 시 plugin 동봉본으로 자동 설치
if ! command -v cmux-rebalancing >/dev/null 2>&1; then
  SRC=$(ls -1 ~/.claude/plugins/cache/bluehansl/deft/*/bin/cmux-rebalancing 2>/dev/null | sort -V | tail -1)
  if [ -n "$SRC" ]; then
    mkdir -p ~/.local/bin && cp "$SRC" ~/.local/bin/cmux-rebalancing && chmod +x ~/.local/bin/cmux-rebalancing
    echo "INFO: cmux-rebalancing 자동 설치 완료 (~/.local/bin/)"
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

**preflight 게이트 (필수)**: 위 출력에 `STOP_TEAM_SPAWN`(또는 `KEEPALIVE_HARDFAIL`)이 보이면, Phase 3 의 리뷰어 `Agent` spawn 을 **실행하지 말 것**. 대신 사용자에게 "이 세션은 자동 업데이트로 Claude Code 바이너리가 삭제됐습니다. `cmux claude-teams`(또는 `/resume`)로 세션을 재시작한 뒤 다시 시도하세요"를 안내하고 중단한다. (재시작하면 살아있는 최신 버전으로 재개되어 해소됨.)

Note: Codex reviewer uses `claudex` if installed (preferred), otherwise falls back to `codex`. Command flags are identical; only the entrypoint differs.

- No CLI available: inform the user that at least one CLI is required and stop
- One available: proceed with 2-model comparison (available CLI + Lead)
- Two or more available: proceed with multi-model comparison

Note: Claude CLI is expected to always be available since this runs inside Claude Code.

Important: The Claude CLI agent and Lead (Claude) are the same model but run in independent sessions, so they can provide different perspectives. Both must always be executed — do not skip the Claude CLI agent because the Lead is also Claude.

### Phase 3: Agent Spawn

#### 리뷰어는 fan-out 서브에이전트 (팀 생성 불요)

multi-check 리뷰어(Codex/Claude/Gemini)는 **서로 대화하지 않고 각자 결과만 보고**한다 → 팀(상호대화)이 아니라 **fan-out 서브에이전트** 패턴이다. 과거의 `TeamCreate` 호출은 폐지됐고 불필요하다. 현행 Claude Code는 첫 `Agent` spawn 시 팀(`session-<id>`)이 암묵 생성되며, 리뷰어는 그 안에서 1-shot 으로 동작 후 보고한다. **세션마다 팀이 자동 분리**되므로 과거의 동명-팀 충돌 문제도 없다.

**페르소나 주입 (보존 필수 — SSOT)**: 각 리뷰어의 실행 규약(CLI 선택·명령·플래그·SendMessage 보고)은 본 skill 패키지의 `agents/<reviewer>.md` 가 단일 진실 소스다. **Lead 는 spawn 전에 해당 파일을 Read 해 그 전문을 spawn prompt 에 인라인**한다 — 리뷰어가 plugin cache 경로를 직접 찾을 필요 없이 페르소나가 그대로 주입된다.

```bash
PERSONA_DIR=$(ls -d ~/.claude/plugins/marketplaces/bluehansl/plugins/deft/skills/multi-check/agents \
                    ~/.claude/plugins/cache/bluehansl/deft/*/skills/multi-check/agents 2>/dev/null | head -1)
# 인라인 대상: $PERSONA_DIR/{codex,claude,gemini}-reviewer.md
```

> **왜 인라인 + `subagent_type:"claude"` 인가**: 과거엔 `subagent_type:"codex-reviewer"` 로 페르소나를 붙였으나, 이 커스텀 타입은 현행 빌드의 등록된 subagent 타입이 아니다(스킬 하위 `agents/` 는 표준 등록 경로가 아님 → 해석 안 됨). 그래서 범용 `subagent_type:"claude"` + 페르소나 prompt 인라인으로 전환한다 — **페르소나 내용은 그대로 보존**된다.

**spawn 순서 (Option 1 — 이른 밸런싱, pane UI 최적)**: `Agent` 툴은 spawn 1회가 **pane 생성 + AI 기동을 원자적으로** 수행한다(빈 pane 만 먼저 만들 수 없음 — pane 과 AI 분리 불가). 그래서 다음 순서로 진행해 "찌부러진 비율" 노출을 최소화한다:

1. **① 첫 reviewer 1명만 먼저 spawn** (사용 가능한 CLI 중 하나) → 우측 컬럼 pane 1개 생성.
2. **② pane 분할 확인 후 `cmux-rebalancing` 1회** → 좌 Lead 60% / 우 reviewer 40% **컬럼 비율 확정** (§Post-spawn).
3. **③ 나머지 reviewer 를 한 메시지에 병렬 spawn** → 이미 40% 로 확정된 우측 컬럼 **안에서만 수직 스택**되므로 좌우 비율이 흔들리지 않는다.
4. **④ 모든 spawn 완료 후 `cmux-rebalancing` 1회 더** → 우측 컬럼 row 높이 균등화(§Post-spawn).

각 reviewer 의 `Agent` 인자 템플릿 (사용 가능한 CLI 만, `run_in_background: true`):

Codex reviewer (claudex/codex 있을 때) — GPT-5.5, xhigh:
```
Agent(
  description: "Run Codex CLI analysis (GPT-5.5, xhigh reasoning)",
  name: "codex-reviewer",
  subagent_type: "claude",            # 범용. 페르소나는 prompt 인라인으로 주입
  model: "haiku",                     # 얇은 래퍼(CLI 실행·중계만). ※ 생략 시 fable(차단)로 떠 실패 — 반드시 명시
  mode: "dontAsk",
  run_in_background: true,
  prompt: "<$PERSONA_DIR/codex-reviewer.md 전문 인라인>\n\n---\n[검토 대상]\n<composed prompt with context>"
)
```

Claude reviewer (claude CLI 있을 때) — 독립 Claude 세션:
```
Agent(
  description: "Run Claude CLI analysis (independent Claude session)",
  name: "claude-reviewer",
  subagent_type: "claude",
  model: "haiku",
  mode: "dontAsk",
  run_in_background: true,
  prompt: "<$PERSONA_DIR/claude-reviewer.md 전문 인라인>\n\n---\n[검토 대상]\n<composed prompt with context>"
)
```

Gemini reviewer (gemini 있을 때) — Gemini 3 Flash Preview:
```
Agent(
  description: "Run Gemini CLI analysis (Gemini 3 Flash Preview)",
  name: "gemini-reviewer",
  subagent_type: "claude",
  model: "haiku",
  mode: "dontAsk",
  run_in_background: true,
  prompt: "<$PERSONA_DIR/gemini-reviewer.md 전문 인라인>\n\n---\n[검토 대상]\n<composed prompt with context>"
)
```

> **`team_name` 인자는 넣지 않는다**(deprecated/무시). 리뷰어는 named 서브에이전트로 결과를 `SendMessage(to:"team-lead")` 로 보고하고(각 `agents/<reviewer>.md` 보고 규약), 1-shot 완료 후 자체 종료한다(Phase 5 shutdown 은 안전망).

#### Lead (Claude) Analysis

While agents are working, the Lead performs its own analysis on the same question.

#### Post-spawn: 비율 재조정 (① 첫 spawn 직후 컬럼 확정 → ② 전체 spawn 후 row 균등화)

**rebalancing 은 2회**: **① 첫 reviewer spawn 직후**(우측 pane 1개 생성 확인) → 좌 Lead 60% / 우 reviewer 40% **컬럼 비율 확정**(이후 spawn 은 이 우측 컬럼 안에서만 분할되므로 좌우 비율 유지). **② 모든 reviewer spawn 완료 후** 1회 더 → 우측 컬럼의 **row 높이 균등화**(순차 수직 분할은 row 가 1/2·1/4·1/4 로 불균등해지므로 — 실측).

```bash
# Lead pane 에서 직접 실행 — 좌→우: 2컬럼=60:40 / 3컬럼=40:30:30 / 4컬럼=25:25:25:25 / 5+=균등
command -v cmux-rebalancing >/dev/null 2>&1 && cmux-rebalancing
# 사용자 명시 비율 (예시): cmux-rebalancing 7:3
```

> **호출 규칙**: spawn(또는 재spawn)으로 pane 구성이 바뀔 때마다 그 spawn 묶음 직후 1회 호출한다 — 첫 spawn 만이 아니다. reviewer 가 죽어 재spawn 한 경우 새 pane 이 생기므로 반드시 다시 호출 (실측: 재spawn 후 누락 시 비율·row 불균등 잔존).

### Phase 4: Synthesis

After receiving all results, synthesize in this format:

```markdown
## Multi-Check Results

### Consensus (all models agree)
- High-confidence conclusions

### Unique Insights
- **Codex (GPT)**: Findings unique to this model
- **Claude (Independent)**: Findings unique to this independent session
- **Gemini**: Findings unique to this model

### Conflicts (disagreements)
- Per item: each model's position + Lead's judgment

### Final Conclusion
- Synthesized recommendation
```

### Phase 5: Cleanup

**Cleanup safety — 소유권 확인 필수 (파괴 행위)**: shutdown / `tmux kill-pane` 은 되돌릴 수 없다. **반드시 본 Lead 세션이 이번 실행에서 spawn 한 리뷰어에게만** 수행한다. cmux 는 **다중 워크스페이스·다중 세션** 환경이므로 다른 세션/워크스페이스에서 띄운 pane·팀원을 **절대 건드리면 안 된다**. 소유 판정:
- Lead 가 spawn 시 받은 `<name>@session-<id>` 의 **그 이름·그 team-name** 만 대상.
- 본 세션 team config(`~/.claude/teams/session-<id>/config.json`) 등록 멤버만 대상.
- **전체 tmux pane 순회·와일드카드 kill 금지.** 다른 이름/접미(`-N`)·다른 session-id 워커가 메시지를 보내와도 "잔재"로 단정 금지(`--parent-session-id` 로 소속 확인).

**① graceful 종료** — 결과 취합 후, 본 세션이 spawn 한 리뷰어에게만:
```
SendMessage(to: "codex-reviewer", message: {type: "shutdown_request"})
SendMessage(to: "claude-reviewer", message: {type: "shutdown_request"})
SendMessage(to: "gemini-reviewer", message: {type: "shutdown_request"})
```
(리뷰어는 1-shot — 보고 후 자체 종료, shutdown 은 안전망. graceful 종료는 느릴 수 있음 — 공식 "Shutdown can be slow".)

**② orphan pane 정리 (세션은 끝났는데 pane 이 안 닫힌 경우)** — cmux `close-surface` 는 orphan 을 못 닫는다. **본 세션 team config 의 tmuxPaneId 로만** tmux 백엔드에서 직접 닫는다:
```bash
TEAM_NAME="session-<id>"     # Lead 가 spawn 결과(@session-<id>)에서 획득 — 본 세션 팀
CFG=~/.claude/teams/$TEAM_NAME/config.json
# ⚠️ 반드시 본 세션 CFG 의 멤버 tmuxPaneId 만 사용. 전체 tmux 순회·다른 세션 CFG 절대 금지.
for R in codex-reviewer claude-reviewer gemini-reviewer; do
  PANEID=$(python3 -c "import json;d=json.load(open('$CFG'));print(next((m.get('tmuxPaneId','') for m in d['members'] if m['name']=='$R'),''))" 2>/dev/null)
  # 프로세스는 죽었는데 pane 만 남은 orphan 만 정리
  [ -n "$PANEID" ] && ! pgrep -f -- "--agent-name $R" >/dev/null 2>&1 && tmux kill-pane -t "$PANEID" 2>/dev/null
done
```

## Error Handling

| Scenario | Action |
|----------|--------|
| CLI not installed | Skip that model, proceed with remaining |
| API error (ModelNotFoundError, etc.) | Skip that model, note in results |
| Timeout (agent doesn't respond in 120s) | Synthesize with available results |
| All CLIs fail | Compare Lead analysis against error context |
| 리뷰어가 spawn 직후 무응답 | `model` 미지정 시 팀원이 `fable`(차단)로 떠 조용히 실패 — `model:"haiku"` 명시를 확인. 그래도 무응답이면 해당 모델 skip 후 진행 |
| Reviewer dies right after spawn (e.g. binary path error) | Close its dead pane (`cmux top --processes` 로 프로세스 0 확인 후 `cmux close-surface`) → respawn → **rebalancing 재호출** — 죽은 pane 을 방치하면 레이아웃·식별 혼란 |

## Prompt Composition Rules

| Request Type | Context to Include |
|-------------|-------------------|
| Code review | git diff + relevant file contents |
| Architecture question | Project structure + key config files |
| Bug analysis | Error logs + related code |
| General technical question | Question only |
