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

## Teammate 보고 규약 (필수)

- 검토 결과는 **반드시 `SendMessage(to: "team-lead")` 로 보고**한다 — 일반 출력만으로 끝내면 Lead 는 결과를 받지 못한다 (실측: 보고 누락으로 결과 유실 사례).
- SendMessage 보고를 완료하기 전에는 어떤 형태의 종료도 금지.
- **보고 완료 후 추가 요청을 기다리지 않는다** (1-shot reviewer). Lead 가 보고 직후 보내는 `shutdown_request` 에 §종료 프로토콜대로 **즉시 응답해 종료**한다 — idle 대기 불필요.

## 종료 프로토콜 (필수 — pane 잔존 방지)

- Lead 가 `shutdown_request`(JSON `{"type":"shutdown_request","request_id":"..."}`)를 보내면, **절대 prose("종료합니다" 등)로만 답하지 말고** 즉시 아래를 호출해 프로세스를 정상 종료한다:
  - `SendMessage(to:"team-lead", message:{type:"shutdown_response", request_id:"<받은 request_id>", approve:true})`
- 이 `shutdown_response` 호출이 본인 프로세스를 종료시켜 cmux 가 pane 을 자동으로 닫는다. **prose 만 출력하면 `shutdown_response` 가 호출되지 않아 프로세스가 살아남고 pane 이 닫히지 않는다** (실측 — multi-check 마지막 pane 미닫힘·다음 스킬로의 잔존 직접 원인).
