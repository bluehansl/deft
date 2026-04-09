# multi-check

AI cross-verification plugin that compares answers from Codex (GPT), Claude, and Gemini for synthesized analysis.

## Prerequisites

- **Claude Code** (latest version)
- At least one additional CLI:
  - **Codex CLI**: `npm install -g @openai/codex`
  - **Gemini CLI**: `npm install -g @google/gemini-cli`
- Claude CLI is always available inside Claude Code

## Installation

### From local marketplace

```bash
/plugin marketplace add ~/git/jeongsaehanseul-plugins
/plugin install multi-check@jeongsaehanseul-plugins
```

### From GitHub

```bash
/plugin marketplace add jeongsaehanseul/jeongsaehanseul-plugins
/plugin install multi-check@jeongsaehanseul-plugins
```

## Optional: Enable Agent Teams for parallel execution

Add to `~/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

## Usage

```
/multi-check
```

Or use natural language triggers:
- "multi check this code"
- "cross verify"
- "ask other AIs too"

## Agents

| Agent | CLI | Role |
|-------|-----|------|
| codex-reviewer | Codex (OpenAI) | GPT-based analysis |
| claude-reviewer | Claude CLI | Independent Claude session analysis |
| gemini-reviewer | Gemini CLI | Google Gemini analysis (120s timeout) |

## License

MIT
