# multi-check

AI multi-check plugin that compares answers from Codex (GPT), Claude, and Gemini for synthesized analysis.

## Prerequisites

- **Claude Code** (latest version)
- At least one additional CLI:
  - **Codex CLI**: `npm install -g @openai/codex`
  - **Claude CLI**: `npm install -g @anthropic-ai/claude-code`
  - **Gemini CLI**: `npm install -g @google/gemini-cli`

## Installation

```bash
/plugin marketplace add bluehansl/bluehansl-plugins
/plugin install multi-check@bluehansl-plugins
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

## How It Works

Checks installed CLIs at runtime. Uninstalled CLIs are skipped automatically — only available agents are used for analysis. At least one CLI must be installed.

## Agents

| Agent | Model | Role |
|-------|-------|------|
| codex-reviewer | GPT-5.4 (xhigh reasoning) | OpenAI Codex CLI analysis |
| claude-reviewer | Claude Opus 4.6 (independent session) | Independent Claude CLI analysis |
| gemini-reviewer | Gemini 3 Flash Preview (120s timeout) | Google Gemini CLI analysis |

## License

Personal use only
