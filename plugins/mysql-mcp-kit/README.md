# mysql-mcp-kit

MySQL(Aurora/MariaDB 포함)을 **benborla MCP**(`@benborla29/mcp-server-mysql`)로 안전하게 조회하는 셋업 키트. Claude Code · Codex 공용.

## 무엇을 주나

- **환경별 접속을 크리덴셜 파일로 관리**(자유 정의). 접속값은 각자 로컬에 입력 — 이 플러그인엔 실제값 없음.
- **읽기 전용 기본** + `write=true` 섹션만 쓰기 허용(DDL은 항상 차단). AST 파싱 + DB세션 READ ONLY 다중 방어.
- **쓰기 승인 게이트**(기본 disabled + 호출마다 승인).
- **`db-access` 스킬** — DB 조회 지침·제약을 단일 소스로 제공.
- **감사 로그**(선택, Claude) — 실행 SQL·메타를 로컬에 기록.

## 설치

1. 마켓플레이스에서 `mysql-mcp-kit` 설치.
2. `/mysql-mcp-setup` 실행 — 래퍼 배치, 크리덴셜 입력 안내, MCP 서버 등록(Claude/Codex), 권한·감사훅·AGENTS.md 가이드까지 대화형 진행.
3. 크리덴셜(`~/.config/mysql-mcp/credentials`)에 **자기 환경의 주소/계정/비번/DB명**을 입력.
4. DB 조회 시 `db-access` 스킬이 접속 지침·제약을 안내.

## 구성 요소

| 파일 | 역할 |
|---|---|
| `bin/mysql-mcp` | 환경별 MCP 기동 래퍼(데이터 구동 — `write=true` 섹션만 쓰기) |
| `bin/db-audit-log` | 감사 로그 스크립트(PostToolUse 훅용) |
| `skills/db-access/` | 조회 지침(`SKILL.md`) + 설치 런북(`README.md`) |
| `commands/mysql-mcp-setup.md` | `/mysql-mcp-setup` 대화형 설치 |
| `templates/` | 크리덴셜 템플릿 + AGENTS.md 가이드 조각 |

## 보안 원칙

- **실제 접속값(주소/계정/비번/DB명)은 절대 커밋하지 않는다** — 로컬 크리덴셜 파일(600)에만.
- 운영 등 민감 환경은 DB 계정 자체를 SELECT 전용으로 두는 것을 권장.
- `MYSQL_DISABLE_READ_ONLY_TRANSACTIONS`·DDL은 켜지 않는다.

상세: `skills/db-access/README.md`(런북).
