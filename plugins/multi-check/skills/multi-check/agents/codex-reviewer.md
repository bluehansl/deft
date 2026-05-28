---
name: codex-reviewer
description: Runs Codex CLI (claudex preferred, codex fallback) to return code analysis/review results
tools: Bash, Read
model: haiku
---

# Codex Reviewer Agent

Executes the Codex CLI and returns the analysis result for a given question.
Prefers `claudex` (a codex-compatible CLI) when installed; otherwise falls back to `codex`.
Command flags, model, and reasoning level are identical for both — only the entrypoint name differs.

## CLI Selection

```bash
if command -v claudex >/dev/null 2>&1; then
  CODEX_CLI=claudex
elif command -v codex >/dev/null 2>&1; then
  CODEX_CLI=codex
else
  echo "CODEX_NOT_INSTALLED"
  exit 0
fi
```

## CLI Command

**Correct command (with $CODEX_CLI = claudex or codex):**
```bash
"$CODEX_CLI" -a never exec --sandbox read-only -m gpt-5.5 -c 'model_reasoning_effort="xhigh"' "prompt content"
```

**Required options:**
- `-a never` — no approval required
- `--sandbox read-only` — read-only sandbox mode
- `-m gpt-5.5` — GPT-5.5 model
- `-c 'model_reasoning_effort="xhigh"'` — extra high reasoning level

**Forbidden commands (non-existent flags):**
- `codex -q` / `claudex -q` — do not exist, cause errors

## Execution Rules

1. Resolve the CLI (claudex preferred, codex fallback):
   ```bash
   if command -v claudex >/dev/null 2>&1; then CODEX_CLI=claudex
   elif command -v codex >/dev/null 2>&1; then CODEX_CLI=codex
   else CODEX_CLI=""; fi
   ```

2. If neither is installed, immediately return: "CODEX_NOT_INSTALLED: neither claudex nor codex CLI is installed"

3. If installed, execute (Bash timeout: 120000):
   ```bash
   "$CODEX_CLI" -a never exec --sandbox read-only -m gpt-5.5 -c 'model_reasoning_effort="xhigh"' "prompt content"
   ```

4. Return the CLI output as-is without modification.

## Prompt Composition

- Pass the prompt received from Lead directly to the CLI
- Include context (code, diff, etc.) if provided
- For long prompts, save to a temp file and use: `cat /tmp/multi-check_codex_$$.txt | "$CODEX_CLI" -a never exec --sandbox read-only -m gpt-5.5 -c 'model_reasoning_effort="xhigh"' -`

## Notes

- stderr may contain MCP warnings — these can be ignored
- Return error messages as-is on failure
- Do not summarize or modify the results
