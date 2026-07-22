---
name: db-access
description: "MySQL(Aurora/MariaDB) DB 접속·조회 전용 지침. DB 조회·SQL 실행·데이터 확인·mysql MCP 사용 시 반드시 먼저 확인. 환경별 접속 방식과 쓰기(write=true 환경) 승인 규칙 등 강한 제약을 소유한다."
metadata:
  version: 0.1.0
  category: "database"
---

# db-access — MySQL DB 접속·조회 지침

> **트리거**: DB 조회·접속·SQL 실행·데이터 확인이 필요하면 **이 스킬을 먼저 확인**한 뒤 진행한다. 접속 구성·환경별 정책·제약을 이 스킬이 단일 소스로 소유한다.

DB 접근은 **mysql MCP**(benborla `@benborla29/mcp-server-mysql`, 버전 핀)로 한다. 각 환경은 도구 `mcp__<서버명>__mysql_query`(인자 `sql`)로 조회한다.

## 1. 환경·서버 (사용자 정의)

환경은 크리덴셜 파일 `~/.config/mysql-mcp/credentials`의 `[섹션]`으로 **사용자가 자유 정의**한다. 각 섹션 = MCP 서버 하나(`mysql-<섹션명>` 등 등록한 이름).

| 크리덴셜 섹션 | 쓰기 | 조회 도구 |
|---|---|---|
| `write` 플래그 **없음** | ❌ 읽기전용 (benborla 기본 차단 + READ ONLY 세션 + AST 파싱으로 쓰기·DDL 거부) | `mcp__<서버>__mysql_query` |
| `write=true` | ⚠️ INSERT/UPDATE/DELETE 허용 (DDL은 차단) | 동일 (아래 §2 승인 규칙 적용) |

- **현재 등록된 서버 목록**은 `mcp mcp list`(Claude `/mcp`, Codex `codex mcp list`) 또는 크리덴셜 파일에서 확인.
- 읽기 서버는 benborla가 쓰기·DDL을 실행 자체를 막는다. **운영 등 민감 환경은 DB 계정 자체를 SELECT 전용으로** 두면 이중 안전.

## 2. ⚠️ 쓰기(`write=true`) 환경 — 강한 제약 (필수)

`write=true` 환경은 실제로 쓰기가 나가는 경로다. 다음을 반드시 지킨다:

1. **사용자의 명시적 승인 없이 쓰기 쿼리를 실행하지 않는다.** 승인은 "이 환경에 이 쿼리를 실행해도 된다"는 직접·명시 동의. 추정·암묵 동의 금지.
2. 특히 **운영(production)** 데이터 변경은 원칙적으로 정식 절차(배포 SQL·DBA·리뷰)로 처리하고, AI 세션 직접 쓰기는 **예외적 상황에서만** 사용자 승인 하에.
3. 쓰기 전 반드시 **영향 범위**(대상 테이블·행 수·롤백 방법)를 사용자에게 제시하고 승인받는다.
4. 쓰기 환경은 **기본 disabled + 호출마다 승인**(Claude: `disabledMcpServers`+`ask` / Codex: `enabled=false`+`default_tools_approval_mode="prompt"`)으로 게이트한다 — 본 규칙은 그 위의 명시적 권고(다중 방어).

## 3. 자격증명·구성

- **기동 래퍼**: `~/.local/bin/mysql-mcp <env>` — 크리덴셜에서 읽어 env 주입 후 benborla 기동. `write=true` 섹션만 DML 허용.
- **자격증명 파일**: 단일 INI `~/.config/mysql-mcp/credentials` (`[env]` 섹션별 `host/port/user/pass/db` [+ `write`], mode 600). MCP 등록 설정(`~/.claude.json`·`~/.codex/config.toml`)에는 비밀을 남기지 않는다.
- **DB명 `db=` 필수** — 빈 값 금지(benborla multi-DB 모드 방지). 다른 DB가 필요하면 해당 섹션의 `db=`만 변경.
- **비밀번호 갱신**: 크리덴셜 파일의 해당 `[env]` 섹션을 편집(비밀 관리처에서 값을 가져와 수동 입력).

## 4. 사용 흐름

1. **기본**: 읽기 환경은 자동 연결(읽기전용). 쓰기 환경은 기본 disabled → 필요 시 명시적 enable.
2. DB 조회 → `mcp__<서버>__mysql_query`로 SELECT 실행.
3. **쓰기가 필요하면** → §2 절차(승인·영향범위 제시)를 거친 뒤, 해당 쓰기 환경을 enable하고 사용.

## 5. 감사·참고 (설치 시 활성화된 경우)

- **감사 로그**(Claude Code, 훅 설치 시): PostToolUse 훅 → `~/.ai/db-audit/YYYY-MM.jsonl` (SQL·메타만 기록, 조회 결과 rows 미기록).
- **구성·설치·재현·롤백**: 이 스킬 디렉토리의 `README.md`(setup 런북) 참조.
