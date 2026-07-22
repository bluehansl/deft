# db-access — 구성·재현 런북 (setup runbook)

> 설치·구성·재현·감사용. 일상 DB 조회 지침은 `SKILL.md`(스킬 트리거 자동 로드), 이 README는 자동 로드되지 않는다.
>
> **실제 접속값(주소/계정/비번/DB명)은 이 문서·플러그인 어디에도 넣지 않는다 — 각 사용자가 로컬 크리덴셜 파일에만 입력한다.**

## 1. 구성 요소

| 구성 | 위치 | 역할 |
|---|---|---|
| MCP 패키지 | `@benborla29/mcp-server-mysql@2.0.9`(버전 핀) | stdio MySQL MCP. AST 쓰기차단 + READ ONLY 세션 + multipleStatements=false 다중 방어 |
| 기동 래퍼 | `~/.local/bin/mysql-mcp <env>` | 크리덴셜에서 읽어 env 주입 후 benborla 기동. `write=true` 섹션만 쓰기 허용 |
| 자격증명 | `~/.config/mysql-mcp/credentials`(INI, 600) | `[env]` 섹션별 `host/port/user/pass/db`(+`write`). MCP 등록 설정엔 비밀 0 |
| 감사(선택) | `~/.local/bin/db-audit-log` + PostToolUse 훅 | `~/.ai/db-audit/YYYY-MM.jsonl`(SQL·메타만) |
| 스킬 | `db-access/SKILL.md` | 조회 지침 |

## 2. 자격증명 포맷

`~/.config/mysql-mcp/credentials`(mode 600). 섹션([이름]) = 환경 = MCP 서버 하나(자유 정의):
```ini
[myenv]
host=<호스트>
port=3306
user=<계정>
pass=<비밀번호>       # pass= 뒤 전체가 값
db=<DB명>             # 필수 — 빈 값 금지(multi-DB 모드 방지)
# write=true          # 있으면 이 환경만 INSERT/UPDATE/DELETE 허용(DDL 차단)
```
- **DB명(`db=`)도 환경별 관리** — 다른 DB가 필요하면 해당 섹션의 `db=`만 변경(래퍼 코드 수정 불요).
- 비밀번호 갱신 = 이 파일의 해당 섹션 편집.

## 3. 설치 (요약 — 상세는 `/mysql-mcp-setup` 커맨드가 대화형으로 진행)

1. 래퍼·감사스크립트 → `~/.local/bin/`(chmod +x).
2. 크리덴셜 파일 생성(600) + **환경별 실제값 입력**(사용자).
3. 환경마다 MCP 서버 등록 — Claude `claude mcp add mysql-<env> -s user -- ~/.local/bin/mysql-mcp <env>` / Codex `[mcp_servers.mysql-<env>]`.
4. 쓰기 환경 게이팅 — Claude `disabledMcpServers`+`ask` / Codex `enabled=false`+`default_tools_approval_mode="prompt"`. 읽기 환경은 allow/자동 enable.
5. (선택) 감사 훅 matcher `mcp__mysql-.*` → `db-audit-log`.
6. AGENTS.md 조각 추가(`templates/agents-snippet.md`).

## 4. 검증

```bash
claude mcp list | grep mysql       # Claude
codex mcp list  | grep mysql       # Codex
# MCP 프로토콜 직접(읽기전용 확인): initialize→tools/call(mysql_query,"SELECT 1")
```

## 5. 롤백 / 제거

```bash
# 등록 서버마다: claude mcp remove mysql-<env>  /  Codex config 의 [mcp_servers.mysql-<env>] 제거
# settings.json allow/ask/PostToolUse, .claude.json disabledMcpServers 정리
rm ~/.config/mysql-mcp/credentials    # 로컬 자격증명(평문)
```

## 6. 안전 주의

- **`MYSQL_DISABLE_READ_ONLY_TRANSACTIONS` 설정 금지** — DB세션 READ ONLY 2차 방어선 제거(위험).
- **DDL(`ALLOW_DDL_OPERATION`)** 은 래퍼가 어떤 환경에서도 켜지 않음(DROP/TRUNCATE 위험).
- **`db=` 빈 값 금지** — benborla multi-DB 모드(계정이 보는 모든 DB)로 빠짐. 생략(줄 없음)은 래퍼가 에러로 막음.
- 운영 등 민감 환경은 **DB 계정 자체를 SELECT 전용**으로 두면 소프트웨어+계정 이중 안전.
