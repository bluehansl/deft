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
```

Note: Codex reviewer uses `claudex` if installed (preferred), otherwise falls back to `codex`. Command flags are identical; only the entrypoint differs.

- No CLI available: inform the user that at least one CLI is required and stop
- One available: proceed with 2-model comparison (available CLI + Lead)
- Two or more available: proceed with multi-model comparison

Note: Claude CLI is expected to always be available since this runs inside Claude Code.

Important: The Claude CLI agent and Lead (Claude) are the same model but run in independent sessions, so they can provide different perspectives. Both must always be executed — do not skip the Claude CLI agent because the Lead is also Claude.

### Phase 3: Agent Spawn

#### Preferred: Agent Teams (parallel execution)

Try creating a team first:

```
TeamCreate(team_name: "multi-check", description: "AI multi-check")
```

If TeamCreate fails (Agent Teams not enabled):
1. Display: "Agent Teams requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in your settings.json env. Would you like me to enable it?"
2. If user declines, fall back to sequential Agent spawn (see below)

On success, spawn agents in **a single message** (parallel):

Codex reviewer (only if codex is available) — GPT-5.5, reasoning: xhigh:
```
Agent(
  description: "Run Codex CLI analysis (GPT-5.5, xhigh reasoning)",
  prompt: "<composed prompt with context>",
  name: "codex-reviewer",
  subagent_type: "codex-reviewer",
  team_name: "multi-check",
  model: "haiku",
  mode: "dontAsk"
)
```

Claude reviewer (only if claude CLI is available) — Independent Claude session:
```
Agent(
  description: "Run Claude CLI analysis (Claude Opus 4.6, independent session)",
  prompt: "<composed prompt with context>",
  name: "claude-reviewer",
  subagent_type: "claude-reviewer",
  team_name: "multi-check",
  model: "haiku",
  mode: "dontAsk"
)
```

Gemini reviewer (only if gemini is available) — Gemini 3 Flash Preview:
```
Agent(
  description: "Run Gemini CLI analysis (Gemini 3 Flash Preview)",
  prompt: "<composed prompt with context>",
  name: "gemini-reviewer",
  subagent_type: "gemini-reviewer",
  team_name: "multi-check",
  model: "haiku",
  mode: "dontAsk"
)
```

#### Fallback: Sequential Agent spawn

If Teams is not available, spawn agents sequentially with `run_in_background: true`:

Codex reviewer (only if codex is available):
```
Agent(
  description: "Run Codex CLI analysis (GPT-5.5, xhigh reasoning)",
  prompt: "<composed prompt>",
  name: "codex-reviewer",
  subagent_type: "codex-reviewer",
  model: "haiku",
  mode: "dontAsk",
  run_in_background: true
)
```

Claude reviewer (only if claude CLI is available):
```
Agent(
  description: "Run Claude CLI analysis (Claude Opus 4.6, independent session)",
  prompt: "<composed prompt>",
  name: "claude-reviewer",
  subagent_type: "claude-reviewer",
  model: "haiku",
  mode: "dontAsk",
  run_in_background: true
)
```

Gemini reviewer (only if gemini is available):
```
Agent(
  description: "Run Gemini CLI analysis (Gemini 3 Flash Preview)",
  prompt: "<composed prompt>",
  name: "gemini-reviewer",
  subagent_type: "gemini-reviewer",
  model: "haiku",
  mode: "dontAsk",
  run_in_background: true
)
```

#### Lead (Claude) Analysis

While agents are working, the Lead performs its own analysis on the same question.

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

After output, send shutdown to teammates:
```
SendMessage(to: "codex-reviewer", message: {type: "shutdown_request"})
SendMessage(to: "claude-reviewer", message: {type: "shutdown_request"})
SendMessage(to: "gemini-reviewer", message: {type: "shutdown_request"})
```

## Error Handling

| Scenario | Action |
|----------|--------|
| CLI not installed | Skip that model, proceed with remaining |
| API error (ModelNotFoundError, etc.) | Skip that model, note in results |
| Timeout (agent doesn't respond in 120s) | Synthesize with available results |
| All CLIs fail | Compare Lead analysis against error context |
| TeamCreate fails | Show activation guide, fallback to sequential Agent |

## Prompt Composition Rules

| Request Type | Context to Include |
|-------------|-------------------|
| Code review | git diff + relevant file contents |
| Architecture question | Project structure + key config files |
| Bug analysis | Error logs + related code |
| General technical question | Question only |
