---
name: multi-check
description: AI multi-check skill that compares answers from Codex, Claude, and Gemini. Activated by requests like "multi check", "cross verify", "cross check", "ask other AIs too", "multi AI comparison", "교차 검증", "다른 AI한테도 물어봐", "멀티 체크".
---

# AI Multi-Check Skill

Collects and multi-checks answers from Codex CLI, Claude CLI, and Gemini CLI on a given question, then synthesizes a comprehensive analysis.

> ## 🎯 Lead 운영 2대 원칙 (최우선 — 전 단계 강제)
>
> **원칙 1 — Lead 본체는 즉각 반응 우선. 대기는 전부 백그라운드.**
> - 메인 세션의 단 하나의 목표는 **사용자 질의에 즉각 반응할 수 있는 idle 상태 유지**다. reviewer spawn 을 **실행하는 순간에만** 바쁘고, **reviewer 응답을 기다리는 구간**은 메인을 점유하지 않는다.
> - 🚫 **대기를 foreground 로 구현 절대 금지** (긴 `sleep` 루프·동기 폴링). reviewer 응답은 `<teammate-message>` 자동 주입으로 **다음 턴**에 온다 — Lead 가 능동 sleep 으로 기다리지 말 것.
>
> **원칙 2 — 출력은 "고정된 announce 지점"에서만. 단계 중계 전면 금지.**
> - 사용자는 스킬을 **직접 의도해서** 호출했다 — 상세 진행 보고가 불필요하다. Lead 가 말하는 지점을 **아래로 고정**하고 그 사이는 말없이 연속 실행한다:
>
>   | # | 유일한 announce 지점 | 예시 |
>   |---|---|---|
>   | 1 | **교차검증 시작 예고** — 질문 + 어떤 AI 몇 개 | "Codex·Claude·Gemini 3개 AI로 교차검증을 시작합니다." |
>   | 2 | **답변 수집 완료 → 종합** | "3개 답변 수집 완료 — 비교 분석합니다." |
>   | 3 | **종합 비교 결과** | (합의/차이/권장안) |
>   | 4 | **사용자 개입 필요 시** | 무엇이 필요한지만 |
>
> - 🚫 **위 외 일체 출력 금지** — "reviewer spawn / deft-review 실행 / pane 분할 / 페르소나 주입 / PATH 보강" 같은 단계 나레이션 금지. spawn 은 1번 예고 후 **전부 한 번에 조용히** 실행하고 2번에서 완료만 알린다.
> - 🚫 **내부 메커니즘 출력 금지**: deft-review CLI·pane 분할·페르소나 주입·헬퍼 동기화·"Ran N shell commands".

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
   - **time-box 지침 (필수 — 무한 검색·지연 방지)**: 프롬프트 말미에 "multi-check 은 **빠른 교차검증** — 신속히 진행하고, 핵심 신뢰 출처 **1~2개**로 결론을 내라. 과도한 다중 web search(수십 회)는 하지 말 것" 를 덧붙인다. claudex/codex 의 web search 가 100+ 쿼리로 수 분간 늘어지면 haiku 래퍼가 background+Monitor 폴링으로 우회해 노이즈·지연을 유발한다(실측). 심층 사실검증이 필요하면 multi-check 이 아니라 `deep-research` 스킬이 적합하다.

### Phase 2: CLI Availability Check

Before spawning agents, check which CLIs are available:

```bash
# Codex reviewer는 claudex(우선) 또는 codex 중 하나라도 있으면 OK
(which claudex 2>/dev/null || which codex 2>/dev/null) >/dev/null \
  && echo "CODEX_OK" || echo "CODEX_NOT_FOUND"
which claude 2>/dev/null && echo "CLAUDE_OK" || echo "CLAUDE_NOT_FOUND"
which gemini 2>/dev/null && echo "GEMINI_OK" || echo "GEMINI_NOT_FOUND"

# Codex-family reviewer 표시 이름 — 실제 사용 CLI 반영(claudex 우선). pane/@agent 이름이 실제 실행 CLI 와
# 일치하도록(사용자 혼동 방지: "@codex-reviewer 인데 실제론 claudex" 문제 해소).
CODEX_REVIEWER_NAME=$(command -v claudex >/dev/null 2>&1 && echo claudex-reviewer || echo codex-reviewer)
echo "Codex-family reviewer 이름: $CODEX_REVIEWER_NAME"

# cmux CLI wrapper 설치 — cmux 가 PATH 에 없으면(신 cmux 는 대화형 precmd 훅으로만 PATH 주입 →
#   비대화형 셸엔 부재) deft 동봉 wrapper 를 ~/.local/bin/cmux 로 설치(조건부 gap-fill, 구버전 안 가림).
#   Lead 의 bare cmux(identify/focus-pane 등) 보호. wrapper 는 매 호출 env→표준경로로 진짜 cmux 해석.
# deft 헬퍼 동기 (갱신형 — 구버전 잔재 자동 최신화). 종전의 개별 `if ! command -v $H`(없으면 설치) 블록은
#   ~/.local/bin 구버전 잔재를 plugin update 후에도 갱신 못 하던 결함이 있어 deft-bin-sync 로 일원화(claude-2.34.0~).
#   deft-bin-sync 가 캐시 최신본과 cmp 해 다르면 cp → cmux(shim)·cmux-rebalancing·rebalance-watch·deft-model·
#   deft-review·claude-bin-keepalive 등 전체를 항상 최신화. 부트스트랩(자기 자신)은 단순 cp.
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
# 1순위: 버전 독립 marketplace 경로(있으면) — /plugin update 시 같은 경로가 갱신되어 항상 최신.
# 2순위: 캐시 전용 설치면 최신 버전 캐시. ⚠️ head -1 금지 — ls 알파벳 정렬로 가장 오래된 버전
#        (예: claude-2.0.0 < claude-2.19.0)을 집어 구버전 페르소나가 인라인된다(실측). sort -V|tail -1 로 최신 선택.
PERSONA_DIR=~/.claude/plugins/marketplaces/bluehansl/plugins/deft/skills/multi-check/agents
[ -d "$PERSONA_DIR" ] || PERSONA_DIR=$(ls -d ~/.claude/plugins/cache/bluehansl/deft/*/skills/multi-check/agents 2>/dev/null | sort -V | tail -1)
# 인라인 대상: $PERSONA_DIR/{codex,claude,gemini}-reviewer.md
```

> **왜 인라인 + `subagent_type:"claude"` 인가**: 과거엔 `subagent_type:"codex-reviewer"` 로 페르소나를 붙였으나, 이 커스텀 타입은 현행 빌드의 등록된 subagent 타입이 아니다(스킬 하위 `agents/` 는 표준 등록 경로가 아님 → 해석 안 됨). 그래서 범용 `subagent_type:"claude"` + 페르소나 prompt 인라인으로 전환한다 — **페르소나 내용은 그대로 보존**된다.

**spawn 순서 (Agent-tool — spawn 과 함께 rebalance 워처 발사)**: `Agent` 툴은 spawn 1회가 **pane 생성 + AI 기동을 원자적으로** 수행하고, cmux claude-teams 가 pane 배치를 **자동 처리**한다(스킬이 분할 방향·대상을 제어할 수 없음 — multi-round 와 달리 `cmux new-split` 을 직접 쓰지 못함). 그리고 **각 spawn 마다 Lead pane 이 다시 찌부러진다**(cmux 가 Lead 기준으로 재분할 — 실측). rebalancing 은 pane geometry 만 정렬하는 **독립·비동기** 작업이라 reviewer 의 headless CLI 작업과 무관하게 호출할 수 있다 → **spawn 묶음과 같은 메시지에서 `cmux-rebalance-watch` 를 백그라운드로 띄워, panes 가 다 생겨 settle 되는 즉시 1회 rebalance** 시킨다(§Post-spawn).

1. spawn **직전(=panes 생성 전)** 에 캡처: `LEAD_REF=$(cmux identify | jq -r .caller.pane_ref)` (focus 복원용) + `BASE=$(tmux list-panes -a -F '#{pane_id}' | wc -l | tr -d ' ')` (baseline) + 이번에 spawn 할 reviewer 수 `N` → `EXPECTED=$((BASE+N))` (목표 최종 pane 수) + `FAST=$([ "$BASE" -eq 1 ] && echo 1 || echo 0)` (**clean Lead 워크스페이스 판정** — BASE==1 이면 빠른 경로). ⚠️ **BASE/EXPECTED/FAST 는 반드시 spawn 전에 캡처**한다 — 워처가 자기 시작 시점에 baseline 을 잡으면 이미 panes 가 생성된 뒤라 값이 부풀려져 감지가 영원히 안 돼 cap 까지 헛돈다(실측 버그).
2. **사용 가능한 reviewer 전부 + rebalance 워처를 한 메시지에 함께 발사** — reviewer 는 `Agent`(병렬), 워처는 `cmux-rebalance-watch "$LEAD_REF" "$BASE" "$EXPECTED" "$FAST"` 를 **`run_in_background: true` Bash** 로 같은 메시지에. 워처가 panes 가 **EXPECTED 에 도달하는 즉시**(=모든 reviewer pane 등장 — panes 는 한꺼번에가 아니라 하나씩 순차 등장하므로 EXPECTED 도달이 가장 정확한 신호) rebalance(컬럼 60:40 + row 균등) + Lead focus 복원을 1회 실행한다(§Post-spawn). **`FAST=1`(clean Lead)이면 `cmux-rebalancing --fast`** (단발 push + row-equalize skip, ~4s→~2s — clean-grid 결정론 실측 기반), **아니면 robust** `cmux-rebalancing`.

각 reviewer 의 `Agent` 인자 템플릿 (사용 가능한 CLI 만, `run_in_background: true`):

> ⚠️ **prompt 끝에 "즉시 실행" 지시를 명시한다 (필수 — idle 정지 방지)**: reviewer 는 `run_in_background:true` 로 떠도 페르소나만 인라인하면 **첫 턴에 deft-review 를 실행하지 않고 idle 로 대기**하는 경우가 있다(실측 — Lead 가 SendMessage 로 깨워야 했음). 그래서 인라인 prompt 의 `[검토 대상]` 뒤에 반드시 한 줄을 덧붙인다:
> `\n\n[실행 지시] 지금 즉시 deft-review <engine> 로 위 검토 대상을 실행하고, 그 출력을 SendMessage(to:"team-lead", summary:"<engine> 검토 결과", message:"<출력>") 로 보고하라. 추가 지시를 기다리지 말 것.`
> 이 한 줄이 reviewer 의 첫 턴을 작업으로 발동시킨다.

Codex reviewer (claudex/codex 있을 때) — GPT-5.5, xhigh:
```
Agent(
  description: "Run Codex CLI analysis (GPT-5.5, xhigh reasoning)",
  name: "<$CODEX_REVIEWER_NAME>",     # claudex 있으면 claudex-reviewer, 없으면 codex-reviewer (실제 CLI 반영)
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

#### Post-spawn: 비율 재조정 — 워처가 panes settle 즉시 자동 실행

**rebalancing 은 워처(`cmux-rebalance-watch`)에 위임한다 — spawn 묶음과 같은 메시지에서 백그라운드로 발사**한다. 워처는 `tmux list-panes` 로 pane 수를 폴링해 **새 pane 들이 생겨 안정(settle)되는 즉시** `cmux-rebalancing`(컬럼 60:40 + row 균등) + Lead focus 복원을 1회 실행한다.

```text
# spawn 직전(panes 생성 전)에 캡처:
LEAD_REF=$(cmux identify | jq -r .caller.pane_ref)
BASE=$(tmux list-panes -a -F '#{pane_id}' | wc -l | tr -d ' ')
EXPECTED=$((BASE + N))                       # N = 이번에 spawn 하는 reviewer 수
FAST=$([ "$BASE" -eq 1 ] && echo 1 || echo 0)   # BASE==1(Lead 단독) → clean-grid 빠른 경로
# spawn 메시지에 reviewer Agent 들과 함께 포함 (run_in_background)
Bash(run_in_background: true): cmux-rebalance-watch "$LEAD_REF" "$BASE" "$EXPECTED" "$FAST"
```

> **clean-grid vs robust (실측 근거)**: 워처는 `FAST=1`이면 `cmux-rebalancing --fast`(단발 push + 행균등 skip + 폴링 최소, ~2s), 아니면 `cmux-rebalancing`(다회 수렴, ~4s)을 부른다. **clean Lead 워크스페이스(BASE==1)에서만 fast** — 그땐 squish 가 결정론적(N≥2 리뷰어 → Lead 26.1%·우측 73.9%, 우측 행 이미 균등)이라 단발로 정확히 60:40 이 된다(실측). **기존 pane 이 있으면(BASE>1) robust** — Agent-tool 은 새 pane 이 기존 우측 컬럼에 섞이거나(소유권), Lead 아래 pane 이 있으면 1컬럼 stack(rebalance no-op)/비그리드가 돼 단발 가정이 깨지기 때문(실측). multi-round 은 별도(Option 2 — fast 미적용).

> **왜 워처인가 (타이밍 당김)**: 종전엔 "전부 spawn **반환** 후 Lead 가 별도 턴에서 `cmux-rebalancing` 수동 호출"이라, ① `Agent` 툴 반환 지연 ② Lead 턴 생성 지연이 끼어 rebalance 가 **haiku 부팅·shell 실행 이후**로 한참 늦게 떴다(사용자 실측). rebalance 는 pane geometry 만 필요하므로, 워처를 spawn 과 동시에 띄우면 **panes 생성 직후(가장 이른 시점)** 정렬된다.
>
> ⚠️ **baseline(`$BASE`)은 반드시 spawn 전에 캡처해 워처에 넘긴다** — 워처는 spawn 과 같은 메시지에서 발사돼 보통 panes 가 이미 생성된 뒤 시작되므로, 워처가 자기 시작 시점에 baseline 을 잡으면 그 값이 부풀려져(=현재 pane 수) "증가" 감지가 영원히 안 돼 settle 못 하고 cap 까지 헛돈다(실측 버그 — claude-2.22.1 수정).
>
> ⚠️ **중간(첫 spawn 후) 호출이 무의미한 건 동일** — Agent-tool spawn 은 매번 Lead pane 을 재차 찌부러뜨린다(실측: 60%→26%→복원). 워처는 "증가가 멈춰 settle" 될 때까지 기다리므로 모든 spawn 이 끝난 시점을 자동으로 잡는다.
>
> **재spawn(죽은 reviewer 교체)**: pane 구성이 바뀌므로 워처를 다시 한 번 발사한다.
>
> **폴백(워처 미설치)**: 종전처럼 모든 spawn 반환 후 `cmux-rebalancing` 1회 수동 호출 + `cmux focus-pane --pane "$LEAD_REF"`. (좌→우: 2컬럼=60:40 / 3컬럼=40:30:30 / 4컬럼=25:25:25:25 / 5+=균등. 사용자 명시 비율: `cmux-rebalancing 7:3`)

### Phase 4: 보고 수신(per-report 종료) + Synthesis

**per-report 종료 (1-shot 리뷰어 — idle 대기 제거)**: 리뷰어는 1회성이라 보고 후 추가 요청을 기다릴 필요가 없다. **각 리뷰어의 report 가 도착하는 즉시, 전원 취합을 기다리지 말고 그 리뷰어에게만 `shutdown_request` 를 보낸다.** 리뷰어는 §종료 프로토콜대로 `shutdown_response{approve:true}` 로 즉시 종료 → **pane 이 보고 직후 순차적으로 닫힌다**(동시 일괄 종료가 아니라 보고순 정리). 취합 시점엔 대부분 이미 정리 완료.

```
# 리뷰어 report 1건 수신 → 즉시 그 1명에게만 (다음 보고를 계속 대기)
SendMessage(to: "<방금 보고한 리뷰어 이름>", message: {type: "shutdown_request"})
```

> 🚨 **`message` 는 반드시 구조화 객체(`{type:"shutdown_request"}`) — 평문 종료 금지**: "종료해 주세요" 같은 평문 문자열은 리뷰어가 *일반 메시지*로 받아 보고만 하고 프로세스가 안 내려간다(claude 리뷰어는 kill 도 금지라 구조화 shutdown_request 가 유일 종료 수단 — 실측). 안 죽었으면 kill 이 아니라 구조화 shutdown_request 를 다시 보낸다.

> Lead 는 그동안 자체 분석(§Lead Analysis)을 이어가고, 남은 리뷰어 보고를 계속 받는다. rebalance 는 순차 close 마다 호출하면 깜빡임이 생기므로 **최종 1회(Phase 5 ④)만** 한다.

전원 보고가 모이면 아래 형식으로 synthesize:

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

**① graceful 종료 보강** — 정상 흐름에선 Phase 4 의 per-report 종료로 각 리뷰어가 **보고 직후 이미 shutdown_request 를 받아 종료**했다. 여기서는 **미발송분만 보강**한다 — 보고가 늦었거나 per-report 발송이 누락된 리뷰어가 있으면 그 이름으로만 보낸다 (본 세션이 spawn 한 리뷰어에게만):
```
SendMessage(to: "<아직 shutdown_request 안 보낸 리뷰어>", message: {type: "shutdown_request"})
```
리뷰어 페르소나(`agents/<reviewer>.md` §종료 프로토콜)는 이 요청을 받으면 `shutdown_response{approve:true}` 를 호출해 정상 종료하고, cmux 가 그 pane 을 자동으로 닫는다. graceful 종료는 느릴 수 있음(공식 "Shutdown can be slow").

**② 종료 검증 + 강제 폴백** (자가종료 안 한 리뷰어만 — 소유권 안전) — haiku 래퍼 리뷰어가 간혹 `shutdown_request` 를 prose("종료합니다")로만 응답하고 `shutdown_response` 를 **호출하지 않아 프로세스·pane 이 잔존**하는 경우가 있다(실측 — multi-check 마지막 pane 미닫힘·다음 스킬로의 잔존 직접 원인). graceful 유예 후에도 살아있으면 **본 세션 그 리뷰어 프로세스만** 직접 종료한다:
```bash
TEAM_NAME="session-<id>"      # Lead 가 spawn 결과(@session-<id>)에서 획득 — 본 세션 팀
for R in "$CODEX_REVIEWER_NAME" claude-reviewer gemini-reviewer; do   # 실제 spawn 한 이름(접미 -N 포함) 기준
  # graceful 자가종료를 ~8초 대기. ⚠️ 앵커는 반드시 "--agent-id $R@$TEAM_NAME" (단일 토큰)
  #   — 전역 "--agent-name $R" 은 타 세션 동명 리뷰어/prefix(qa-sql 류)까지 매칭해 오판한다(false-negative).
  for _ in $(seq 1 8); do
    pgrep -f -- "--agent-id $R@$TEAM_NAME" >/dev/null 2>&1 || break
    sleep 1
  done
  # 유예 후에도 생존 = 프로토콜 무시 → 본 세션 그 프로세스만 SIGTERM (cmux 가 pane 자동 close)
  PID=$(pgrep -f -- "--agent-id $R@$TEAM_NAME" 2>/dev/null)
  [ -n "$PID" ] && kill $PID 2>/dev/null && echo "INFO: lingering $R 강제 종료 (pid $PID)"
done
```

**③ orphan pane 정리** (프로세스는 죽었는데 pane 만 남은 경우) — cmux `close-surface` 는 orphan 을 못 닫으므로 tmux 백엔드로 직접 닫는다. **본 세션 team config 의 tmuxPaneId 로만**, 그 pane 이 아직 존재하고 프로세스가 죽은 것만:
```bash
CFG=~/.claude/teams/$TEAM_NAME/config.json
EXIST=$(tmux list-panes -a -F '#{pane_id}' 2>/dev/null)   # 현재 존재하는 pane id 집합
# ⚠️ 본 세션 CFG 멤버 tmuxPaneId 만. 전체 tmux 순회·다른 세션 CFG·와일드카드 절대 금지.
for R in "$CODEX_REVIEWER_NAME" claude-reviewer gemini-reviewer; do   # 실제 spawn 한 이름(접미 -N 포함) 기준
  PANEID=$(python3 -c "import json;d=json.load(open('$CFG'));print(next((m.get('tmuxPaneId','') for m in d['members'] if m['name']=='$R'),''))" 2>/dev/null)
  if [ -n "$PANEID" ] \
     && ! pgrep -f -- "--agent-id $R@$TEAM_NAME" >/dev/null 2>&1 \
     && printf '%s\n' "$EXIST" | grep -qx "$PANEID"; then
    tmux kill-pane -t "$PANEID" 2>/dev/null
  fi
done
```
> ⚠️ cmux 환경의 `tmux` 는 호환 shim 이라 `#{pane_dead}`/`#{pane_pid}` 는 **빈 값**을 반환한다(실측) — pane 생사 판정에 쓸 수 없다. 그래서 ②/③ 는 그 포맷에 의존하지 않고 **세션앵커 `pgrep`(프로세스 생사) + `tmux list-panes`(pane 존재) + `kill-pane`(shim 지원 확인됨)** 으로만 판정한다.

**④ 레이아웃 복원** — 리뷰어 pane 이 다 닫힌 뒤, 남은 Lead 레이아웃을 정렬하고 focus 를 Lead 로 복원한다(다음 스킬·후속 작업이 깔끔한 단일 pane 에서 시작되도록):
```bash
command -v cmux-rebalancing >/dev/null 2>&1 && cmux-rebalancing
cmux focus-pane --pane "$(cmux identify | jq -r .caller.pane_ref)" 2>/dev/null
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
