# Changelog

이 파일은 deft 플러그인의 모든 주목할 만한 변경 사항을 기록합니다.

형식은 [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/) 를 따르며, 버전 체계는 [Semantic Versioning](https://semver.org/lang/ko/) 을 사용합니다 (`claude-X.Y.Z` / `codex-X.Y.Z` 접두).

## [claude-2.2.1] - 2026-06-10

### Added
- **agent-teams 팀원 모델 명시 복원** — teams-porter 가 프로젝트-중립 일반화 과정에서 제거한 모델 표기를 복구. 모든 팀원은 **Claude Fable 5 (`claude-fable-5`)** 로 통일 — 동질 시각, 컨벤션 강제 일관.
  - `agents/*.md` 8종(architect/backendDev/designer/frontendDev/lead/pm/qa/reviewer) 각 페르소나 본문 시작부에 모델 메타 라인 삽입 (`> **모델**: Claude Fable 5 (\`claude-fable-5\`) — Agent tool 호출 시 alias \`fable\``).
  - `SKILL.md` §2 도입부에 팀원 모델 한 줄 요약 + §4-3 spawn 템플릿에 **Agent 도구 호출 인자** 섹션 신규: `model: "fable"` alias 사용 명시 (Agent tool enum 제약: `sonnet`/`opus`/`haiku`/`fable` — 구체 ID 직접 지정 불가).

### Notes
- 본 버전은 모델 명시 복원. 동작 호환성 유지 (PATCH bump).
- `~/git/AGENTS.md` + `~/git/AGENTS.teams.md` 의 "Claude opus" 표기 24군데도 동일 패턴으로 갱신 (Lead 환경 본업 정책 — 별도 repo).

## [codex-1.1.3] - 2026-06-10

### Fixed
- **multi-check (Codex) Bash CLI fallback 의 claude reviewer 모델 ID 갱신** — `plugins/codex/deft/skills/multi-check/SKILL.md:170` 의 `claude --model claude-opus-4-6` → `claude --model claude-fable-5` (신규 모델 반영).

## [codex-1.1.2] - 2026-06-09

### Fixed
- **restore-statusline SKILL.md YAML frontmatter 파싱 실패 정정** — `description` 값이 백틱(`)으로 시작하여 YAML plain scalar 파서 에러(`found character that cannot start any token at line 2 column 14`). 이 오류로 codex 시작 시 "Skipped loading 1 skill(s) due to invalid SKILL.md files." 경고 + restore-statusline skill 로드 실패. description 본문에서 백틱 제거 (의미 동일 유지).

## [codex-1.1.1] - 2026-06-09

### Fixed
- multi-round Codex SKILL Phase 2 등록 확인 명령 (`codex --list-tools` → `codex mcp list`)
- multi-round Codex SKILL Phase 3-C 1-shot 실행 옵션 (`exec --no-tui` → `exec - < <file>`)

### Changed
- multi-round 자동 분기 우선순위 정정 — cmux 환경 안에서는 3-B (pane) 우선, 외부에서만 3-A (MCP) / 3-C (codex 내부)
- Phase 0 ↔ Phase 2 claudex 강제 모순 정리 — codex-only 환경에서의 3-A 가용성 명시
- "MCP 경유 ↔ cmux 제어" 표현 통일 — 경로별 의존성 명확 분리
- frontmatter description 간결화 (2~4 문장)

### Added
- **`plugins/codex/deft/bin/cmux-rebalancing` 동봉** — Claude 측과 동일 헬퍼 (pane 비율 자동 조정).
- **Codex 측 multi-round / multi-check SKILL 에 헬퍼 설치 확인 + spawn 직후 호출 명시** — `~/.codex/plugins/cache/bluehansl-codex/deft/.../bin/cmux-rebalancing` 우선 탐색 후 `~/.local/bin/` 으로 자동 복사. Phase 3-B-fin / reviewer spawn 직후 `cmux-rebalancing` 호출.
- **Codex GUIDE Before You Start 에 헬퍼 항목 추가**.

### Removed
- broker / agent-relay / relaycast / 외부 cloud 송신 관련 표현 전수 제거 — multi-round 자체가 외부 호출을 만들지 않으므로 불필요한 잡음
- cmux search.db 권한·purge 관련 가드 — multi-round 책임 영역 외 (cmux 자체 부산물)

## [claude-2.2.0] - 2026-06-09

### Added
- **agent-teams 스킬 신규** — `plugins/deft/skills/agent-teams/` 작성. Claude Code 내장 팀 기능 기반의 다중 에이전트 팀 운영 지침을 **자기완결적 skill 패키지**(SKILL.md + `agents/*.md` 8종 + `GUIDE.md`)로 제공. 외부 참조 없이 패키지만으로 운영 가능.
  - **내장 도구 기반** — `TeamCreate`/`Agent`/`SendMessage`/`Task*` 4종만 사용. `SendMessage` 자동 전달로 별도 폴링·inbox 수동 확인 불필요.
  - **Phase 0 환경 검증** — 실험 플래그(`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`)·Claude Code v2.1.32+·`cmux claude-teams` 확인. cmux 외부 실행 시 단일 Claude degrade(기본) / 재시작 권장 / 명시 요청 시 시각화 비활성 진행. 운영 제약 4종(한 lead=한 team / nested 불가 / in-process resume 불가 / task status lag) 명시.
  - **work-id 영속 키 + 연속성** — 내장 `team-name`(휘발 가능)과 분리한 영속 작업 키. 같은 work-id면 세션 재시작·새 team-name에도 동일 `work.md`를 이어받아 연속성·누락 방지(in-process resume 한계 보완). 작업 데이터는 `~/.claude/plugin-data/deft/agent-teams/<work-id>/`.
  - **work-id 명명 규약 자가 결정** — 최초 실행 시 사용자에게 규약 선택(이슈번호/브랜치명/날짜-작업명/자유명/직접입력) → `config.json` + `CONVENTION.md`(plugin-data, update-safe)에 저장. 특정 규약 강요 없이 범용. "규약 바꿔"로 재설정.
  - **페르소나 라이브러리** — `agents/*.md` 8종(lead/backendDev/frontendDev/qa/designer/architect/reviewer/pm). 프로젝트-중립 일반화(프로젝트 컨벤션은 cwd AGENTS.md 참조).
  - **회의 모드 6종 + 페어/Trio 패턴** — consult/dialogue/collaborate/debate/cascade/signoff. 신호 프로토콜을 `SendMessage` 본문 규약으로 표현. `multi-round collaborate`(검토·설계·리뷰)와 agent-teams(실제 코드 작업) 경계 및 승격 규칙 명시.
  - 단계 게이트(요건분석/영향도/Plan/체크리스트)·Plan 게이트·diff 검증·파일 구조(work.md/team.md/role.md)·GUIDE.md(Before You Start 체크리스트 포함). work.md는 Lead 단독 writer, 팀원(qa 포함)은 본인 role.md만 write. 팀 종료는 자연어 지시로 처리.

### Fixed
- **multi-round (Claude) Phase 2 등록 확인 명령** — `which mcp__claudex__codex` (MCP tool 이름을 PATH 실행파일로 잘못 검사) → `claude mcp get claudex` 로 정정.

### Changed
- **multi-round (Claude) spawn 경로 자동 분기** — cmux 환경 안에서는 **Phase 3-B (pane 시각화) 우선**, cmux 외부에서만 Phase 3-A (MCP) 사용. 사용자 정책 (cmux 환경: pane / 외부: background) 반영. Phase 0 에 `HAVE_CMUX` 검출 추가, Phase 3 도입부에 환경별 분기 표 신규.
- **multi-round (Claude) Phase 0 ↔ Phase 2 claudex 강제 모순 정리** — codex-only 환경에서의 3-A 가용성 / 3-B fallback 명시.
- **multi-round (Claude) "MCP 경유 ↔ cmux 제어" 표현 통일** — 3-A=MCP cmux 무관 / 3-B=cmux 필요 / 3-C 분기를 본문·README·페르소나에서 일관.
- **multi-round (Claude) frontmatter description 간결화** — 트리거 어휘 대량 나열 + 비교를 압축, 2~4 문장 + 대표 트리거 7개로 축소.
- **3-도구 비교표 의존성 칸** — `multi-round` 의존성 표현을 "cmux 환경: pane / cmux 외부: MCP" 로 갱신. `multi-round collaborate` ↔ `agent-teams` 경계 한 줄 추가 (검토·설계는 multi-round, 실제 코드 작업은 agent-teams).
- **공식 MCP 등록 명령 병기** — `claude mcp add-json --scope user claudex '{...}'` 스니펫 추가.

### Removed
- **multi-round (Claude) Phase 0 의 `/etc/hosts` cloud 차단 확인 블록** — multi-round 자체가 외부 호출을 만들지 않으므로 책임 영역 외. 잡음 제거.
- **multi-round (Claude) 보안 가드 표 정리** — `cmux search.db 권한 600` / `agent-relay 영구 삭제 금지` / "외부 cloud 검사" 행 삭제. 가드 8개 → 6개 (참가자 CLI / MCP 컨텍스트 격리 / cmux send sanitize / settings.json write 금지 / 환경 진단 / `cmux identify` 사용).
- **multi-round (Claude) `5-C cmux search.db 잔존 처리` 섹션** — `chmod 600 search.db*` 권장 통째 삭제. cmux 자체 부산물이므로 skill 책임 영역 외.
- **multi-round (Claude) GUIDE FAQ Q5 (broker 관계) / Q8 (외부 송신 zero) 삭제** — 잡음 제거 + Q 번호 재정렬.
- **multi-round (Claude) agents/*-participant.md 의 "본업 코드 외부 송신 금지 / search.db 잔존 가능성" 라인 삭제**.
- **README (Claude) "broker 무관" 표현 제거** — multi-round 행 + 3-도구 비교표 의존성 칸.

### Added (cmux-rebalancing 헬퍼 통합)
- **`plugins/deft/bin/cmux-rebalancing` 동봉** — pane 비율 자동 조정 헬퍼. 좌→우 정책 비율(2컬럼=60:40 / 3컬럼=40:30:30 / 4컬럼=25:25:25:25 / 5+=균등) 또는 사용자 명시 비율(`cmux-rebalancing 7:3`) 적용.
- **각 skill Phase 0 에 헬퍼 설치 확인 + 자동 cp**: `~/.local/bin/cmux-rebalancing` 미존재 시 plugin cache(`~/.claude/plugins/cache/.../bin/cmux-rebalancing`)에서 자동 복사 + `chmod +x`.
- **첫 pane 분할 직후 Lead 가 `cmux-rebalancing` 1회 직접 호출** — multi-round Phase 3-B-fin / agent-teams §2-3 / multi-check Phase 3. 호출 시점은 **첫 워커/팀원의 우측 분할 직후** (마지막 워커 spawn 까지 기다리지 않음). 두 번째 이후 워커는 같은 우측 컬럼 안에서 하단 수직 분할되므로 좌우 비율 유지 — 추가 호출 불필요. Lead pane 가독성 보장 (2:8 축소 방지).
- **GUIDE Before You Start 에 헬퍼 항목 추가** — multi-round Claude/Codex + agent-teams.

### Notes
- 신규 skill 추가 + multi-round 동급 release notes + cmux-rebalancing 헬퍼 통합 → MINOR bump (claude-2.1.3 → claude-2.2.0). Codex 측은 별도 [codex-1.1.1] entry.

## [codex-1.1.0] - 2026-06-08

### Added
- **multi-round 스킬 Codex 포팅** — `plugins/codex/deft/skills/multi-round/` 신규 작성. Claude 측 동일 워크플로 + Codex 환경 차이 반영.
  - 작업 디렉토리 경로: `~/.codex/plugin-data/deft/multi-round/`
  - MCP 등록 위치: `~/.codex/config.toml [mcp_servers.claudex]` (Claude 측 `settings.json mcpServers` 대응)
  - **Phase 3-C 신규** — cmux 외부 환경 fallback. codex가 background process로 worker (`claudex` 우선, 없으면 `codex`) 동시 spawn → 응답 파일 캡처 → history 누적으로 양방향 모사. stateless라 max-round 5 권장.
  - **cmux 환경 자동 검출** (Phase 0): `HAVE_CMUX` 값으로 3-B (pane) / 3-C (codex 내부) 자동 분기.
  - worker CLI 우선순위: cmux 내 pane 띄울 때 **claudex 우선, 없으면 codex** (사용자 정책 §5-2).
- **Codex README** — `multi-round` 항목 + 사용자 데이터 경로 컨벤션 추가.

### Notes
- Codex 측은 첫 다중 skill 진입이라 MINOR bump (codex-1.0.0 → codex-1.1.0).
- 사용자 데이터 경로 `~/.codex/plugin-data/deft/<skill>/` 컨벤션은 Codex README에 명시.

## [claude-2.1.3] - 2026-06-08

### Changed
- **multi-round 작업 디렉토리 경로 재정정** — `~/.agents/skills/multi-round/` → **`~/.claude/plugin-data/deft/multi-round/`** 로 변경. plugin cache 영역과 사용자 데이터 영역을 명확히 분리하기 위함.
- **SKILL.md / GUIDE.md 톤 정리** — 사용자 입장에서 불필요한 히스토리 톤(plugin cache 위험성 설명 등) 제거. 최종 사용자는 "데이터·세션·hooks는 다음 경로에 저장" 한 줄로 충분.
- **README.md (plugin 루트)** — "사용자 데이터 경로 컨벤션" 섹션 신규 추가. deft 플러그인 차원에서 모든 스킬 공통 경로 패턴(`~/.claude/plugin-data/deft/<skill>/`) 명시.
- **사용자 환경 데이터 이전** — `~/.agents/skills/multi-round/` → `~/.claude/plugin-data/deft/multi-round/`. 7개 transcript (`sessions/20260605-1735-design/`) 포함 보존.

### Notes
- 본 버전은 경로 표준 정정 + 문서 톤 정리. 동작 호환성 유지 (PATCH).

## [claude-2.1.2] - 2026-06-08

### Changed
- **multi-round 작업 디렉토리 표준화** — skill 실행 시 사용하는 세션·메타·hooks 경로를 `/tmp/multi-round-session/` → **`~/.agents/skills/multi-round/`** 하위로 통일. 다른 사용자 skill들과 일관된 구조 (예: `~/.agents/skills/agent-relay/`).
  - 새 구조: `sessions/<YYYYMMDD-HHMM-tag>/` (회의별 transcript) + `state/` (영구 메타) + `hooks/` (동작 훅)
  - SKILL.md: 작업 디렉토리 표준 섹션 신규 추가 + Phase 4-A 예시 경로를 `$SESSION_DIR` 변수로 변경
  - GUIDE.md: Before You Start에 작업 디렉토리 안내 추가 + Examples 9-5 메타 transcript 경로 갱신
- **상충 정정 (SKILL.md)** — 이전 2.1.1에서 Phase 0 외부 cloud lsof 체크 제거했으나 보안 가드 #1 + Error Handling에 잔존 표기가 있었던 부분 정정:
  - 보안 가드 #1: "Phase 0 preflight 통과 (외부 cloud 송신 0)" → "Phase 0 참가자 CLI 1개 이상 설치 확인"
  - Error Handling: "외부 cloud 연결 발견 (Phase 0) → abort" 제거 + 참가자 CLI 매트릭스 재정렬

### Notes
- 본 버전은 경로 표준화·문서 일관성 정정. 동작 호환성 유지 (PATCH).
- `/tmp/multi-round-session/` 임시 데이터는 사용자 환경에서 `~/.agents/skills/multi-round/sessions/<timestamp>/`로 이동 (개인 메타).

## [claude-2.1.1] - 2026-06-08

### Changed
- **multi-round Phase 0 Preflight 단순화** — 외부 cloud 송신 lsof 체크 제거. multi-round skill 자체는 외부 호출을 만들지 않으므로 본 검사는 skill 책임 영역 밖 (`~/AGENTS.md §5-0` cloud 차단 정책 적용자의 환경에서 자동 보호됨). Chrome 등 무관한 시스템 트래픽 false positive 제거.
- **참가자 양방향 + mix 기본** — claudex 단독 확인 → **claude + claudex(또는 codex) 양쪽 검사**. mix가 default. 한쪽만 설치된 환경에서도 그 쪽만으로 진행 (graceful fallback). 양쪽 모두 Lead가 될 수 있음 명시.
- **양방향 통신 컨셉 명확화 (§Phase 2)** — MCP server는 항상 claudex가 띄움. Lead가 Claude이든 Claudex이든 동일한 MCP를 경유. **cmux나 Claude 팀 기능에 종속 X — multi-round는 자체 MCP 채널로 독립 동작**.
- **회의 모드 사용자 선택 메뉴 추가** — consult/dialogue/collaborate/debate 각 모드의 1줄 설명을 함께 노출. 사용자가 1~4 입력으로 선택. 명시 없으면 기본 dialogue.
- **라운드 게이트 자동 진행 (§Phase 4-C)** — 라운드 종료마다 사용자에게 묻는 방식 제거. **기본 종료 조건 = '모든 AI 합의 (CONSENSUS)' 또는 '사용자 개입'**. Lead는 사용자에게 묻지 않고 자체적으로 라운드 계속. 사용자가 자발 개입(메시지) 하면 즉시 반영. 명시적 종료 조건 변경 요청 시에만 교체.
- **3-도구 멘탈 모델 강화** — multi-check (1회성 fan-out, MCP 무관) / **multi-round (지속 N라운드, MCP 경유, cmux·팀기능 무관)** / Agent Teams (Claude끼리, Claude 팀 기능 베이스, MCP 불필요) 명확히 구분.
- **도구 선택 기준 — 사용자 입력 예시 매핑 표 추가** — "토론해서 정해" → multi-round / "GPT랑 Claude 답 비교" → multi-check / "BE·FE·QA 분담" → Agent Teams 등.
- **agents/codex-participant.md + claude-participant.md** — Lead가 어느 쪽이든 동일 페르소나 적용 명시 + 3-도구 비교표 동봉.

### Notes
- 본 버전은 동작 개선·UX 보강·정책 정확화. 기존 호출 호환성 유지 (PATCH).
- Codex 측 포팅 (plugins/codex/deft/skills/multi-round/) 은 여전히 별도 사이클.

## [claude-2.1.0] - 2026-06-05

### Added
- **multi-round** 신규 스킬 추가 — broker 없이 여러 AI가 N라운드에 걸쳐 양방향으로 의견을 주고받는 멀티턴 토론 도구.
  - `claudex mcp-server` (내장 MCP 도구 `codex` / `codex-reply`) + cmux pane 제어 조합으로 동작.
  - 외부 cloud(api.relaycast.dev / agentrelay.com) 송신 zero — `~/AGENTS.md` §6-1 본업 코드 외부 송신 금지 정책 준수.
  - 회의 모드: `consult` / `dialogue` (기본) / `collaborate` / `debate` — `~/git/AGENTS.teams.md` §12 정의 이식.
  - 신호 프로토콜: `ACK`/`STATUS`/`BLOCKED`/`DONE` + 모드별 확장 (`CONSENSUS`/`AGREED`/`DISSENT`/`CONCEDE`/`REVIEW_PASS`/`REVIEW_FAIL`).
  - 보안 가드 8종: preflight 송신 게이트, `-c mcp_servers={}` 강제, cmux send 줄바꿈 sanitize, cmux search.db 권한 600, settings.json 자동 write 금지, claudex/codex graceful fallback, `cmux identify` 사용, agent-relay 영구 삭제 금지.
  - 트리거: "멀티 라운드", "라운드 회의", "왔다갔다 토론", "주거니 받거니", "AI끼리 토론시켜", "수렴할 때까지 주고받아" 등 18종 — `multi-check` (1발 비교) / Agent Teams (파일 작업) 와 명확히 분리.
  - `agents/codex-participant.md`, `agents/claude-participant.md` 두 참가자 페르소나 동봉.

### Changed
- CHANGELOG 헤더를 "session-relocate 플러그인" → "**deft 플러그인**"으로 정정 (stale 헤더 보정).
- 버전 표기 정책 정렬: 본 changelog의 버전을 `claude-X.Y.Z` 접두 표기로 통일 (이전 `1.0.X` 표기는 그대로 유지하되 신규 엔트리부터 적용).

### Notes
- agent-relay broker 의존성 — 본 스킬은 broker를 호출하지 않음. broker가 cloud-coupled로 사용자 환경에서 차단된 경우 (`/etc/hosts`로 `api.relaycast.dev` 차단)에도 정상 동작.
- Codex 측 포팅 (plugins/codex/deft/skills/multi-round/) 은 별도 사이클로 분리 — Codex 측 변경 시 `codex-X.Y.Z` 독립 bump.

## [1.0.4] - 2026-04-20

### Fixed
- `/session-relocate` 또는 `/session-relocate:session-relocate` 호출 시 여전히 "session-relocate 스킬이 준비되었습니다 / ...하시려면 /session-relocate / 혹은 다른 작업이 필요하신가요?" 류의 소개 + 재질문이 노출되던 현상.
  - 1.0.3 의 `EXEC_IMMEDIATE` 규칙이 과도하게 압축되어 차단력이 약했던 점을 보완.
  - 금지 문구를 **사용자 실제 보고 기준**으로 구체화하여 SKILL.md 최상단에 예시 나열 (`스킬이 준비되었습니다`, `~하시려면`, `~하시려고 하시나요`, `다른 도움이 필요하신 부분`, 재인용 사용법 등).
  - 호출 형태별 "즉시 수행할 첫 동작" 표를 복원하여 첫 응답이 assistant 텍스트가 아닌 **도구 호출로 시작**해야 함을 명시.

## [1.0.3] - 2026-04-20

중간 patch 버전(1.0.4 ~ 1.0.7)에서 이뤄진 반복 개선을 모두 흡수하여 1.0.3 단일 릴리스로 통합.

### Performance
- **도구 호출 횟수 대폭 감축**: Phase 1(4~5회) → 2회, Phase 2(10+회) → 1회, Phase 5(3회) → 1회. 체감 속도 개선.
- Phase 1-2/1-3/1-4 를 단일 통합 Python 스크립트로 병합 (프로젝트 디렉토리 조회 + 자기 세션 판별 + 상위 5개 파싱).
- Phase 2-2 ~ 2-14 를 단일 통합 Python 스크립트로 병합 (realpath·순환·fs·disk·lock·충돌 등 일괄 수행).
- Phase 5 메인·사이드카·정리·롤백을 단일 Python 스크립트로 병합.
- **대용량 jsonl 파싱 최적화**: 마지막 user 엔트리 추출을 256 KB chunk 역방향 seek 방식으로 전환. 수십 MB 파일에서도 빠른 조기 종료.
- **SKILL.md 토큰 사용량 대폭 감축**: 1,028줄 → 약 400줄(-61%), 41 KB → 약 19 KB(-53%). 사용자 노출 문구와 Python 실행 로직은 그대로 유지한 채 반복 서술·레퍼런스·장황한 prose 를 단축 표기로 치환. 섹션 헤더도 `EXEC_IMMEDIATE`, `FLOW`, `CHECK_INTERNAL`, `USER_OUTPUT`, `CARD_TEMPLATE`, `P1-1`, `P1-2`, `P2-0`, `DRYRUN_TEMPLATE`, `CONFIRM`, `P5`, `P6_RESULT_TEMPLATE`, `EDGES`, `HINTS`, `TOOL_CALL_BUDGET` 로 단축.

### Changed
- Claude 내부 선처리 규칙 명시: UUID/절대경로/`~` expansion/시스템 경로 prefix 검증은 도구 호출 없이 텍스트 수준에서 수행.
- 공유 상태를 환경변수(`SESSION_ID`, `TARGET`, `NONCE`, `SRC` 등)로 전달해 중간 덤프 호출 제거.
- 빠른 실행 체크리스트를 "도구 호출 횟수" 기반으로 재작성 (목표: 인자 없음 5회 / 인자 있음 4회).
- **호출 즉시 실행 규칙 신설**: SKILL.md 최상단에 `⚡ EXEC_IMMEDIATE` 섹션을 추가, 호출 즉시 도구부터 실행하고 소개/로딩알림/의도재확인/사용법 안내 assistant 텍스트를 일체 금지. frontmatter `description` 도 "즉시 이동 실행" 중심 능동형 문구로 개정. FQN `/session-relocate:session-relocate` 도 트리거 예시에 명시.
- **카드 렌더 포맷**: 마크다운 **3컬럼 테이블**(`no` | `항목` | `값`) 로 변경. 터미널 폭 자동 적응을 위해 마크다운 테이블만 사용(HTML 금지). 카드당 **별도 테이블**로 출력 + 테이블 간 빈 줄 1개 삽입. 외부 `### [N]` 헤딩 제거(번호가 테이블 내부로 이동).
- **라벨 재정렬/변경**:
  - `rename` → `이름`
  - `최종 업데이트 시간` → `최종 업데이트`
  - 행 순서: `session-id` → `이름` → `시작 대화` → `끝 대화` → `최종 업데이트`
- **표시 글자수 상수화**: P1-2 Python 에 `FDL = 30` (fontDisplayLength) 도입. `이름`/`시작 대화`/`끝 대화` 세 필드 모두 이 상수로 일괄 절삭. 기본 40 → **30** 으로 축소. 이후 조정은 `FDL` 한 값만 바꾸면 전체 일괄 반영.
- `truncate40` 함수 → `tr` 로 리네임, `FDL` 상수 참조.

### Fixed
- `/session-relocate` 호출 시 카드 리스트 대신 "스킬이 로드되었습니다..." 소개 메시지와 "세션을 이동하려고 하시나요?" 재질문이 뜨던 문제.
- 안내 문구와 카드 리스트가 bash 실행 전후로 갈라져 노출되던 순서 문제(`ctrl+o` 로 툴 결과를 펼쳐야 카드가 보이던 상황 포함).

### Documentation
- 기존 Phase 2-1 ~ 2-14, Phase 5 Step 1~3 개별 서술은 레퍼런스로 남김(실행은 통합 스크립트 경로로). 1.0.5 에서 중복 레퍼런스 섹션은 삭제되어 통합 스크립트만 권한.

### Known Limitations
- 마크다운 표준이 rowspan 을 지원하지 않아 "no 칸 세로 병합(중앙)" 는 정확 구현 불가. `no` 값을 각 카드의 첫 행에만 표시하는 방식으로 대체.
- 슬래시 커맨드 자동완성이 FQN `/session-relocate:session-relocate` 를 제안하는 건 Claude Code 플랫폼 동작이라 플러그인 쪽에서 제어 불가. FQN 형태여도 즉시 실행 규칙에 의해 동일하게 카드 리스트부터 출력됨. 단축형을 원하면 `/sess` 입력 후 `Esc` 로 자동완성을 닫고 직접 `/session-relocate` 를 입력.

## [1.0.2] - 2026-04-20

### Changed
- 실행 순서 규칙 강화: 모든 백그라운드 작업(NONCE 주입, 세션 스캔, 파싱)을 먼저 끝내고 최종 응답 한 번으로 안내 문구·카드·프롬프트를 출력.
- NONCE 주입 방식을 `echo` → `:` no-op + Claude가 매 호출마다 생성하는 literal 문자열로 변경. 툴 실행 로그 노이즈 최소화.
- 파서(Python) stdout을 사용자에게 그대로 노출하지 않고 내부 데이터로만 취급함을 명시.

### Fixed
- bash 출력과 카드 리스트가 뒤섞여 사용자가 `ctrl+o` 로 툴 결과를 펼쳐야 카드를 볼 수 있던 문제.
- 안내 문구와 카드 리스트가 bash 실행 전후로 갈라져 노출되던 순서 문제.

## [1.0.1] - 2026-04-17

### Changed
- 리스트업 범위를 상위 9개 → 상위 5개로 축소 (자기 세션 제외).
- 10번 이후 요약 테이블 및 상세 펼침 로직 제거.
- 인자 없이 호출 시 상단 안내를 2줄 고정 문구로 고정:
  - `최근 사용된 5개의 세션 리스트가 제공 됩니다. 이동하려는 세션의 no를 입력해주세요.`
  - `(오래된 세션을 이동하려면 해당 세션을 1회 이상 사용 후 시도해 주세요.)`
- 사용자 노출 출력 규칙 추가: Phase/Step 번호, 진행 상황 서술, 불필요한 보조 안내 금지.

### Removed
- 리스트 하단의 `번호를 입력하거나 /resume 로 돌아가세요.` 류 보조 안내 문구.

## [1.0.0] - 2026-04-17

### Added
- 초기 릴리스.
- Claude Code 세션 로그(`~/.claude/projects/<encoded-pwd>/<session-id>.jsonl`) 와 사이드카 디렉토리(`<session-id>/subagents/`, `<session-id>/tool-results/`)를 다른 pwd 프로젝트 디렉토리로 이동.
- 두 가지 호출 방식: 인자 없음(리스트업 모드) / `/session-relocate <session-id> <절대경로>`.
- NONCE 마커 기반 자기 세션 판별.
- 상위 9개 카드 + 10번 이후 요약 테이블 하이브리드 리스트업(1.0.1에서 5개 카드로 축소).
- 경로 보안: realpath 정규화, 시스템 디렉토리 차단, HOME 외부 경고, 순환 경로 차단.
- 이동 원자성: 같은 파일시스템 체크, disk 용량 사전 확인, 파일 잠김 검사, 실패 시 자동 롤백.
- 14개 엣지 케이스 처리 (모두 `⚠️` prefix).
- 드라이런 + 사용자 컨펌 2단 안전장치.
