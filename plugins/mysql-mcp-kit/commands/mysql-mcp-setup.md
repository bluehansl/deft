---
description: mysql-mcp-kit 초기 설정 — 래퍼 배치, 크리덴셜 입력 안내, MCP 서버 등록(Claude/Codex), 권한·감사훅·AGENTS.md 가이드까지 대화형으로 진행
---

# mysql-mcp-kit 설정

사용자의 MySQL 환경을 benborla MCP로 안전하게 조회하도록 구성한다. **실제 접속값(주소/계정/비번/DB명)은 반드시 사용자에게 물어보거나 사용자가 직접 파일에 입력**하게 하고, 임의로 채우지 않는다.

플러그인 루트: `${CLAUDE_PLUGIN_ROOT}`

## 단계

1. **래퍼·감사스크립트 배치**
   - `${CLAUDE_PLUGIN_ROOT}/bin/mysql-mcp` → `~/.local/bin/mysql-mcp` (복사, `chmod +x`).
   - `${CLAUDE_PLUGIN_ROOT}/bin/db-audit-log` → `~/.local/bin/db-audit-log` (복사, `chmod +x`).

2. **크리덴셜 파일 생성 + 사용자 입력**
   - `~/.config/mysql-mcp/` 생성(`chmod 700`), `${CLAUDE_PLUGIN_ROOT}/templates/credentials.template` → `~/.config/mysql-mcp/credentials`(없을 때만, `chmod 600`).
   - 사용자에게 **환경 목록**을 물어본다(자유 정의 — 예: dev/stg/prod). 각 환경마다 `host/port/user/pass/db`와 **쓰기 허용 여부(write=true)**를 받는다.
   - ⚠️ **비밀번호 등 실제값은 사용자가 직접 파일에 넣게** 안내하거나 사용자 입력을 받아 기록. 절대 임의값 금지. `db=`는 필수(빈 값 금지).

3. **MCP 서버 등록** (사용자가 정의한 환경마다, 서버명은 `mysql-<env>` 권장)
   - Claude: `claude mcp add mysql-<env> -s user -- ~/.local/bin/mysql-mcp <env>`
   - Codex: `~/.codex/config.toml` `[mcp_servers.mysql-<env>]` (command=`~/.local/bin/mysql-mcp`, args=[env]). **env 블록/secret 없음**. 백업 후 merge.

4. **쓰기 환경 게이팅** (write=true 인 환경만)
   - Claude: 프로젝트 `disabledMcpServers`에 추가 + `~/.claude/settings.json` `permissions.ask`에 `mcp__mysql-<env>`. 읽기 환경은 `permissions.allow`.
   - Codex: `[mcp_servers.mysql-<env>]`에 `enabled=false` + `default_tools_approval_mode="prompt"`.

5. **감사 훅** (선택) — `~/.claude/settings.json` `hooks.PostToolUse`에 matcher `mcp__mysql-.*` → `~/.local/bin/db-audit-log`.

6. **AGENTS.md 가이드** — `${CLAUDE_PLUGIN_ROOT}/templates/agents-snippet.md` 내용을 사용자의 지침 파일(예: 프로젝트 AGENTS.md)에 추가하도록 안내.

7. **검증** — Claude `claude mcp list` / Codex `codex mcp list`로 등록 확인. 읽기 환경 하나로 `SELECT 1` 조회 테스트(읽기전용).

각 단계 전 사용자에게 무엇을 할지 알리고, 실제값 입력은 사용자 확인 하에 진행한다.
