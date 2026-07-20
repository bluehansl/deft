# Changelog

이 파일은 deft 플러그인의 모든 주목할 만한 변경 사항을 기록합니다.

형식은 [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/) 를 따르며, 버전 체계는 [Semantic Versioning](https://semver.org/lang/ko/) 을 사용합니다 (`claude-X.Y.Z` / `codex-X.Y.Z` 접두).

## [claude-2.46.0 / codex-1.22.0] - 2026-07-20

> **산출물 라우팅 규칙 신설 — 독자(audience) 기준** — 팀 산출물이 plugin-data(`agent-teams/<work-id>/`)와 `~/.ai/tickets/<티켓>/`에 기준 없이 혼재하던 문제(실측: IT-14882 release-note.md 가 plugin-data 에, 구 IT-14552 역할노트가 tickets 에) 해소. 판별 질문 "팀 바깥 독자(사용자·타팀)가 읽는 완성물인가?" — Yes 면 티켓 디렉토리/프로젝트 repo, No(팀 내부 통신·연속성·오케스트레이션)면 plugin-data. 근본 원인이던 "부산물 자유 조항"(agent-teams §3-4) 교체.

### Added
- **agent-teams `SKILL.md` §3-4-1 산출물 라우팅** — 내부(work.md·<role>.md·team.md·orchestration.log·.spawn-*) = plugin-data / 대외 완성물(릴리즈노트·핸드오프·배포절차·QA컨텍스트·보고서) = work-id 가 티켓(`IT-\d+`)이면 `~/.ai/tickets/<work-id>/`, 프로젝트·OSS 작업이면 해당 repo. 배출 시 work.md 에 경로 링크 의무(SSOT 포인터 — 경로 수색 제거). §6-4 취합 절차에도 배출 단계 연결.
- **multi-round `SKILL.md` §5-A 동일 라우팅** (Claude+Codex 양 포트) — board/summary/transcript 는 회의 세션 기록(내부) 유지, 보고서형 대외 완성물만 티켓/repo 로.

### Changed
- agent-teams §3-4 디렉토리 트리의 "작업 부산물 자유 추가" 조항 → "팀 내부 부산물만 + 대외 완성물은 §3-4-1" 로 교체 (혼재의 근본 원인 제거).

### 데이터 정리 (스킬 외)
- `IT-14882/release-note.md` 를 plugin-data → `~/.ai/tickets/IT-14882/` 로 이동 + work.md META 에 링크 기록.

## [claude-2.45.2] - 2026-07-02

> **PENDING 등록 — 모델 지정 전면 변수화 검토 결과** — 모델 지정을 `deft-model` SSOT 로 단일화(멀티체크 haiku 제외)하는 방안의 가능여부 판단 완료(가능). CLI 경로는 `$(deft-model)` 완전 자동, Agent tool 경로는 alias SSOT 참조로 단일화. 구현은 승인 후 별도. 코드 무변경.

### Docs
- **`PENDING.md`** — 모델 변수화 설계(deft-model alias 차원 추가 + 리터럴 ~10곳 SSOT 참조 전환)·제약(Agent tool 런타임 치환 불가)·트레이드오프 등록.

## [claude-2.45.1] - 2026-07-02

> **PENDING 등록 — harness 방법론 부분 차용(C) 분석 결과** — multi-round 회의(3인 CONSENSUS) 결론을 `PENDING.md` 에 보류 항목으로 등록. 구현은 사용자 승인 후 별도 세션. 코드 무변경(Codex 무영향).

### Docs
- **`PENDING.md`** — harness A(토폴로지 렌즈)·B(분리 4축)·C(트리거 검증) 부분 차용 체크리스트 등록. (A)내재화·(B)병용 기각 근거 + deft 정체성 3축 보존 불변식 포함.

## [claude-2.45.0 / codex-1.21.0] - 2026-07-02

> **Claude Fable 5 재개방 → 전 스킬 모델 Fable 5 복원** — 2026-06 차단으로 opus 로 운용하던 Claude 워커·팀원·리뷰어·첫워커 모델을 Fable 5 로 원복. CLI 실행 경로는 `deft-model`(SSOT) `CLAUDE_DEFAULT`=`claude-fable-5` 로, Agent tool 경로는 enum alias `fable` 리터럴로 전환. `claude --model claude-fable-5` 와 Agent tool `model:"fable"`(spawn→런타임→SendMessage) 양쪽 실호출 검증 완료. multi-check 의 haiku 얇은 래퍼는 의도대로 유지.

### Changed
- **`bin/deft-model` (Claude+Codex) `CLAUDE_DEFAULT` `opus`→`claude-fable-5`** — CLI 경로(`claude --model "$(deft-model claude)"`)가 전 스킬 자동 복귀(멀티체크 리뷰어·회의 send/capture 폴백·claude CLI 워커). `DEFT_CLAUDE_MODEL` override·codex 기본(gpt-5.5) 무영향.
- **Agent tool `model:` 리터럴 `opus`→`fable`** — Agent tool enum 제약(sonnet/opus/haiku/fable, 풀 ID 불가)이라 alias 사용: agent-teams 팀원(SKILL §2·§4-3·GUIDE + `agents/*.md` 8종 모델 메타), multi-round 첫 워커(Phase 3-A·용례 1).
- **native-spawn 기본/인자 `opus`→`fable`** — `bin/deft-claude-native-spawn` 기본 모델(`${4:-fable}`) + multi-round 헬퍼 호출 인자. `bin/deft-claudex-native-spawn` 팀 config 멤버 메타도 `fable`.
- **`||echo opus` 폴백 → `||echo claude-fable-5`** — deft-model 미설치 시 폴백도 Fable 로 통일(`bin/deft-review`·multi-check `claude-reviewer.md`·multi-round SKILL, 양 포트).
- **스테일 "차단됨" 설명 현행화** — fable 이 더 이상 차단이 아니므로 agent-teams(SKILL/GUIDE)·multi-check 의 "미지정 시 fable(차단) 실패" 문구를 정정(모델은 그대로).

### 검증
- `claude --model claude-fable-5 -p …` exit 0(`FABLE_OK`) · alias `fable` 도 CLI 수용.
- Agent tool `model:"fable"` 프로브: spawn 성공 → 런타임 → `SendMessage`(`FABLE_AGENT_OK`) 수신 확인. 과거 opus 전환 원인(fable 차단) 해소 확정.

## [claude-2.44.1 / codex-1.20.2] - 2026-06-25

> **문서·메타 정비** — ① plugin.json/marketplace 의 `homepage`/`repository`/`websiteURL` 을 실제 repo(`github.com/bluehansl/deft`)로 정정(기존 `bluehansl-plugins` 오기 — 설치엔 무관하나 혼동 방지). ② README/GUIDE 소개 정확도 향상 — multi-round 에 "작업 모드"(NTP mesh 분담) 설명 추가, multi-round/agent-teams 한 줄 설명 보강.

### Fixed
- **GitHub URL 오기 정정 (claude·codex plugin.json 5곳)** — `github.com/bluehansl/bluehansl-plugins` → `github.com/bluehansl/deft`. 실제 git remote 와 일치시켜 개발팀 설치·열람 시 혼동 제거.

### Changed
- **README/GUIDE 소개 보강** — multi-round 가 회의/작업 2모드임을 명시(작업 모드=board 없는 NTP mesh 분담), multi-round·agent-teams FQN 설명 구체화.

## [claude-2.44.0] - 2026-06-25

> **회의 워커 실측 검증 후 2건 버그 수정 — claude 워커 pane 스택 + board write 강제** — 2.43.0 배포 후 사용자가 다른 워크스페이스 날것 실행으로 검증한 결과(R-16 2채널 공존·이름표·ntpPush 정상 확인), 두 가지 결함이 드러나 수정. ① 추가 claude CLI 워커가 첫 워커 아래로 스택되지 않고 Lead 옆 새 컬럼을 만들어 1:1:N 으로 깨짐 ② claude 워커가 board 를 읽기는 하나 응답을 board `post_message` 가 아니라 NTP `SendMessage` 로 Lead 에 보고 → 다른 워커가 그 입장을 board 에서 못 봄(브로드캐스트 실패). 작업 모드(NTP mesh) 호환 유지하며 회의 모드 한정으로 수정.

### Fixed
- **`bin/deft-claude-native-spawn` pane 스택 로직 누락(1:1:N 레이아웃 버그)**: 무조건 `new-split right`(새 컬럼) 하던 것을 `deft-claudex-native-spawn` 과 **동일한 `.last-worker-pane` 연쇄**(직전 워커 pane focus → `new-split down`, 새 pane:ref 기록)로 교체. 두 헬퍼가 같은 상태파일 프로토콜을 공유해 **혼합 회의(claude+claudex)에서도 순서 무관 단일 컬럼 스택** → Lead 1 : 워커 N 레이아웃. (회의·작업 모드 공통 — `DEFT_BUS_DIR` 무관.)
- **claude 워커가 board 에 write 안 함(NTP 로 새는 버그)**: claude 워커는 NTP binding + board 버스를 둘 다 가져 응답 채널이 모호 → 페르소나 24행("받은 채널로 답")을 NTP 쪽으로 적용해 `SendMessage` 보고로 샜다. **회의 모드 한정 board 강제**를 3중으로 박음:
  - `agents/claude-participant.md` — "회의 모드 = board `post_message` 전용, `SendMessage` 보고 금지(board 단일 진실 소스)" 규칙 추가. 작업 모드 NTP 보고는 명시 보존(의제에 `응답 채널: board` 없으면 작업 모드).
  - `skills/multi-round/SKILL.md` 워커 prompt 표준 inject — "응답 채널: board(post_message) 전용, claude 워커도 board 에 post" 명시(페르소나 트리거).
  - `bin/deft-claude-native-spawn` — board 버스 주입(`DEFT_BUS_DIR`) 시 `--allowedTools mcp__bus__*` 추가(권한 거부 fallback 차단 이중 안전망, 근거: RATIONALE R-10).

### 호환성
- **작업 모드(Phase 4-T) 무영향**: `--allowedTools`·board 강제는 `DEFT_BUS_DIR`(회의) 분기 내에만 적용. 작업 모드는 board 미주입이라 NTP `SendMessage` 보고 경로 그대로 유지.

## [claude-2.43.0] - 2026-06-25

> **multi-round 회의 워커 2채널 공존 복원 — Phase 3-A 헬퍼 기반 재작성(회귀 수정, R-16 구현)** — 2.40.0 회귀("빈 pane + CLI 직접부팅"으로 `--claude-team-agent` binding 누락 → pane 이름표 사라짐 + NTP 노크 ntpPush→cmuxKnock 폴백)를 RATIONALE R-16 의 실측 확정 절차로 교체했다. 회의 워커가 다시 **NTP binding(이름표 `@name`·ntpPush) + MCP 버스 board(토론 본문) 2채널을 동시에** 갖는다. 인프라(`deft-claudex-native-spawn`·`deft-claude-native-spawn`·`multi-round-bus`)는 이미 준비돼 있어 스킬 절차만 정정. `claude-2.42.2` 의 의뢰서(`HANDOFF-phase3a-rewrite.md`)대로 수행.

### Changed
- **`skills/multi-round/SKILL.md` Phase 3-A (2)~(5) 전면 재작성** (약 142줄 교체):
  - 워커 부팅을 **"빈 pane + CLI 직접부팅" → "첫 워커 Agent tool + 나머지 헬퍼(`DEFT_BUS_DIR` 주입)"** 로 전환. `DEFT_BUS_DIR` 설정 시 헬퍼가 `--claude-team-agent`(NTP) + 버스 MCP(board) 를 함께 주입 → 2채널 공존(근거: R-16).
  - **(2)** 첫 워커 = `Agent` tool(팀 생성·TID 획득, board MCP 직결 불가 → `SendMessage` 중계). **(3)** 첫 워커 pane:ref 를 `.last-worker-pane` 기록(헬퍼가 그 아래로 세로 스택 — pane 레이아웃 유지). **(4)** 나머지 워커 = `deft-claudex-native-spawn`/`deft-claude-native-spawn` 헬퍼(JSON 출력에서 `.surface` 캡처). **(5)** board `register --inbox <팀inbox>` (ntpPush 스위치) + `post --inject` 의제 게시 + 응답 회수 2경로(헬퍼 워커=board `check`, 첫 워커=`team-lead.json` 직접 회수).
  - 🔑 **`--inbox` 가 ntpPush 의 스위치**임을 명시(버스 `info.inbox ? ntpPush : cmuxKnock`) — 헬퍼로 띄운 워커 inbox 경로를 register 에 줘야 느린 cmuxKnock 대신 빠른 ntpPush.
  - 폐기된 "빈 pane + CLI 직접부팅" 경로는 `<details>` 접이식으로 보존(회귀 재발 방지 — 왜 폐기됐는지 명시).
- **§운영 용례 1 보강** — claudex 워커 블록에 2채널 공존 효과(`DEFT_BUS_DIR`) 주석, 추가 claude CLI 워커(`deft-claude-native-spawn`, `DEFT_LEAD_SESSION` 필수) 경로, 회의 모드 board 등록 단계 추가. Phase 3-A 가 용례 1 을 단일 소스로 참조(중복 제거).
- **§Phase 5-B 정리** — 워커 유형별 종료 분기 명시: 첫 워커(Agent tool)=`shutdown_request`(close-surface·kill 금지, R-5), 헬퍼 워커=캡처한 `WSURF_*` surface close. 옛 `W*_SURFACE`/`(3.5)` dangling 참조 정정.

## [claude-2.42.2] - 2026-06-25

> **Phase 3-A 재작성 작업 의뢰서 추가(HANDOFF)** — 회의 워커 2채널 공존 복원 작업을 리줌 없는 새 세션에 인계하기 위한 자기완결 의뢰서 `HANDOFF-phase3a-rewrite.md` 신설. 목표·배경·정답 절차(R-16)·제약(pane 구성 유지·하드코딩 금지)·검증 방법(R-8 맹점 — bash 직접 금지, 별도 세션 날것 실행)·작업 절차·버전 규약을 담음. 실제 Phase 3-A 코드 재작성은 새 세션이 이 의뢰서로 수행.

### Added
- **`HANDOFF-phase3a-rewrite.md`** — Phase 3-A 재작성 작업 의뢰서(새 세션 인계용).

## [claude-2.42.1] - 2026-06-25

> **회의 워커 이름표·NTP 노크 회귀 진단 — 헬퍼 2채널 공존 절차 확정(RATIONALE R-16, 구현 대기)** — 2.40.0 에서 회의 워커를 "빈 pane + CLI 직접부팅"으로 띄우며 `--claude-team-agent` binding 을 빠뜨려 ① pane 이름표(`@logistics`) 사라짐 ② NTP 노크(ntpPush)→cmuxKnock 폴백. 원래(첨부 이미지·사용자 재실측) claudex 는 `--claude-team … --claude-team-agent … -c mcp_servers.bus` 로 binding+버스 공존했다. 사용자 세션이 NTP(이름표·노크)+버스(board 토론) 2채널 공존을 재현·성공하고 정확한 띄우기 절차를 제공 → RATIONALE R-16 으로 보존, Phase 3-A 재작성은 PENDING 등재(약 120줄 교체라 정밀 실행).

### Added
- **RATIONALE R-16** — 회의 워커 NTP binding + 버스 board 2채널 공존 원리·띄우기 절차(첫 워커 Agent tool team 생성 → 나머지 헬퍼 DEFT_BUS_DIR 주입)·시행착오 교훈(team 디렉토리 rm 금지·DEFT_LEAD_SESSION 필수) 보존.
- **PENDING — Phase 3-A 재작성 설계** 등재(인프라 준비 완료 확인: deft-claude-native-spawn·deft-claudex-native-spawn + DEFT_BUS_DIR·DEFT_LEAD_SESSION 처리 내장).

## [claude-2.42.0] - 2026-06-25

> **버스 경로 워커 부팅 견고화 — cmux send 3대 규약 (사용자 세션 자체 보정 → 일반화)** — 다른 워크스페이스·zsh 환경에서 버스 경로(claude CLI + claudex 인라인 MCP)로 워커를 pane 에 띄울 때, pane 분할은 됐으나 ① 입력창 잔여 텍스트로 명령 오염(touch 텍스트가 prompt 에 박힌 채 실행 안 됨) ② MCP 인라인(수백 자) 직접 send 시 유실 ③ `surface:N` 콜론이 zsh 파싱(`${pair%%:*}`/`set --`) 깨뜨림 — 세 가지가 겹쳐 워커가 안 떴다. 사용자 세션이 자체 보정으로 성공한 패턴을 스킬에 일반화. (근거: RATIONALE R-15)

### Fixed
- **cmux send 3대 규약 (Phase 3-A (3.5)~(5))** — ① **send 전 `send-key C-u`(입력창 클리어)** 매 send 직전 ② **긴 부팅 명령은 `boot-<name>.sh` 저장 → `source` 한 줄만 send**(MCP 인라인 직접 send 유실 방지) ③ **colon ref·zsh 파싱 회피** — 루프·구분자 금지, surface ref 명시적 나열. 헬퍼(deft-claudex-native-spawn)는 readiness·--workspace 는 내장하나 C-u·source 는 없어(NTP 경로는 send 짧고 1회라 덜 취약) 버스 경로에 특히 필요.

## [claude-2.41.1] - 2026-06-25

> **문서 정리 — 설계 근거 RATIONALE.md / 보류 PENDING.md 분리 (사용자 요청)** — SKILL.md 에 누적된 일지형 실측 사고·근거 주석을 별도 `RATIONALE.md`(R-1~R-14)로 이관하고, SKILL.md 는 간결한 지침 + `(근거: RATIONALE R-N)` 참조만 남김. 진행 중·보류 항목은 `PENDING.md` 로 관리. multi-round 1차 적용(핵심 일지형 6건 축약 + deft-test L4 연계 제거). agent-teams·multi-check 정리는 PENDING 에 등재(후속).

### Added
- **`RATIONALE.md` 신설** — deft 가드·규약의 "왜"(실측 사고·재현 조건·소스 확정)를 R-1~R-14 로 보존. 가드를 미래에 되돌리려는 사람이 먼저 읽도록. SKILL.md 본문은 지침만, 근거는 여기 참조.
- **`PENDING.md` 신설** — 진행 중·보류 항목 추적(상태 플래그). 완료 시 CHANGELOG 이관.

### Changed
- **multi-round SKILL.md 일지형 주석 축약** — NTP 자동주입 누락 근원·회수 순서·전송계층 모드종속·회의 버스강제·foreground 데드락·kill 금지·codex 프롬프트 등 장문 사고 서술을 RATIONALE 참조로 축약(운영 지침은 본문 유지). deft-test L4 연계 표기 제거.

## [claude-2.41.0] - 2026-06-25

> **🔴 크리티컬 — multi-round 가 다른 워크스페이스에서 동작 불가하던 잠복버그 수정 (2.5.0~2.40.0)** — 사용자가 새 워크스페이스에 pane 을 만들고 거기서 claude 를 띄워 스킬을 실행하자, **pane 은 분할됐으나 워커가 안 뜨고 `touch`/CLI 부팅 명령이 워커 pane 이 아니라 Lead pane 으로 폴백 입력**되는 문제 발생. 원인: Phase 3-A 의 모든 `cmux send`/`send-key`/`focus-pane`/`new-split`/`close-surface` 가 `--workspace` 동반 없이 `--surface` 단독으로 호출 → caller stale 환경(다른 워크스페이스에서 스킬 실행·resume 후·비대화형)에서 surface ref 해석 실패 → caller(Lead) 로 폴백. **2.5.0(버스 아키텍처 도입)부터 잠복**했으나, 모든 테스트가 Lead 와 같은 워크스페이스에서 돌아 우연히 안 터졌다(처음으로 다른 워크스페이스에서 날것 실행되며 드러남). NTP 헬퍼(`deft-claudex-native-spawn`)는 이미 이 패턴으로 고쳐져 있었으나(CHANGELOG 154) 버스 경로 send 엔 전파가 누락. **영향: multi-round 한정** — agent-teams·multi-check 는 Agent tool 이 pane 생성+기동을 원자적으로 처리해 `cmux send` 단계가 없어 구조적으로 안전.

### Fixed
- **Phase 3-A 모든 cmux 호출에 `--workspace "$LEAD_WORKSPACE"` 동반 강제** — `LEAD_WORKSPACE`/`LEAD_PANE` 를 `cmux identify` 로 **런타임 발견**(세션 고유값 하드코딩 없음 — 어느 워크스페이스·PC·세션에서나 동작)하고, `WS=(--workspace "$LEAD_WORKSPACE")` 배열을 (2) pane 분할 ~ (5) 페르소나 주입 + Phase 5 정리(close-surface·focus-pane)의 모든 send/send-key/focus-pane/new-split/close-surface 에 동반.
- **SESSION_DIR 일관성 가드 신설** — Claude Code Bash 는 호출 간 셸 변수가 유지 안 돼, 모델이 SESSION_DIR 공유를 위해 **공유 고정 임시파일(`/tmp/.mr_session_dir`)을 즉흥 생성 → 이전 세션 값 잔재로 오염**되던 사고 방지. 세션 고유 파일 저장·재사용 또는 리터럴 절대경로 직접 박기로 명시. `mapfile`/`readarray`(bash 전용 — zsh 깨짐) 경고 추가. SESSION_TAG 를 분→초 단위(`%H%M%S`)로 격상(충돌 방지).

## [claude-2.40.0] - 2026-06-25

> **회의 모드 board 브로드캐스트 회귀 복원 — 회의=MCP 버스 강제 (실측 진단)** — "토론"을 요청했는데 워커 간 브로드캐스트(board 공유)가 안 일어나고 각자 Lead 에 1:1 보고만 한 사고를 파일 레벨로 진단. 정상 회의(13:35 세션)는 board.jsonl + `to:"all"` + 워커 간 #번호 인용으로 토론했으나, 출력 개선 작업 중 회의 spawn 이 **NTP 직접회수 경로(board 없음, r*-collected.jsonl)로 전환되어 star 로 퇴화**. 근본 원인은 통신 우선순위 매트릭스가 claudex 0.139.1+ 면 모드 무관하게 NTP 1순위를 골라, 회의 모드인데도 board 없는 경로로 간 것. **버스에는 이미 "board 공유 + `ntpPush`(cmux 노크 대신 팀 inbox 자동주입 전파)"가 구현돼 있어(13:35 검증됨)**, 새 인프라 없이 회의를 버스로 되돌리면 board(공유 진실 소스)+속도(ntpPush) 둘 다 성립. NTP fan-out(워커가 전원 복제 전송)은 공유 타임라인을 못 만들어(파편화) 진짜 broadcast 가 아님 — 단일 허브(버스) board 가 정답.

### Fixed
- **통신 우선순위 매트릭스 모드 종속화** — 회의 모드는 claudex 유무 무관 **MCP 버스 강제**(board 보장, 속도는 ntpPush). NTP 네이티브 1순위는 **작업 모드 전용**으로 격리. 전송계층이 모드를 따르도록 표를 회의/작업 2개로 분리.
- **§Lead 직접회수 적용 범위 축소** — "회의+작업 공통" → **작업 모드 + 종료 대기 전용**. 회의 라운드 수신에 직접회수를 쓰면 board 를 우회해 워커 상호 노출이 사라짐(회귀 원인)을 명시.
- **회의=버스 강제 가드 신설 (Phase 2)** — 회의 모드면 어떤 이유로도 NTP 직접회수로 안 띄우고 버스로 spawn, 후 `board.jsonl` 생성 확인(없으면 BLOCKED). 같은 회귀 재발 차단.

> 출력 개선(2.39.x: announce 고정·foreground 금지·평문종료 금지)은 그대로 유지 — 이번 수정은 회의 전송계층만 복원.

## [claude-2.39.2] - 2026-06-25

> **종료 프로토콜 강화 — 평문 종료 요청 금지, 구조화 shutdown_request 필수 (실측 사고)** — 회의 종료 시 Lead 가 claude 워커에게 "정리하고 종료해 주세요" 같은 **평문 문자열**로 종료를 요청 → 워커는 그걸 *일반 메시지*로 받아 **보고만 하고 프로세스는 안 내려감**(claudex 워커는 종료됐으나 claude 워커 잔존). 워커가 직접 "shutdown 은 shutdown_response(approve:true)를 받아야 내려간다 — 평문은 응답만 가능, terminate 못 함"이라고 올바르게 거부. claude 워커(in-process)는 kill 도 금지라 **구조화 `shutdown_request` 가 유일한 종료 수단**인데 평문으로 보내 영영 안 죽은 것.

### Fixed
- **평문 종료 요청 금지 명시 (multi-round/agent-teams/multi-check 3개 스킬)** — 종료 신호는 반드시 `SendMessage(to:"<name>", message:{type:"shutdown_request", reason:"…"})` 구조화 객체로. "정리하고 종료해 주세요" 류 평문 문자열 절대 금지(워커가 보고만 하고 프로세스 안 내려감 — 실측). 안 죽었으면 kill 이 아니라 구조화 shutdown_request 를 다시 보낸다. (SendMessage 스키마상 `message` 가 평문/구조화 둘 다 받아 모델이 평문으로 보내던 함정 차단.)

## [claude-2.39.1] - 2026-06-25

> **2대 원칙 정밀화 — announce 지점 고정 + 회수 백그라운드 완결 (실측 피드백)** — 2.39.0 적용 후에도 ① spawn 을 단계별로 쪼개 매번 중계("첫 워커 spawn / team-id 확인 / 두 번째 추가 / claudex 2명 추가 / pane 기록 / N번째 기동 완료")하고 ② 회수 루프를 foreground `wait` 로 기다려 메인이 멈춤(`Flummoxing… 1m+`)이 남았다. 출력 규약을 **블랙리스트("이건 출력 금지") → 화이트리스트("이 고정 지점에서만 출력")** 로 격상하고, 회수 대기를 **foreground `wait` → `run_in_background` + done-flag** 로 전환.

### Fixed
- **출력 announce 지점 고정 (3개 스킬 공통)** — Lead 가 대화에 말하는 지점을 스킬별 5개 내외로 **고정**(① 시작 예고: 요청+인원+페르소나 한 번에 ② 스폰 완료→시작 ③ 중간 결과 ④ 최종 결론 ⑤ 사용자 개입). 그 사이 spawn·통신 단계는 **한 턴에 묶어 말없이 연속 실행** — "첫 워커 spawn합니다 / 두 번째 추가 / pane 기록" 류 단계 나레이션 전면 금지.
- **회수 루프 foreground `wait` 제거 (multi-round)** — 회수 스크립트를 `run_in_background:true` 로 던지고 메인 턴은 즉시 종료, 완료는 `*.done` 플래그 → harness 가 다음 턴을 깨워 COLLECT 를 읽게 함. 기존 `wait "$RECV_PID"` 가 메인을 수십 초~수 분 블록하던 `Flummoxing…` 멈춤 해소(원칙 1 — 메인은 즉각 반응 우선).

## [claude-2.39.0] - 2026-06-25

> **Lead 운영 2대 원칙 신설 — 전 스킬 공통(반응성 + 의미 이벤트 출력)** — 사용자 요구: ① Lead 세션은 실제 작업 중이 아니면 항상 사용자 입력에 반응 가능해야 하고(팀원 응답 대기는 백그라운드/in-progress) ② 출력은 CLI 생성·bus·pane·페르소나 주입 등 내부 메커니즘을 빼고 "어떤 요청으로 몇 명이 어떤 페르소나로 생성·작업 시작·spawn 완료·회의 시작·중간 결과" 같은 최소 의미 이벤트만. multi-round 만 부분 적용돼 있던 것을 **3개 스킬(multi-round/agent-teams/multi-check) 최상단에 동일 강제 박스로 통일**.

### Added
- **multi-round/agent-teams/multi-check SKILL.md 최상단 "Lead 운영 2대 원칙" 박스** — 각 스킬 첫 단락 직후에 최우선 규약으로 배치(워크플로 세부보다 먼저 읽힘).
  - 원칙 1(반응성): 응답 대기 foreground blocking 금지, 백그라운드/idle 강제 — Lead 가 사용자 입력에 항상 반응.
  - 원칙 2(의미 이벤트만): 출력할 것(요청→인원·페르소나→작업 시작→spawn 완료→회의 시작→중간 결과)과 출력 금지(CLI 부팅·버스 등록·pane 분할·페르소나 주입·헬퍼 동기화·레이아웃 정렬·"Ran N shell commands")를 ✗/✓ 예시와 함께 명시.
- agent-teams·multi-check 은 기존에 출력 레지스터 규약이 **전무**했어 신규 도입. multi-round 는 본문 §Lead 출력 레지스터 규약에 더해 상단 강제 요약 추가(실측상 본문만으론 모델이 늦게·약하게 적용 — CLI/pane/bus 중계가 계속 노출됨).

## [claude-2.38.2] - 2026-06-25

> **버스 경로 Lead 데드락 수정 — foreground blocking sleep 폴링 금지 (실측 발견)** — 별도 독립 세션(Sonnet 4.6, MCP 버스 경로)에서 회의 실행 중 Lead 가 라운드 응답 대기를 `for i in $(seq 1 16); do sleep 30; … done` 같은 **foreground blocking 루프**로 구현 → 그 Bash 가 끝날 때까지(최대 8분) 모델 턴 전체가 블록 → 워커 응답·노크가 도착해도 다음 행동으로 못 넘어가는 무한 대기(사용자가 ESC 로 Bash 를 죽여야 큐의 노크를 그제서야 처리). NTP(②)와 무관한 버스 경로 별개 결함. claudex 무관 — 스킬만 수정.

### Fixed
- **foreground blocking sleep 폴링 금지 명시 (Phase 4-A + Workflow 전 Phase 공통)** — Lead 는 응답 대기를 긴 foreground `sleep` 루프로 돌리지 말 것. 올바른 대기 = **짧은 단발 확인(check/read 1회) 후 턴 종료** → 다음 노크/메시지가 다음 턴을 깨운다. 무응답 감시는 **반드시 `run_in_background`/`&`**(데드락 워치독). "응답 올 때까지 기다린다"를 코드(sleep)로 구현 금지 — 기다림은 턴 종료 + 노크 재진입으로 이뤄진다.
- **종료 데드락 주의 추가** — 합의 도달 + 워커 전원 "Lead 종합 대기" 상태면 더 이상 Lead 를 깨울 노크가 없으므로, 또 응답을 기다리면 영구 대기 → 즉시 Phase 5(종합·종료)로 진행하도록 명시.

## [claude-2.38.1] - 2026-06-25

> **Lead 직접 회수 타이밍 정밀화 (재재테스트 발견)** — 2.38.0 의 직접 회수 하네스를 실측(claude2 회의)으로 검증하니 **방향은 맞으나 타이밍 결함**이 드러났다 — ① 회수 루프를 SendMessage **직후** 시작하면 워커 응답을 watcher(750ms)가 먼저 비워 놓침(입장 본문 대신 idle_notification 만 잡힘) ② 한 명 잡고 break 하면 나머지 발신자 응답 유실 ③ idle_notification 등 제어 메시지가 회수 필터를 통과. 회수 루프를 **백그라운드로 먼저 띄운 뒤 SendMessage**(선점)하니 입장 본문 회수 성공 입증.

### Fixed
- **회수 순서 역전 — "회수 루프 먼저(`&`) → SendMessage 나중"** — SendMessage 직후 회수는 수 초 지각해 watcher 에 본문을 뺏긴다. 회수 루프를 백그라운드로 선행 기동해 inbox 를 선점 감시한 뒤 워커에 요청한다.
- **기대 발신자 전원 모일 때까지 break 금지** — 한 명 회수 후 끊으면 그 뒤 도착분 유실(실측 — dbtuning 놓침). `EXPECTED_REPLIES` 전원 충족까지 루프 유지.
- **회수 필터 정정** — idle_notification·shutdown 등 제어 메시지를 회수 대상에서 제외(`.text` 가 idle_notification 포함이면 skip). 실제 보고 본문만 `COLLECT` 에 모은다.

## [claude-2.38.0] - 2026-06-25

> **NTP 수신 격상 — 자동주입 신뢰 폐기, Lead 직접 회수를 1차 경로로 (재테스트 근원 규명)** — 2.37.0 배포 후 재테스트(회의 claude2+claudex2)에서 ② "송신≠전달"의 근원이 소스+실측으로 규명됐다. 워커 메시지는 `team-lead.json` 에 정상 적재되나(고빈도 폴링으로 `read:false` 포착), **Claude Code(Lead) 런타임 watcher 가 읽어 비운 뒤 turn 경계(mailbox delivery phase=NextTurn)에서 대화 주입을 누락**해 유실된다(Lead transcript 자동주입 0건 확정). drain 주체는 Lead 런타임이고 claudex watcher 는 자기 inbox 만 건드려 무죄 — 즉 **claudex 수정 불필요, 스킬만 수정**. 2.37.0 의 "느린 폴링 권고"로는 부족(watcher 750ms 주기보다 느리면 빈 inbox 만 봄)해 **고빈도 선점 직접 회수**로 격상.
>
> 부수 확인: ①(claudex `send_message(target:…)` 형식)·④(Lead 출력 레지스터)는 재테스트에서 **정상 작동 입증**.

### Changed
- **§Lead 직접 회수 신설 (구 §폴백 워치독 격상) — 자동주입을 1차 경로에서 강등** — Lead 는 `<teammate-message>` 자동주입을 신뢰하지 말고, 워커에 `SendMessage` 한 **직후부터 `team-lead.json` 을 0.5초 간격 고빈도로 직접 read 해 회수**한다(잡는 즉시 `COLLECT` 파일로 복사 — watcher 가 비워도 보존). turn 경계 누락을 Bash 직접 읽기로 구조적 우회. 근원(NextTurn phase 누락)·메커니즘·회수 루프 예시 명문화.
- **자동주입 단정 표현 보정 (용례 3·NTP 보고 규칙)** — "팀원 응답은 자동 주입된다 — 정상 경로에선 inbox 수동 확인 안 함" → "자동주입은 보너스 채널일 뿐, **Lead 직접 회수가 1차 경로**"로 전면 수정. 작업 모드(T-5) 참조도 §Lead 직접 회수로 통일.

## [claude-2.37.0] - 2026-06-25

> **multi-round NTP 통신·출력 견고화 3건 (실측 발견)** — 루트에서 멀티라운드 '토론' 실측 중 발견한 결함을 스킬 하네스로 박음. ① claudex `send_message` 의 수신자 키가 `to` 가 아니라 `target` (소스 확정)인데 스킬 문서가 `to` 로 잘못 안내 → AI 별 키 분기 명시. ② 송신 도구가 `success:true` 를 반환해도 Lead inbox 0건·자동주입 미도착인 사고(claude·claudex 공통)를 실측 → Lead 능동 폴링 강제 + 워커 재보고 규약. ④ Lead 가 spawn 헬퍼·cmux·team-id 등 내부 메커니즘을 사용자 대화에 중계하던 문제 → 출력 레지스터 규약(의미 이벤트만). (③ claude 워커 config 미등록 의혹은 실측에서 정상 등록 확인 — 코드 결함 아님, 죽은 세션의 누락은 spawn 중도 실패 흔적.) Claude 측 전용.

### Fixed
- **claudex `send_message` 키 정정 — `to` → `target` (SKILL.md §NTP, codex-participant.md)** — claudex(codex fork)의 `send_message` 는 `{target, message}` 두 키만 받는다(`#[serde(deny_unknown_fields)]`, 소스 `SendMessageArgs` 확정). 기존 문서가 `send_message(to:…)` 로 안내해 claudex 가 `to` 로 부르면 도구 호출 실패. **Lead `SendMessage`=`to` / claudex `send_message`=`target`** 분기를 표로 명시하고, claudex 페르소나에 정확한 호출 형식(`send_message(target:"team-lead", message:…)`)과 `to`/`recipient` 금지를 박음.

### Changed
- **Lead 능동 폴링 강제 — "송신 success ≠ 전달" (SKILL.md §NTP·보고 규칙)** — claude·claudex 워커 모두 송신 도구가 `success:true` 를 반환해도 `team-lead.json` 0건·자동주입 미도착인 porter 수신 사고를 실측(2026-06-25). 송신 성공 신호는 inbox 적재 시도까지만 보장 → Lead 는 자동주입에 의존하지 말고 `team-lead.json` 직접 폴링, 미수신 시 워커에 재보고 요청(권고 → 필수 하네스로 격상). 양 워커 페르소나(claude/codex-participant.md)에 "보고 후 출력만 반복 금지, 재요청 시 도구 재호출" 추가.
- **Lead 출력 레지스터 규약 신설 (SKILL.md §진행 로그 + Workflow 전 Phase 포인터)** — Lead 가 사용자 대화 화면에 출력하는 것을 **의미 이벤트(소환 페르소나·진행 마일스톤·중간/최종 결과)만**으로 한정. spawn 헬퍼·cmux 명령·rebalance·상태파일·team-id·버전 게이트 등 오케스트레이션 디테일은 `orchestration.log` 로만 남기고 대화에 중계 금지. 불가피한 프로세스 언급은 사용자 친화 문구로 변환. (에이전트/cmux UI 가 이미 pane·워커 상태를 시각화하므로 텍스트는 의미만 담당 — 실측 피드백.)

## [claude-2.36.2] - 2026-06-25

> **multi-check reviewer 견고화 2건 (풀사이클 테스트 발견)** — ① reviewer 가 spawn 후 첫 턴에 idle 로 멈추던 문제(즉시 실행 지시 추가) ② reviewer 가 shutdown_request 에 prose 로만 응답해 SIGKILL 필요했던 문제(shutdown_response 도구 호출 강조). Claude 측 전용(Codex multi-check reviewer 는 종료 메커니즘이 달라 무관).

### Changed
- **reviewer spawn prompt 에 "즉시 실행" 지시 명시 (§Phase 3 템플릿)** — `run_in_background:true` 로 띄워도 페르소나만 인라인하면 reviewer 가 첫 턴에 deft-review 를 실행 않고 idle 대기하는 경우가 있어(실측), `[검토 대상]` 뒤에 "지금 즉시 deft-review 실행 후 SendMessage 보고, 추가 지시 대기 말 것" 한 줄을 덧붙이도록 명문화.
- **reviewer 페르소나 종료 프로토콜 강조 (codex/claude/gemini-reviewer.md)** — shutdown_request 수신 시 "다른 어떤 출력보다 먼저 shutdown_response 도구 호출, prose·CLI 재실행 금지" 🚨 블록 추가. codex/gpt-5.5 reviewer 가 shutdown 을 prose 로만 응답해 SIGKILL·좀비 핸들을 유발한 실측 사고 반영.

## [claude-2.36.1 / codex-1.20.1] - 2026-06-25

> **deft-review PATH 자동 보강 — 빈약한 PATH 환경(Agent 워커 셸)에서도 CLI 탐색** — multi-check reviewer(Agent tool 워커)의 비대화형 셸은 PATH 에 nvm bin 이 없어 `command -v claudex/codex/gemini` 가 실패, CODEX_NOT_INSTALLED/GEMINI_NOT_INSTALLED 오판이 났다(실측). deft-review 가 호출 시 표준 설치 경로를 PATH 앞에 prepend 해 어느 셸에서 호출돼도 CLI 를 찾게 보강.

### Fixed
- **`deft-review` PATH 자동 보강** (양측) — 프롬프트 처리 후 case 진입 전, `$HOME/.local/bin` · 최신 nvm bin(`$HOME/.nvm/versions/node/*/bin` sort -V tail) · `$HOME/.nvm/current/bin` · `/opt/homebrew/bin` · `/usr/local/bin` 을 PATH 에 prepend(이미 있으면 skip). 빈약한 PATH(`/usr/bin:/bin`)에서도 claudex/codex/gemini/claude 전부 발견 확인. multi-check·multi-round(작업 모드 deft-review 호출) 공통 혜택 — Agent 워커 셸 PATH 와 무관하게 reviewer 동작.



> **rebalance-guard `expected-panes` 인자 — 예정 다(多)컬럼이면 첫 워커부터 목표 비율 미리 정렬** — guard 가 "지금 pane 수"만 보던 것을, Lead 가 spawn 확정 시 넘기는 "예정 총 pane 수"도 알게 해, 워커가 다 뜨기 전부터 최종 목표 비율(60:40)로 당긴다. multi-round·agent-teams 공통(multi-check 은 guard 미사용이라 제외).

### Added
- **`cmux-rebalance-guard` 7번째 인자 `expected-panes`** (양측) — Lead 포함 예정 총 pane 수(= 스폰 확정 워커 수 + 1). **≥3 이면** 현재 pane 이 2개(Lead+워커1)일 때도 발동 임계를 58 로 올려, cmux 기본 2-pane 분할(50:50)을 **워커가 다 뜨기 전부터 목표 60:40 으로 미리** 정렬한다. ≤2(또는 미지정)면 최종 2-pane=50:50 이 기본 분할이라 별도 교정 불요 → 기존 임계(50)대로(하위호환). (배경: 종전엔 첫 워커 단계 50:50 이 임계 50 에 안 걸려 두 번째 워커가 Lead 를 깎아야 비로소 60:40 으로 정렬됐다 — 실측.)

### Changed
- **multi-round(용례 1·작업 T-1)·agent-teams(§2-3) guard 호출에 `EXP_PANES` 전달** — multi-round 는 `EXP_PANES=$((WORKER_COUNT+1))`, agent-teams 는 기존 `$EXPECTED`(=BASE+N) 재사용. 워커 2명+ 면 ≥3 이 되어 첫 워커 단계부터 60:40 정렬.

## [codex-1.19.1] - 2026-06-24

> **Codex 스킬 Phase 0 deft-bin-sync 일원화** — Claude 측(claude-2.34.0)에 이어 Codex 포팅본 스킬의 개별 헬퍼 설치 블록을 deft-bin-sync 부트스트랩으로 교체. (인프라 `bin/deft-bin-sync`·`cmux-rebalance-guard` 는 codex-1.18.0/1.19.0 에서 이미 양측 미러됨 — 이번엔 스킬 인라인만 교체. Codex 만 bump.)

### Changed
- **Codex multi-round·multi-check Phase 0 자동설치 일원화** — 개별 `if ! command -v $H`(없으면 설치, 구버전 잔재 갱신 불가 결함) 블록을 **deft-bin-sync 부트스트랩 + 1회 호출**로 교체(캐시 codex 우선 탐색). `HAVE_BUS`(node+bus 판정)·`HAVE_CMUX`(cmux identify) 판정 로직은 유지, 설치만 위임. cmux gap-fill 은 `deft-bin-sync cmux` 보강.

### Notes
- **done-flag 는 Codex 포팅본에 적용 대상 없음**(의도된 미반영) — Codex multi-round/multi-check 는 Lead=Codex 로 `cmux new-split`(빈 pane) **선분할 → 단발 rebalancing**(Option 2) 모델이라, claude `Agent` tool 의 "spawn ~1.4초 후 늦은 cmux 재계산" 타이밍 결함이 **구조적으로 발생하지 않는다**. done-flag guard 가 푸는 그 문제가 없으므로 부분 반영조차 불요. (claude-2.35.0 done-flag 는 Agent-tool spawn 전용.)

## [claude-2.35.0 / codex-1.19.0] - 2026-06-24

> **rebalance-guard done-flag 종료 방식** — guard 종료 조건을 "시간(grace 5초)" → "Lead 의 spawn 완료 신호 플래그"로 전환. 느린 마지막 워커(4번째 Agent)의 재계산이 grace 후에 와서 guard 가 먼저 죽어 마지막 틀어짐을 놓치던 문제(실측 540px 잔존) 해결. multi-round 회의·작업 + agent-teams 공통 적용.

### Changed
- **`cmux-rebalance-guard` `--done-flag` 옵션 추가** (양측) — 6번째 인자로 "모든 spawn 완료" 신호 파일 경로. **설정 시 그 파일이 touch 되기 전엔 grace 무틀어짐이어도 종료하지 않고 비율을 계속 지킨다**(spawn 기간이 얼마든·부팅이 느리든 끝까지 커버). 플래그 touch 후 마지막 안정 확인하고 종료. 미설정 시 종전 grace 종료(하위호환). spawn 호출 반환 ≠ pane 재계산 완료라 시간으로 못 끊으므로 플래그가 정확.
- **multi-round(회의 용례 1·작업 T-1)·agent-teams(§2-3) guard 발사 통일** — `GUARD_FLAG="$SESSION_DIR(또는 $LOG_DIR)/.spawn-done"; rm -f` → guard 발사(플래그 인자) → 모든 워커 spawn 반환 후 `touch "$GUARD_FLAG"`. 3개 스킬 공통 패턴.

## [claude-2.34.0 / codex-1.18.0] - 2026-06-24

> **헬퍼 자동설치 갱신형 전환** — `deft-bin-sync` 공통 도구로 일원화. 종전 Phase 0 자동설치는 "없으면 설치"라 `~/.local/bin` 구버전 잔재를 plugin update 후에도 갱신 못 하던 **배포 결함**(실측: ntpPush 없는 6/12 구버전 multi-round-bus 가 최신 캐시를 PATH 우선순위로 가림)을 해결.

### Added
- **`bin/deft-bin-sync`** (신규 공통 헬퍼, Claude·Codex 양측) — deft 가 `~/.local/bin` 에 까는 모든 헬퍼를 **캐시 최신본으로 동기(갱신형)**. 캐시 `sort -V tail` 최신본 ↔ `~/.local/bin` 내용을 `cmp` 해 다르거나 없으면 cp+chmod. claude/codex 캐시 양쪽 탐색. 인자 없으면 전체, 인자 주면 지정 헬퍼만(`deft-bin-sync cmux` 는 deft-cmux-shim→cmux 매핑).

### Changed
- **multi-round·agent-teams·multi-check Phase 0 자동설치 일원화** — 개별 `if ! command -v $H`(없으면 설치) 블록 ~40개를 **deft-bin-sync 부트스트랩 + 1회 호출**로 교체. "구버전 잔재가 있으면 영원히 갱신 안 됨" 결함 제거 → plugin update 후 항상 최신 헬퍼가 쓰인다. HAVE_CMUX/HAVE_BUS 판정·keepalive 게이트는 유지.

## [claude-2.33.0] - 2026-06-24

> multi-round **작업 모드 신규**(순수 NTP mesh) + **Lead 자동주입 폴백 워치독** — 회의(board 브로드캐스트)에 더해 board 없는 점대점 분담 실행 모드를 추가하고, NTP 수신 간헐 실패를 inbox 직접 폴링으로 복구. (Lead=Claude NTP 고유 — Codex 포팅본 미적용, Claude 만 bump.)

### Added
- **multi-round 작업 모드 (§통신 모드 — 회의 vs 작업 / §Phase 4-T)** — 회의 모드(board 브로드캐스트 + 합의)와 별개의 **순수 NTP mesh** 통신 모드. board 없이 Lead↔mate 1:N(작업 지시) + mate↔mate N:N(직접 협의) 점대점, audit 은 agent-teams `work.md`(같은 work-id)에 Lead 단독 취합. 트리거 "작업지시"/"작업요청"/"의뢰". 차이는 **브로드캐스트(board) 유무** — 회의=의견 수렴, 작업=분담 실행.
- **Lead 자동주입 폴백 워치독 (용례 3)** — NTP 수신(Lead 자동주입) 간헐 실패(porter 수신 사고) 대응. 응답 대기 구간에서 N초 무응답이면 `team-lead.json` inbox 를 직접 폴링·드레인(read=false 확인 + 마킹). 버스 `watch` 데드락 워치독과 같은 사상. 회의·작업 모드 공통.

### Changed
- **트리거 라우팅 + Phase 1-0.5 통신 모드 결정** — "회의"/"미팅"/"논의"/"토론" → 회의 모드, "작업지시"/"작업요청"/"의뢰" → 작업 모드. agent-teams("코딩 작업"=실제 파일 수정)와의 경계 명시: "코드 만지면 agent-teams, AI 시각 섞어 분담하면 multi-round 작업 모드". description 에 작업 모드 트리거 추가.

## [claude-2.32.0 / codex-1.17.0] - 2026-06-24

> multi-round/agent-teams 워커 spawn **하네스 확정 + pane 레이아웃 자가교정 + kill 안전종료** — 실전 검증 세션에서 anchor/placeholder 우회 장치 제거, claudex 헬퍼 right→down 세로 스택, claude Agent 워커 spawn 시 cmux 비율 깨짐 자동 교정 워처(`cmux-rebalance-guard`), in-process 워커 좀비 핸들 방지 규칙을 확립. 모두 0.1초 pane-watch 모니터링으로 실측 확정.

### Added
- **`bin/cmux-rebalance-guard`** (신규 헬퍼, Claude·Codex 양측) — 워커 spawn 중 cmux 가 레이아웃을 재계산하며 Lead pane 비율을 깎는 것(2컬럼 60%→26%, claude Agent tool 워커 spawn ~1.4초 후 발생 — 실측)을 0.1초 폴링으로 ~1초 내 자동 교정. 마지막 spawn 후 grace-sec(기본 5초) 무틀어짐이면 자동 종료. `cmux-rebalance-watch`(settle 후 1회)와 달리 **매 재계산 반복 교정** — claude Agent 혼합 구성에 필수. Phase 0 자동 설치 + 워커 spawn 시작 시 백그라운드 1회 발사(multi-round 용례 1 / agent-teams §2-3).

### Changed
- **multi-round/SKILL.md §NTP 불변 하네스 규칙(H1~H4) 신규** — 우회 장치(anchor/placeholder/seed) 금지를 명시적 규칙으로 박음: H1 첫 워커=팀 생성자=참가자 / H2 "팀 생성 전용" Agent spawn 금지 / H3 첫 워커는 항상 claude(Agent tool) / H4 team-id 우회 생성 금지. (과거 `AGENTS.teams.md` 시절부터 anchor 없이 동작했음을 입증 — 실측 사고: placeholder 반복 생성.)
- **`deft-claudex-native-spawn`** — pane 분할을 `right` 단일 → **표준 2컬럼 레이아웃**(첫 워커 우측 새 컬럼, 이후 직전 워커 pane focus→`down` 세로 스택)으로 교정. team dir `.last-worker-pane` 상태파일로 헬퍼 간 연쇄. cmux `--surface` 단독 ref 가 caller stale 환경(비대화형 Bash·resume 후)에서 not_found 되는 것을 `--workspace` 컨텍스트 + focus→down 우회로 해결(모든 `new-split`/`send`/`focus-pane` 호출에 `DEFT_BASE_WORKSPACE` 동반).
- **multi-round·agent-teams/SKILL.md 종료 규칙 강화** — claude(Agent tool, in-process) 워커에 **SIGTERM/kill/pkill 폴백 절대 금지**. in-process 라 kill 이 통하지 않고 메인 세션 레지스트리에 **좀비 핸들**(`N teammate started` UI 잔재 — SendMessage·Esc·TaskStop·kill 다 안 먹어 Lead 세션 재시작만이 유일 해법)을 남긴다(실측 사고: SIGTERM 정리 → 10+ 좀비). `shutdown_request`→`shutdown_approved`/`teammate_terminated` 대기만 사용. claudex(외부 프로세스)는 pkill 폴백 유지(좀비 안 생김).
- **회의 워커 subagent_type 규칙** — 반드시 `"claude"`(범용). `claude-code-guide`·`Explore` 등 제한 타입은 SendMessage 도구가 비활성이라 Lead 보고 불가 → 조용한 데드락(실측: 보고 누락의 진짜 원인).
- **`multi-round-bus`** (Claude·Codex 양측 동기) — 깨우기 NTP(`ntpPush`) 기존 변경 유지 + 미러 동기.

## [claude-2.31.0] - 2026-06-24

> multi-round 워커 **보고 채널 원칙** 강화 — Lead 가 요청한 작업은 항상 통신 도구(NTP `send_message` / 버스 `post_message`)로 보고하고, 사용자가 TUI 에 직접 친 것만 세션 출력으로 답한다. (워커가 결과를 세션에 출력만 하고 `send_message` 미호출 → Lead 미수신하던 실측 사고 차단.)

### Changed
- **multi-round 페르소나(`agents/claude-participant.md`·`codex-participant.md`)** — §"보고 채널 원칙 (출력 ≠ 전달)" 신규 섹션: 요청 **출처**(통신 채널 주입 vs 사용자 TUI 직접 입력)에 따라 응답 채널을 구분. 통신 채널로 온 Lead·참가자 요청은 반드시 통신 도구(버스 `post_message` / NTP `send_message`)로 보고, 사용자 직접 입력만 출력. §금지의 "pane 출력만으로 응답 종료 금지"를 버스 전용에서 **NTP(`send_message`)까지 일반화**.
- **multi-round/SKILL.md §NTP 절차 3** — 워커 보고 규칙 명시(출력 ≠ 전달, `send_message` 강제 + 실측 사고 기록). 페르소나 §보고 채널 원칙과 SSOT 연결.

## [claude-2.30.0] - 2026-06-24

> 이종 AI 네이티브 팀 통신의 확정 기술명 **NTP(Native Teammate Protocol)** 명칭 통일 + multi-round 가이드에 NTP **운영 용례 3종**(팀원 spawn · 기존 세션 resume 편입 · NTP 메시지 송수신) 추가.

### Added
- **multi-round/SKILL.md §운영 용례** — §"NTP — claudex 네이티브 팀원" 섹션에 복사실행 가능한 용례 4종 추가(모두 실측 검증): ⓪ Lead 세션 ID 확인(`$CLAUDE_CODE_SESSION_ID`) + **team-id 와 다른 값임을 명시**(leadSessionId 조차 팀 자체 id 라 세션 ID 아님), ① team-id 획득 + claude(`Agent`)·claudex(`deft-claudex-native-spawn`) 팀원 spawn, ② 기존 claudex 세션을 `--claude-team … --claude-team-agent … resume <uuid>` 로 **대화 맥락 보존한 채 팀원 편입**, ③ `SendMessage` NTP 송수신 + `<teammate-message>` 자동주입 + `shutdown_request` 종료. 추상 절차(why)와 분리된 명령(how) 레퍼런스.

### Changed
- **multi-round/SKILL.md** — §"claudex 네이티브 팀원" 섹션 제목에 `NTP —` prefix 추가 + 도입부에 NTP 한 줄 정의(파일 inbox 네이티브 팀 통신을 이종 AI 에 이식, `send_message` 직접 통신) 삽입. 통신 우선순위 매트릭스의 "Claude 네이티브 inbox" 라벨을 "NTP — Claude 네이티브 inbox" 로 보강. 기존 표현·섹션 참조(`§claudex 네이티브 팀원`)는 유지해 링크 무손상.

### Note
- claudex 측 `docs/claudex-customizations.md` §5-1 제목도 같은 NTP 명칭으로 통일(별도 repo, 로컬 문서 — deft 버전과 무관). 메모리(reference_ntp.md)는 기 통일됨.

## [claude-2.29.0] - 2026-06-23

> agent-teams 혼합 claude+claudex 네이티브 팀(§2-5, 2.28.0) **철회** — agent-teams 는 다시 Claude 전용으로 복원. 이종 AI 네이티브 통신(NTP)은 multi-round 로 일원화한다. NTP 헬퍼 `deft-claudex-native-spawn` 는 multi-round 소속으로 유지(철회 대상 아님).

### Changed
- **agent-teams §2-5(혼합 claude+claudex 팀) 철회** — `agent-teams/SKILL.md` 를 1071d77 직전 상태로 복원(§2-5 혼합팀 절차 + §0 `deft-claudex-native-spawn` 설치 안내 + §1 멘탈모델 혼합 노트 제거). agent-teams 는 Claude 전용 협업 도구로 환원.
- **방향 정리**: 이종 AI(Claude+claudex) 네이티브 팀 통신 = **NTP(Native Teammate Protocol)** 로 명명하고, agent-teams 가 아니라 **multi-round** 에서 다룬다(헬퍼의 고향). agent-teams 에 claudex 를 끼우던 2.28.0 방향을 되돌림.

### Kept (철회 대상 아님)
- **`deft-claudex-native-spawn` 헬퍼 유지** — config.json members 자동 등록(팀원↔팀원 NTP 라우팅 인프라)·`exec claudex` 기동 포함. bin 공용 위치(`plugins/deft/bin/`) 불변, multi-round SKILL §claudex 네이티브 팀원 안내가 사용처. (2.28.0 에서 강화된 헬퍼 기능은 NTP 자산이라 보존)

### Note
- 다운그레이드 금지 정책(§1-4)에 따라 revert 가 아니라 2.29.0 forward 로 진행.

## [claude-2.28.0] - 2026-06-23

> 혼합 claude+claudex **네이티브** 에이전트팀 지원. claudex(0.139.2+, shutdown 자기종료 구현)를 Claude 네이티브 팀에 팀원으로 합류시켜, claude·claudex 팀원이 한 팀에서 네이티브 inbox 로 통신·정상종료한다. (Claude-core 변경 0 — Lead 는 평범한 `SendMessage` 만.)

### Added
- **agent-teams §2-5: claudex 네이티브 팀원 + 혼합 팀** 절차. claude 팀원=`Agent` tool, claudex 팀원=`deft-claudex-native-spawn`, 둘 다 같은 `~/.claude/teams/<id>/inboxes/` 공유. Lead↔팀원·**팀원↔팀원(claude↔claudex 양방향)** 네이티브 통신, 전원 shutdown 자기종료 + pane auto-close (+미종료 시 force-kill 폴백). §0 에 `deft-claudex-native-spawn` 자동설치, §1 멘탈모델에 혼합 팀 노트.

### Changed
- **`deft-claudex-native-spawn` 헬퍼 강화** (혼합 팀 필수):
  - **config.json members 자동 등록** — 팀원↔claudex 라우팅 필수. Lead→claudex 는 미등록도 배달되나, 다른 *팀원*의 `SendMessage` 는 수신자가 members 에 등록돼야 라우팅됨(미등록 시 조용히 드롭, 실측). tmuxPaneId 는 pane 셸 `$TMUX_PANE` best-effort 캡처(빈 값이어도 name 기반 라우팅 동작).
  - **`exec claudex` 기동** — claudex shutdown 자기종료(`process::exit`) 시 pane 에 프로세스가 남지 않아 cmux 가 pane 자동 close. force-kill·크래시 시에도 동일.

### Verified
- 혼합 1+1 풀사이클 E2E (2026-06-23, claudex 로컬 debug 빌드): 스폰 → Lead↔both·팀원↔팀원 양방향(수신 inbox from-field 객관 확인) → 전원 shutdown 자기종료(PID 사멸 실측) → 전원 pane auto-close → 잔존 0. (단위테스트 통과 ≠ E2E — 실제 프로세스 종료까지 실측이 합격 기준.)

## [claude-2.27.0] - 2026-06-22

> claudex 네이티브 팀통신 이식(별도 작업, claudex 0.139.1+)에 대응한 Lead-side 통합. Claude↔claudex 양방향 네이티브 통신을 E2E 실증(도구 경로 + 평문)한 뒤, multi-round 가 버스 대신 Claude 네이티브 inbox 로 claudex 와 통신할 수 있게 함. **Claude-core 변경 0** — Lead 는 평범한 `SendMessage` 만.

### Added
- **`deft-claudex-native-spawn` bin** — claudex(0.139.1+)를 Claude 네이티브 팀원으로 cmux pane 에 기동(`--claude-team`/`--claude-team-agent` binding + readiness 가드). 이후 Lead 는 `SendMessage(to:"<name>")` 로 직접 네이티브 통신(버스/노크 불요). `CLAUDEX_NATIVE_BIN` 으로 설치 전 built 바이너리 테스트 가능.
- **multi-round 통신 우선순위 매트릭스에 "Lead=Claude + claudex(0.139.1+) → Claude 네이티브 inbox 1순위, 버스 폴백" 행 + §claudex 네이티브 팀원 절차** (팀 materialize→team-id 획득→bin 기동→SendMessage). binding 미지원/claudex-Lead/cmux 외부면 버스로 자동 폴백.
- multi-round Phase 0 에 `deft-claudex-native-spawn` 조건부 자동 설치.

### Notes
- team-session-id 는 Lead 의 `Agent` spawn 결과(`<name>@session-<id>`)에서만 신뢰 획득(팀 config 의 `leadSessionId` 는 팀 자체 id 라 Claude 세션 id 와 달라 자동발견 불가 — 실측).
- 전체 deft 경로 E2E 는 claudex 0.139.1 설치 후 진행 예정. 현재는 built 바이너리로 양방향 왕복(수신·발신·평문) 실증 완료.

## [codex-1.16.0] - 2026-06-18

> Claude 측 검증 완료 패턴(claude-2.24.0~2.26.0)을 codex 측에 미러. 형태는 Claude 에서 3회 클린 사이클(3워커 consensus 40~50s + 4워커 research debate)로 확정 후 적용. Claude 측은 변경 없음.

### Added
- **`deft-cmux-shim` + `deft-log` bin (Claude 측과 byte-identical 동기화)** + codex multi-round/multi-check preflight 조건부 자동 설치. cmux 비대화형 PATH 부재(신 cmux 의 precmd 훅 PATH 주입) 대응 + 오케스트레이션 관찰성 로그.
- **multi-round 워커 inject brevity time-box** — 회의 워커가 web search 로 라운드 정체시키는 위험 제거(실측). + 세션 시작 진행 로그(`tail -f` 안내).

### Changed
- **multi-round readiness 를 fail-fast 게이트로 강화** — 워커 pane 쉘 미기동 시 BLOCKED 기록 + 부팅 중단 + 사용자 보고(미기동 pane 오발 send 방지).
- **multi-check preflight 에 cmux-shim 설치** — Lead 의 bare cmux(identify/focus-pane) 가 비대화형 셸에서 깨지던 것 방지.

## [claude-2.26.0] - 2026-06-18

> 멀티라운드 속도 재테스트(speed2 — 셋업→3자 CONSENSUS 50s 클린 사이클)에서 검증된 패턴의 **스킬 간 교차 적용(harmonize)**. Claude 측만 변경 → `codex-1.15.2` 유지.

### Added
- **multi-round 워커 inject 에 brevity time-box (multi-check 검증 패턴 이식)** — 회의 워커(claudex/codex)가 web search 로 수 분 늘어져 라운드가 정체되는 위험. 워커 표준 inject(버스 첫 메시지)에 "핵심 권장 + 근거 1~3줄 간결, **과도한 web search·장문 분석 금지**, 아는 지식으로 신속 응답" 추가. multi-check Phase 1 time-box 와 동일 사상. 실측(speed2): 적용 시 3워커 응답 ~30s, 셋업 포함 50s 에 3자 CONSENSUS.

### Notes (선검토 후 미적용 — 사유 기록)
- agent-teams brevity: **미적용** — 코드 작업 팀원은 thorough 해야 하고 web search 정체 위험이 낮음(용도 상이).
- multi-check deft-log: **미적용** — 세션 dir 개념이 없고, Agent-tool pane 라이브 출력 + reviewer SendMessage 보고가 이미 관찰성 제공(관찰성 모델 상이).
- zsh-안전성 감사: 스킬 본문 bash 는 `${!arr[@]}`·`set -- $`·`declare -A` 전무로 **안전**(speed2 실패는 테스트 핸드롤 한정). deft-test §4-1 에 "단일 bash 스크립트 오케스트레이션" best-practice 기록(비배포).

## [claude-2.25.0] - 2026-06-18

> 사용자 실측(멀티라운드 재테스트 preflight)에서 발견·재조사. Claude 측만 변경 → `codex-1.15.2` 유지. codex 미러는 형태 확정 후.

### Fixed
- **cmux CLI 가 비대화형 셸 PATH 에 없어 multi-round pane 회의가 통째로 폴백되던 버그 (사용자 실측·재조사)** — cmux 신버전(2026-06~)은 `cmux` 를 PATH 바이너리/alias/함수가 아니라 셸 통합 precmd 훅(`_cmux_fix_path`)으로 **첫 대화형 프롬프트에 1회** `Resources/bin` 을 PATH 앞에 주입해 노출한다. 따라서 Claude/Codex 의 **비대화형 Bash 도구 셸**에선 프롬프트가 없어 훅이 안 돌고 `cmux` 가 `command not found` → 스킬의 bare `cmux new-split`/`send` 가 깨지고 `HAVE_CMUX=0` 으로 오판(pane 회의 폴백). 구버전은 비대화형에서도 동작했기에 "갑자기 안 됨" 으로 관측됨. (multi-check 은 pane 생성을 Agent 도구로, 리밸런싱을 bin 으로 처리해 Lead 의 bare cmux 실패가 silent 라 무사 — 비대칭. bin 들은 이미 `_resolve_cmux_bin`/`CMUX_BUNDLED_CLI_PATH` 로 hardening 돼 있었음.)
  - **수정**: `deft-cmux-shim` wrapper 신규 + 3개 스킬(multi-round/agent-teams/multi-check) preflight 가 **`cmux` 가 PATH 에 없을 때만** 이를 `~/.local/bin/cmux` 로 설치(조건부 gap-fill — 구버전·기존 cmux 를 가리지 않음). wrapper 는 매 호출 `CMUX_BUNDLED_CLI_PATH`→`CMUX_CLAUDE_TEAMS_CMUX_BIN`→`CMUX_BIN`→표준 설치 경로 순으로 진짜 cmux CLI 를 해석해 exec(정적 symlink 보다 환경 변화·버전 차이에 강함; `cmux-rebalancing` 의 `_resolve_cmux_bin` 과 동일 체인). 자기 재귀 방지 위해 wrapper 는 `command -v cmux` 미사용(env/표준경로만). → 신·구 cmux + 다양한 환경에서 bare `cmux` 동작 보장, 스킬 57곳 무수정.

## [claude-2.24.0] - 2026-06-18

> 사용자 지시(멀티라운드/에이전트팀 테스트 관찰성). Claude 측만 변경 → `codex-1.15.2` 유지. codex multi-round 미러는 형태 확정(첫 테스트) 후 적용 예정.

### Added
- **`deft-log` 진행 로그 헬퍼 (오케스트레이션 관찰성 SSOT)** — multi-round/agent-teams 의 Lead 오케스트레이션(pane 분할·readiness 대기·워커 부팅·페르소나 주입·라운드/단계 게이트·정리)은 `cmux send`/`Agent` spawn 으로 조용히 진행돼 "지금 무엇을 하는지"가 안 보였다. 특히 워커 셸 **lazy-init 으로 멈추면 무진행 침묵**이 생겨 위험했다 — 사용자가 빈 pane 을 보다 다른 pane 을 건드리면 의도치 않은 명령이 실행될 수 있다(실측 — FOMC 멀티라운드 셋업 차단 사례). `deft-log <session_dir> <level> <msg>` 가 단계마다 타임스탬프 한 줄을 `<session_dir>/orchestration.log` 에 append + stderr echo → 사용자가 `tail -f` 로 **실시간 관찰** + 실패 시 **정확히 어디서 멈췄는지 사후 추적**. 레벨 `STEP/WAIT/DONE/BLOCKED/WARN/ERROR`, `--tail [N]` 조회 지원. deft-model/deft-review 와 동일한 단일 bin 헬퍼 패턴.
- **multi-round/agent-teams 진행 로그 배선** — multi-round: Phase 0-F 자동설치 + 세션 시작 시 `tail -f` 안내 + Lead 등록·pane 분할·rebalance·readiness·부팅·정리 마일스톤 로그. agent-teams: §0-1 자동설치 + §2-4 관찰성 서브섹션 + 팀원 spawn·정리 마일스톤 로그.

### Changed
- **multi-round readiness 를 fail-fast 게이트로 강화** — 종전엔 워커 pane 쉘 readiness 타임아웃 시 `echo WARN` 한 줄 뒤 **그대로 부팅을 진행**해, 미기동 pane 에 `cmux send` 가 흘러 입력이 유실되거나(조용한 실패) 사용자가 그새 다른 pane 으로 전환했을 때 잘못된 pane 에 명령이 들어갈 수 있었다(실측 위험). → 타임아웃 시 `deft-log BLOCKED` 기록 + **부팅 중단 + 사용자에게 "화면 전면 활성 후 재개" 보고**. 무진행 침묵으로 끌지 않는다.

## [claude-2.23.0] / [codex-1.15.2] - 2026-06-17

### Added
- **rebalance clean-grid 빠른 경로 `cmux-rebalancing --fast` (사용자 실측 기반 최적화)** — clean Lead 워크스페이스(spawn 전 pane 1개)에서 Agent-tool spawn 의 squish 는 **결정론적**(실측: 1명→Lead50%, 2+명→Lead26.1%·우측73.9%, 우측 행 raw 상태 이미 균등)이라, robust 다회 수렴이 불필요하다. `--fast` 는 **단발 column push + row-equalize skip + 폴링 최소**로 동일한 60:40 결과를 ~4s→~2s 에 낸다(실측 검증). 워처(`cmux-rebalance-watch`)에 4번째 인자 `FAST` 추가, multi-check/agent-teams 가 **BASE==1(clean Lead)일 때만** `FAST=1` 전달. 기존 pane 이 있으면(BASE>1) 자동으로 robust 경로 유지.

### Changed
- **rebalance 전제 명문화 + 비-clean 워크스페이스 동작 규명 (사용자 지시 조사)** — "Lead 60%/리뷰어 40%" 시각 모델은 **clean Lead 워크스페이스 전제**임을 실측으로 확인·명문화. 기존 pane 이 섞이면 방식별로 다르게 degrade(기능은 정상, 시각만 영향):
  - **Agent-tool + 우측 pane**: 새 리뷰어가 기존 우측 컬럼에 섞임 → rebalance 가 사용자 pane 도 리사이즈(소유권 영향).
  - **Agent-tool + 아래 pane**: 단일 컬럼에 행으로 stack → **1컬럼이라 rebalance no-op**(60:40 안 생김, Lead=1/N행).
  - **multi-round(new-split)**: Lead 를 쪼개 워커 전용 컬럼 생성(다른 컬럼 미접촉), 아래 pane 있으면 비그리드 → rebalance 컬럼 오측정.
  → 그래서 `--fast` 는 clean 케이스로 게이트하고, 비-clean 은 robust 경로(안정대기+수렴)로 처리.
- **codex `cmux-rebalancing` 동기화** — `--fast` 옵션을 codex 측 사본에도 반영(공유 헬퍼 parity). codex 스킬은 Option 2 라 `--fast` 를 호출하진 않음(미사용 옵션, parity 목적).

## [claude-2.22.3] - 2026-06-17

### Fixed
- **gemini 리뷰어가 매번 force-fallback(SIGTERM) + orphan pane 을 내던 원인 규명·수정 (사용자 지시 조사)** — claudex/claude 는 ~2-4s graceful 종료인데 gemini 만 반복적으로 종료가 ~12s 지연돼 grace 창을 넘겨 강제 종료+orphan. **단일 gemini 리뷰어 격리 측정**으로 원인 확정: shutdown_request 수신 시 haiku 래퍼가 **shutdown_response 외 추가 작업(느린 gemini CLI ~12s 재호출/재검토)** 을 해 종료가 지연. 페르소나에 "shutdown 시 **오직 shutdown_response 만**, 추가 CLI 호출·재검토 금지" 를 명시하니 **~2s graceful 종료**로 회복(실측). → 리뷰어 페르소나 3종 §종료 프로토콜에 "추가 작업 금지" 강화. (gemini CLI 가 trivial 쿼리에도 ~12s 걸리는 특성이 이 지연을 치명적으로 만든 배경 — claudex/claude 는 빨라 grace 안에 끝났음.)

## [claude-2.22.2] - 2026-06-17

> 모두 사용자 실측 피드백 반영. Claude 측만 변경 → `codex-1.15.1` 유지.

### Fixed
- **리뷰어 보고가 `summary` 누락으로 실패하던 버그** — 리뷰어 페르소나가 `SendMessage(to:"team-lead", message:"<문자열>")` 로 보고하는데, SendMessage 는 **message 가 문자열이면 `summary` 필수** → 누락 시 `Error: summary is required when message is a string` 로 보고 실패(실측: gemini 리뷰어). 게다가 보고 실패로 리뷰어가 stuck → shutdown_request 정상 응답 못 함 → 강제폴백 SIGTERM → **orphan pane** 까지 연쇄. → 페르소나 3종 보고 규약에 `summary:"<engine> 검토 결과"` **필수 명시**.
- **`cmux-rebalance-watch` 가 순차 등장하는 pane 을 다 못 기다리거나 안정대기 ~1s 를 낭비하던 문제** — panes 는 한꺼번에가 아니라 **하나씩 순차 등장**(사용자 실측). 종전 "BASE 초과 + 3회 안정"은 ① 인터-pane 간격이 안정창(~0.9s)보다 크면 일부 pane 만 보고 조기발사 위험, ② 이미 다 떠 있어도 안정대기 ~1s 소요. → **목표 최종 pane 수 `EXPECTED`(= BASE + spawn 수)를 워처 3번째 인자로 주입**, `n >= EXPECTED` 도달 즉시 발사(조기발사·불필요 안정대기 제거). multi-check Phase 3 + agent-teams §2-3 에 EXPECTED 캡처·전달 반영.

### Changed
- **Codex-family reviewer 표시 이름이 실제 CLI 반영** — claudex 를 쓰는데 `@codex-reviewer` 로 떠 혼동(사용자 지적). → multi-check 가 spawn 시 `command -v claudex` 로 판정해 **claudex 사용 시 `@claudex-reviewer`, 없으면 `@codex-reviewer`** 로 명명(`CODEX_REVIEWER_NAME`). Phase 5 정리 루프도 해당 변수 사용.

## [claude-2.22.1] - 2026-06-17

### Fixed
- **`cmux-rebalance-watch` 가 rebalance 못 하고 cap 까지 헛돌던 버그 (2.22.0 회귀 — 사용자 실측)** — 워처가 baseline(`init`)을 **자기 시작 시점**에 캡처했는데, 워처는 spawn 과 같은 메시지에서 발사돼 **보통 panes 가 이미 생성된 뒤 시작**된다. 그래서 `init` 이 현재 pane 수(부풀려진 값)로 잡혀 settle 조건 `n > init`(증가)이 **영원히 거짓** → 80회 cap(~수십 초)까지 헛돌다 끝에야 rebalance(사용자 화면엔 "리밸런싱 실패"로 보임). 로그 진단: `START init=4 … panes=4` 고정.
  - **수정**: baseline 을 **skill 이 spawn 전에 캡처해 워처에 인자로 전달**(`cmux-rebalance-watch "$LEAD_REF" "$BASE"`). 워처는 주입된 BASE 기준으로 `n > BASE && settle` 판정 → panes 가 이미 생성됐어도 `n(4) > BASE(1)` 즉시 성립해 ~1s 내 발사. BASE 미주입 시 폴백(증가 요건 없이 안정화만, 조기발사 방지 최소 대기). multi-check Phase 3 + agent-teams §2-3 에 BASE 캡처·전달 반영.

## [claude-2.22.0] - 2026-06-17

> Claude 측만 변경 (codex multi-check 은 cmux-split Option 2 로 rebalance 타이밍이 이미 최적 + 페르소나 미참조 → `codex-1.15.1` 유지).

### Added
- **rebalance 타이밍 워처 `bin/cmux-rebalance-watch` 신설 (사용자 실측 피드백)** — Agent-tool spawn(multi-check/agent-teams)에서 rebalance 가 "haiku 부팅·shell 실행 **이후**"로 한참 늦게 뜨던 문제. 원인: 종전엔 "전부 spawn **반환** 후 Lead 가 별도 턴에서 `cmux-rebalancing` 수동 호출" → ① Agent-tool 반환 지연 ② Lead 턴 생성 지연이 누적. rebalance 는 pane geometry 만 필요하므로, **spawn 묶음과 같은 메시지에서 워처를 `run_in_background` 로 띄워 `tmux list-panes` 폴링 → panes 가 생겨 settle 되는 즉시** `cmux-rebalancing` + Lead focus 복원을 발사하도록 변경. settle 감지(증가 후 안정)라 baseline 불필요, 미감지 시 ~24s 상한 후 1회 실행(누락 방지). multi-check Phase 3 + agent-teams §2-3 + 양 skill preflight 자동설치 반영.

### Changed
- **codex 리뷰어 비정상 모니터링 차단 (사용자 실측)** — `deft-review codex`(claudex web search)가 **115+ 쿼리로 수 분간** 늘어져 Bash timeout(120s)을 초과하면, haiku 래퍼가 **background 실행 + Monitor + 결과파일 반복 Read(폴링)** 로 우회해 "Monitor event/계속 진행 중/파일 확인" 반복 노이즈를 냈다(gemini·claude 리뷰어는 빨라서 미발생 — 속도 비대칭이 원인). 두 갈래로 차단:
  - **페르소나 3종 §실행 규율**: `deft-review` 는 **foreground 1회 실행**, background/Monitor/파일폴링 **금지**, 타임아웃 시 우회 말고 부분출력·타임아웃 사실을 그대로 보고.
  - **multi-check Phase 1 프롬프트 time-box**: "빠른 교차검증 — 신속히, 핵심 출처 1~2개로 결론, 과도한 web search 자제" 를 프롬프트 말미에 명시(claudex/codex 무한검색 방지). 심층 사실검증은 `deep-research` 스킬 권장. → codex 8분 병목도 함께 완화.

## [claude-2.21.0] - 2026-06-17

> Claude 측만 변경 (codex multi-check 은 페르소나 미참조라 무관 → `codex-1.15.1` 유지).

### Added
- **리뷰어 실행 헬퍼 `bin/deft-review` 신설** — `deft-review <codex|claude|gemini> [prompt]`(prompt 생략 시 stdin). 리뷰어 CLI 호출의 **CLI 선택(claudex→codex 폴백)·실행 플래그·모델·추론수준을 한 곳에 캡슐화**한다. `deft-model` 과 동일한 SSOT 사상.

### Changed
- **리뷰어 페르소나 3종에서 raw bash 블록 제거 (사용자 UX 요청)** — haiku 래퍼 리뷰어의 spawn 프롬프트(=대화형 pane 에 노출되는 지시문)에 `if command -v claudex…fi` / `"$CODEX_CLI" -a never exec …` 같은 **구현 코드가 그대로 노출**되던 것을, `deft-review <engine>` **한 줄 prose** 로 대체. 그 코드는 실행 코드가 아니라 haiku 에게 주는 지시문이라(haiku 가 자기 Bash 도구로 실제 실행) 화면 노출이 불필요했음. 폴백(헬퍼 미설치)만 1줄로 축약 유지.
- **부수 효과(속도·비용)**: 페르소나 프롬프트가 짧아져 haiku 가 첫 Bash 호출까지 읽을 양이 줄어듦 → 리뷰어 첫 동작 지연·토큰 비용 소폭 감소.
- multi-check Phase 2 preflight 에 `deft-review` 자동설치 추가(`cmux-rebalancing`/`deft-model` 과 동일 패턴).

## [claude-2.20.0] - 2026-06-17

> Claude 측만 변경 (codex multi-check 은 인라인 프롬프트라 페르소나 파일 미참조 + close-surface 모델 → 무관, `codex-1.15.1` 유지).

### Changed
- **multi-check 리뷰어 per-report 종료 (idle 대기 제거 — 사용자 요청)** — 기존엔 리뷰어 3종이 보고 후 **idle 대기**하다가 Lead 가 취합을 마치면 **동시 일괄 종료**했다. 1-shot 리뷰어는 보고 후 추가 요청이 없으므로, **각 보고가 도착하는 즉시 그 리뷰어에게만 `shutdown_request` 발송** → 보고순으로 **pane 이 순차 종료**되도록 변경(Phase 4 에 per-report 종료 명문화, Phase 5 ① 은 누락분 보강으로 축소). 깔끔한 종료 메커니즘(`shutdown_response{approve:true}`)은 유지 — self-kill 아님. rebalance 는 깜빡임 방지를 위해 최종 1회(④)만. 리뷰어 페르소나 3종의 "idle 대기 가능" 문구도 "보고 직후 shutdown_request 에 즉시 응답" 으로 정리.

### Fixed
- **PERSONA_DIR 가 구버전 페르소나를 인라인하던 버그 (배포 시 종료 프로토콜 무력화)** — `ls -d <marketplace> <cache>/*/... | head -1` 이 **버전 정렬 없이** ls 알파벳 첫 항목을 집어 가장 오래된 캐시(`claude-2.0.0`, 종료 프로토콜 없음)를 선택 → 2.19.0 fix 가 배포 단계에서 무력화됨(실측: 캐시 21개 버전 누적 환경에서 발견). marketplace 우선 의도도 ls 정렬(`cache` < `marketplaces`)에 깨져 있었음. → **버전 독립 marketplace 경로를 명시적으로 먼저 체크, 없으면 캐시 `sort -V | tail -1`** 로 수정. (같은 SKILL 의 bin 헬퍼 설치는 이미 `sort -V|tail -1` 인데 PERSONA_DIR 만 누락된 일관성 결함.)
- **agent-teams 페르소나 경로 버전 미핀 (동일 클래스)** — §4-3 task instruction 이 팀원에게 "agents/<role>.md, skill 경로는 plugin cache 하위" 로만 줘 버전이 핀되지 않아 구버전 페르소나를 읽을 여지. → 버전 독립 marketplace 우선 + 캐시 `sort -V|tail -1` 폴백으로 경로 해석 명문화.

## [claude-2.19.0] - 2026-06-17

> Claude 측만 변경 (codex multi-check 은 `cmux close-surface` + 추적 surface 모델이라 본 건과 무관 → `codex-1.15.1` 유지, §1-2 독립 bump).

### Fixed
- **multi-check 마지막 리뷰어 pane 미닫힘 (다음 스킬로 잔존)** — multi-check 가 끝나고 multi-round 가 시작되는 시점에도 `codex-reviewer` pane 이 닫히지 않고 남는 현상(사용자 스크린샷 제보). 근본 원인 2건:
  - **(A) 페르소나에 종료 프로토콜 부재** — haiku 래퍼 리뷰어가 Lead 의 `shutdown_request` 를 일반 채팅으로 보고 **"종료합니다" prose 만 출력**, `shutdown_response{approve:true}` 를 호출하지 않아 프로세스가 안 죽고 pane 잔존. → `agents/{codex,claude,gemini}-reviewer.md` 에 **§종료 프로토콜** 추가: `shutdown_request` 수신 시 prose 금지, `SendMessage(message:{type:"shutdown_response",request_id,approve:true})` **호출 의무** 명시.
  - **(B) Lead 정리에 검증·강제 폴백 부재** — Phase 5 ① 이 `shutdown_request` 만 보내고 자가종료를 신뢰해 넘어감. → **② 종료 검증 + 강제 폴백** 신설: graceful 유예(~8초) 후에도 살아있는 **본 세션 그 리뷰어 프로세스만** SIGTERM(cmux 가 pane 자동 close), 이어 **③ orphan pane sweep**(프로세스 죽음 + pane 잔존만), **④ 레이아웃 복원**(`cmux-rebalancing` + Lead focus 복원)으로 다음 스킬이 깔끔한 단일 pane 에서 시작되도록.
- **정리 소유권 pgrep 전역매칭 결함 (agent-teams §9-1 / multi-check Phase 5)** — orphan 판정의 `pgrep -f -- "--agent-name $N"` 이 **호스트 전역·비앵커 substring** 이라 ① 타 세션 동명 팀원이 살아있으면 본 세션 orphan 을 "생존"으로 오판(false-negative — 미정리 + "정리완료" 오보고), ② `qa-sql`/`backendDev-sql` 등 prefix 충돌. → **세션+이름 단일토큰 앵커 `pgrep -f -- "--agent-id $N@$TEAM_NAME"`** 로 교체(agent-teams 팀 검증에서 발견). cmdline 에 `--agent-id <name>@session-<id>` 인접 실재 확인.

### Added
- **agent-teams §9-1 teardown 레이아웃 복원** — 팀원 pane close 후 `cmux-rebalancing` + Lead focus 복원 추가(multi-round §5-B 와 동일 패턴). 부분 종료가 흔한 agent-teams 에서 빈 행 흡수·focus 튐 정리(기존엔 누락 — 자매 스킬과 비대칭).
- **cmux `tmux` 호환 shim 동작 명문화 (실측)** — cmux 환경의 `tmux` 는 일부 서브커맨드만 번역하는 shim 으로, **`#{pane_dead}`/`#{pane_pid}` 는 빈 값 반환**(pane 생사 판정 불가). 반면 `kill-pane`·`list-panes -F '#{pane_id}'` 는 지원. 그래서 정리 로직은 그 포맷에 의존하지 않고 **세션앵커 `pgrep`(프로세스 생사) + `tmux list-panes`(pane 존재) + `kill-pane`** 만 사용하도록 SKILL 에 캐비엇 명시. (팀원이 제안한 `#{pane_dead}` 기반 수정안을 환경 실측으로 반증해 채택하지 않음.)

## [claude-2.18.1] / [codex-1.15.1] - 2026-06-17

### Fixed
- **multi-round pane down-split 플래그 오류 (`--pane` → `--surface`)** — `cmux new-split` 의 올바른 플래그는 `--surface`(또는 `--panel`)인데 multi-round(claude+codex)가 `--pane "<prev>"` 를 써서 2번째 이후 워커 pane 분할이 **"not_found" 로 실패**(워커가 우측 컬럼에 안 쌓임 — 실측). 캡처한 `W*_SURFACE` 로 `--surface "$W1_SURFACE"` 호출하도록 수정. **우측 pane 을 아래로 분할하면 컬럼 비율(60:40)이 유지**됨을 실측 확인.
- **rebalancing 타이밍 정정 (multi-check/agent-teams)** — 직전 2.18.0 의 "Option 1(첫 spawn→rebalance→나머지)"은 무효였음: Agent-tool spawn 은 cmux 가 Lead 기준으로 재분할해 **매 spawn 마다 Lead pane 이 다시 찌부러지고**(실측 60%→26%→복원), 중간 rebalance 가 다음 spawn 에 덮어써짐. → **"전부 spawn 후 단일 rebalance 1회"**로 정정. rebalancing 은 pane geometry 만 정렬하는 **독립·비동기** 작업이라 AI headless 작업과 무관하게 호출 가능. (cmux-split 기반 multi-round/codex multi-check 은 down-split 이 비율을 유지하므로 해당 없음 — Agent-tool 한정 현상.)

## [claude-2.18.0] / [codex-1.15.0] - 2026-06-17

### Changed
- **pane 분할·밸런싱 타이밍 (UI 최적화 — 사용자 실측 피드백)** — spawn 시 "찌부러진 비율" 노출 시간을 최소화하도록 스킬별 spawn/밸런싱 순서를 명문화:
  - **Agent-tool 기반(multi-check / agent-teams)**: `Agent` spawn 은 pane 생성 + AI 기동이 **원자 결합**이라 빈 pane 선분할이 불가 → **Option 1**(① 첫 1명 spawn → ② `cmux-rebalancing` 컬럼 60:40 확정 → ③ 나머지 spawn(확정 컬럼 안 스택) → ④ row 균등화).
  - **cmux-split 기반(multi-round / codex multi-check)**: pane·CLI 분리 가능 → **Option 2**(전체 pane 먼저 분할 → 밸런싱(컬럼+row 동시) → 그다음 CLI 부팅). 느린 CLI 부팅 전에 레이아웃 안정.
  - rebalancing 타이밍 규칙을 multi-check 뿐 아니라 **전 스킬 공통** 적용(claude multi-check/agent-teams/multi-round + codex multi-round/multi-check).

### Added
- **종료·정리 소유권 안전 (전 스킬, 파괴 행위 가드)** — shutdown / `tmux kill-pane` / `close-surface` 는 **본 Lead 세션이 spawn 한 팀원/워커만** 대상으로 명문화. cmux **다중 워크스페이스·다중 세션** 환경에서 다른 세션/워크스페이스 pane 을 절대 건드리지 않도록: 본 세션 team config 의 tmuxPaneId · 본 실행이 추적한 `W*_SURFACE`/`$R*` 만 사용, **전체 tmux/surface 순회·와일드카드 kill 금지**, `--parent-session-id` 로 소속 확인.
- **orphan pane 정리법 (실측 확인)** — graceful shutdown 이 닫지 못한 잔여 pane(세션 종료·pane 잔존)은 cmux `close-surface` 로 안 닫힌다 → **본 세션 소속 pane 의 tmuxPaneId 로만** `tmux kill-pane -t <id>` 직접 정리. (force-kill 이 pane 을 orphan 으로 남기는 문제 + graceful shutdown 의 느린 종료 대응.)

## [claude-2.17.0] / [codex-1.14.3] - 2026-06-16

### Changed
- **Agent Teams API 마이그레이션: `TeamCreate`/`TeamDelete` 폐지 → 암묵적 팀** (현행 Claude Code v2.1.17x 가 명시적 팀 생성/삭제 도구를 폐지하고 첫 `Agent` spawn 시 `session-<id>` 팀을 자동 생성·세션 종료 시 자동 삭제하는 모델로 전환 — 공식 문서 + probe 실측 확인). 영향:
  - **agent-teams** (claude): SKILL/GUIDE 전반의 `TeamCreate`/`team_name` 제거, Agent 템플릿에서 `team_name` 인자 삭제(`model:"opus"` 유지), §0-3 한계·§2 도구표·§3 데이터경로를 "세션 자동 팀" 기준으로 갱신, 정리는 `SendMessage` shutdown_request 기준. **페르소나 prompt-Read 주입·역할 테이블·`agents/*.md` 는 무변경(보존)**.
  - **multi-check** (claude): 깨진 `TeamCreate`-preferred 경로 제거, 리뷰어를 **fan-out 서브에이전트 단일 경로**(`run_in_background`, `team_name` 없음)로 통일.
- **multi-check 리뷰어 서브에이전트 등록 정비**: `subagent_type:"codex-reviewer"`(스킬 하위 `agents/` 는 표준 등록 경로가 아니라 현행 빌드에서 미해석) → **`subagent_type:"claude"` + 페르소나 prompt 인라인**(Lead 가 `agents/<reviewer>.md` 를 Read 해 spawn prompt 에 주입). 페르소나 내용은 그대로 보존.

### Added
- **agent-teams §7-5 `/workflows` 오프로드 패턴** — Lead/팀원이 대규모·결정론적 fan-out 을 Claude Code Workflow 도구로 오프로드 가능(probe 실측: 팀원도 Workflow 사용 가능, Lead workflow ↔ 활성 팀 동시 동작, 워크플로 서브에이전트는 cmux 팀 pane 미생성). 팀의 양방향 대화와 직교하는 보조 수단.
- **트랩 명문화** — ① 팀원 `model` 미지정 시 차단된 `fable` 기본값으로 떠 조용히 실패 → `model` 필수 명시(공식: 팀원은 Lead 모델 미상속). ② 팀원 보고는 `to="team-lead"`(`"main"` 불가). ③ resume 시 in-process 팀원 비복원(work-id 영속 설계로 보완).

### Fixed
- **`cmux-rebalancing` cmux 바이너리 미발견** (claude + codex bin 동기) — `subprocess.run(["cmux", ...])` 가 PATH 누락 서브셸 컨텍스트에서 `FileNotFoundError: 'cmux'` 로 실패(팀원 spawn 후 rebalancing 누락 사례). `CMUX_BUNDLED_CLI_PATH`/`CMUX_CLAUDE_TEAMS_CMUX_BIN` env 힌트 → PATH → 표준 설치경로 순으로 cmux 경로를 해석하도록 보강.

## [claude-2.16.2] - 2026-06-16

### Fixed
- **plugin.json `hooks` 필드 중복 로드 에러** (실사용 발견 — `/plugin` 관리화면 "1 error") — `manifest.hooks: "./hooks/hooks.json"` 가 **Claude Code 가 자동 로드하는 표준 hooks 파일**을 명시 참조해 "Duplicate hooks file detected" 로드 에러를 유발(2.15.0 SessionStart hook 도입 이후 상존). 표준 `hooks/hooks.json` 은 자동 로드되므로 manifest.hooks 는 *추가* hook 파일만 참조해야 함 → `hooks` 필드 제거. SessionStart keepalive hook 동작은 자동 로드로 그대로 유지(영향 없음).

## [claude-2.16.1] / [codex-1.14.2] - 2026-06-16

### Fixed
- **헬퍼 자동설치 캐시 선택 `sort -V` 누락** (deft-test L4 실전에서 발견) — multi-round/multi-check/agent-teams Phase 0 의 헬퍼 설치 블록이 `ls 캐시/*/bin/<helper> | tail -1` 로 캐시본을 골라, 버전 디렉토리가 누적된 환경(claude-2.0.0~2.16.0 등)에서 **사전순 마지막**(예: `2.8.0` > `2.16.0`)을 잡아 옛 헬퍼를 설치할 위험. 21곳 전부 `| sort -V | tail -1` 로 정정해 항상 최신 캐시본 선택.

### Added
- **codex 워커 업데이트 프롬프트 대응 노트** (multi-round, deft-test L4 발견) — 진짜 codex 워커 첫 기동 시 "Update available" 프롬프트로 회의 시작 전 정지하는 현상(claudex 는 자체 최신이라 무관). spawn·readiness 후 `3`(skip until next version) 전송 또는 사전 `codex update` 권장을 SKILL 에 명시.

## [codex-1.14.1] - 2026-06-16

### Fixed
- **`deft-model` 헬퍼 codex측 미러** — `bin/deft-model`이 claude측(`plugins/deft/bin/`)에만 있고 codex측(`plugins/codex/deft/bin/`)에 없어, codex 환경에서 모델 중앙관리(`DEFT_CLAUDE_MODEL` override)가 적용되지 않던 갭 (deft-test L1 동기화 검증에서 발견). codex측 `deft-model` 추가로 양측 동기화. 당장은 CLI fallback(`$(deft-model claude 2>/dev/null||echo opus)`)으로 opus 동작했으나, Fable 복구 시 codex측도 한 줄 수정으로 자동 복귀하도록 보장.

## [claude-2.16.0] / [codex-1.14.0] - 2026-06-15

### Changed
- **모델 ID 단일 관리(`bin/deft-model`) 도입** — multi-check / multi-round / agent-teams 에 흩어진 `claude-fable-5` 16곳을 `deft-model` 헬퍼 참조(실행 CLI)와 `opus` 리터럴(Agent Teams enum 인자)로 일원화. 모델 차단·버전업 시 `deft-model` 한 곳(또는 `DEFT_CLAUDE_MODEL` 환경변수)만 고치면 전 스킬에 반영 — 다중 파일 수정 누락 위험 제거. 헬퍼 미설치 시 `opus` fallback 내장(`$(deft-model claude 2>/dev/null||echo opus)`). 세 스킬 Phase 0 에 `deft-model` 자동 설치 블록 추가.
- **Claude Fable 5 사용 불가 대응 → 기본 모델 opus 운용** — `claude --model claude-fable-5` 가 실호출에서 "It may not exist or you may not have access" 로 확인됨(2026-06, opus 는 정상). 전 스킬의 Claude 워커·리뷰어·팀원 모델을 opus 로 전환. Fable 복구 시 `deft-model` 의 `CLAUDE_DEFAULT` 한 줄로 자동 복귀.

### Added
- **세션 바이너리 keepalive hard-fail preflight 게이트** — `claude-bin-keepalive` 가 복원·대체복원 모두 불가한 경우 `exit 3` + `KEEPALIVE_HARDFAIL` 마커 출력. multi-check / agent-teams SKILL.md Phase 0 가 이를 받아 `STOP_TEAM_SPAWN` 시 팀 spawn(TeamCreate/Agent)을 진입하지 않고 사용자에게 세션 재시작(`cmux claude-teams`/`/resume`)을 안내·중단한다. 이미 바이너리가 삭제된 구버전 세션이 raw `env: ...: No such file or directory` 를 노출하던 문제(실사용 보고) 방어.

## [claude-2.15.0] - 2026-06-12

### Added
- **SessionStart keepalive hook** — 플러그인이 hook(`hooks/hooks.json`)을 포함: 세션 시작마다 `claude-bin-keepalive` 자동 실행 (1초 미만·상주물 없음). "스킬을 돌려야 보존된다"는 조건을 제거해 어떤 세션이든 teammate spawn 경로가 항상 유효 — launchd 등록 없이 도달 가능한 최대 근본화 (잔여 갭은 대체 복원 폴백이 커버). 검증 중 2.1.173 실복원 실증. README 고지 갱신.

## [claude-2.14.0] - 2026-06-12

### Added
- **README "Quick Start — 첫 실행 검증" 섹션** (multi-round 3인 회의 합의 → agent-teams 3 페르소나 팀 구현): prerequisites / 설치·확인 / 첫 실행 `/set-statusline` / 성공 기준 / 실패 시 안내 + 버전·CHANGELOG 링크(숫자 무기재) + 버전 의존 동작 도입 버전 병기 (조건 B). 기존 "## 설치" 섹션 흡수·삭제 (정보 손실 0). Day-2 Runbook 은 절차 안정화 후 후속 보류.

## [codex-1.13.0] - 2026-06-12

### Added
- README (Codex) 간이 Quick Start + **CHANGELOG 단일 소스 링크 2곳** (`../../deft/CHANGELOG.md` — 회의 합의 조건 A: Codex 포팅본 변경이력 단절 해소).

## [claude-2.13.2] - 2026-06-12

### Fixed
- **세션 간 팀 충돌 방지 (실사고 — 크로스 세션 인시던트)**: `~/.claude/teams/` 는 전역 공유 네임스페이스인데 multi-check 가 고정 팀명("multi-check")을 사용 → 두 세션 동시 실행 시 워커 메시지 교차 + 타 세션이 동명 팀을 잔재로 오인해 shutdown·디렉토리 삭제하는 사고 발생. 조치:
  - multi-check 팀명을 실행별 유니크(`multi-check-<HHMMSS>`)로.
  - 정리(shutdown/TeamDelete) 전 **소유 확인 필수** 가드 — `-N` 접미 워커는 "타 리드 spawn" 신호, `--parent-session-id` 로 소속 확인. agent-teams 제약 표에도 "한 작업 한 세션 + 이름 동일 ≠ 소유" 명시.
- 정정: claude-2.13.1 의 "reviewer 보고 누락 케이스"는 오진 — 실원인은 위 크로스 세션 shutdown 이 보고 전에 도착한 것. 보고 규약(SendMessage 의무·보고 후 자체 종료 허용) 자체는 유익하므로 유지.

## [codex-1.12.2] - 2026-06-12

### Fixed
- (버전 동기화 — Codex 측 스킬 변경 없음. multi-check Codex 포팅본은 teammate 팀 미사용이라 본 충돌 비해당)

## [claude-2.13.1] - 2026-06-12

### Fixed
- **keepalive 검출 갭 2건** (teammate spawn 오류 재현으로 발견):
  - launcher 경유 세션은 ps comm 이 순수 버전명(예: "2.1.170")으로 보여 실행 중 버전 검출 누락 → 버전 패턴 매칭 추가.
  - 보존본 없이 이미 삭제된 버전은 macOS 특성상 원본 복구 불가 → **최신 가용 버전을 그 경로 이름으로 hardlink 하는 대체 복원** 폴백 (실측: 2.1.170 세션 + 2.1.175 대체로 reviewer spawn·보고 정상).
- **rebalancing 호출 규칙** — "첫 분할 직후 1회"가 재spawn 시나리오를 누락 (실측: 재spawn pane 비율 미적용) → "spawn/재spawn 으로 pane 구성이 바뀔 때마다 직후 1회"로 재정의 (multi-check·multi-round 양쪽).
- **실패 pane 정리 규칙** — spawn 직후 사망한 reviewer/워커의 pane 이 잔존 (실측) → 프로세스 0 확인 후 close-surface → 재spawn → rebalancing 절차를 Error Handling 에 명시.
- multi-check reviewer 페르소나 보고 누락 케이스 — 결과를 일반 출력으로만 내고 SendMessage 없이 끝나는 사례 (재spawn prompt 에 보고 의무 강화. 페르소나 영구 수정은 검증 후 후속).

## [codex-1.12.1] - 2026-06-12

### Fixed
- multi-round·multi-check (Codex) — rebalancing 재spawn 규칙 + 실패 pane 정리 규칙 동일 반영.

## [claude-2.13.0] - 2026-06-12

### Changed
- **multi-round 기본 참가자 수 = 워커 3명 (사용자 정책)** — 주제에서 보완적 페르소나 3개를 도출해 1명씩 배정 (명확하면 자동+1줄 보고, 애매하면 후보 조합 제시 후 사용자 질문 — 자동 추측 금지). 워커 이름 `worker<N>-<페르소나slug>`, 엔진은 mix 번갈아 배정. **1명 또는 4명+ 는 사용자가 명시할 때만**. GUIDE 흐름·체크박스 동기화.

## [codex-1.12.0] - 2026-06-12

### Changed
- multi-round (Codex) — Claude 측과 동일: 기본 워커 3명(페르소나별) + 사용자 명시 시만 1명/4명+.

## [claude-2.12.0] - 2026-06-12

### Changed
- **pane 수명 정책 변경 (사용자 정책)** — pane 분할로 진행한 작업은 **완료 후 pane 을 닫는다**: multi-round 워커 pane 은 회의 종료(Phase 5) 시, 기록은 board.jsonl·transcript.md 보존. 닫은 뒤 rebalancing 1회로 레이아웃 복원. (구 "관찰 보존 — 사용자 컨펌 후 닫기" 대체)

### Fixed
- 존재하지 않는 `cmux focus-surface` 명령 → `cmux focus-pane --pane <caller pane>` 정정 (실측 — focus 복원 절차).

## [codex-1.11.0] - 2026-06-12

### Changed
- multi-check·multi-round (Codex) — Claude 측과 동일: 완료 후 pane 자동 close (reviewer 출력은 tee 파일 보존) + focus-pane 정정. cmux=pane / 외부=백그라운드 분기 정책 Claude 와 동일함을 확인.

## [claude-2.11.1] - 2026-06-12

### Fixed
- multi-round — 워커 2+명 순차 down 분할 시 row 높이 불균등(1/2·1/4·1/4) 실측 → 전 분할 완료 후 rebalancing 1회 추가 + Lead focus 복원 절차.

## [codex-1.10.1] - 2026-06-12

### Fixed
- multi-check (Codex) pane 경로 — claudex 워커 실전 실행에서 보고된 3건 반영: 전 분할 후 rebalancing(row 균등) + Lead focus 복원, runner script 권장(quoting 안전). multi-round (Codex) 도 동일 row 균등 절차.

## [codex-1.10.0] - 2026-06-12

### Changed
- **multi-check (Codex) — cmux 환경에서 reviewer pane 시각화 기본화**: 기존 sub-agent + headless CLI 방식은 reviewer 가 화면 없이 백그라운드로만 실행돼 "multi-agent spawn 은 pane 시각화" 원칙과 어긋남 (실사용 관찰). cmux 환경이면 reviewer 마다 pane 분할 + readiness 가드 + 출력 tee 수집(.done 마커 폴링)으로 실행 — 시각화와 결과 수집 양립. sub-agent 병렬은 cmux 외부 전략으로 재배치. pane 분할 절차 없이 rebalancing 만 있던 모순 해소.

## [claude-2.11.0] - 2026-06-12

### Added
- **`bin/claude-bin-keepalive` — 세션 바이너리 보존/복원 (teammate spawn 실패 예방)**: 오래된 세션에서 Claude Code 자동 업데이트가 세션 버전 바이너리(`~/.local/share/claude/versions/<ver>`)를 삭제하면 multi-check·agent-teams 의 팀 spawn 이 `env: ...: No such file or directory` 로 실패하는 문제 (실사용 보고). 스킬 실행 시 hardlink 보존(추가 디스크 0, inode 점유는 실행 중 버전 + 최신 2개 유지) + 삭제 시 복원 + 이미 복원 불가한 세션 검출·경고(재시작 안내). 두 스킬 preflight 에 표준 호출 1줄 + README 고지. Claude 전용 (Codex 측은 teammate spawn 미사용).

## [claude-2.10.0] - 2026-06-12

### Changed
- **claude 워커도 승인 0회화** — spawn 에 `--dangerously-skip-permissions` 추가 (claudex 의 bypass 에 대응, 인스턴스 한정). `--allowedTools` 는 skip 미적용 환경 폴백 겸 유지.
- **README 권한 모드 고지** — 워커 spawn 권한 모드(claudex bypass / claude skip-permissions)와 트레이드오프·해제 방법을 사용자 노출 문서 마지막에 명시.

## [codex-1.9.0] - 2026-06-12

### Changed
- multi-round (Codex) — Claude 측과 동일: claude 워커 skip-permissions + README 권한 모드 고지.

## [claude-2.9.0] - 2026-06-12

### Changed
- **claudex/codex 워커 MCP 도구 승인 0회화** — `--disable tool_call_mcp_elicitation` 은 elicitation 채널만 차단하고 TUI 승인 다이얼로그는 잔존 (실측). MCP 도구 영구 신뢰 설정 부재 확인 (approval_policy·guardian_approval·서버 하위 trust 류 후보 키 전수 무효) → spawn 에 `--dangerously-bypass-approvals-and-sandbox` 기본 포함 (인스턴스 한정·회의 워커 용도 한정 — 트레이드오프 주석 명시). 승인 최소화 대안("Allow for this session" 도구당 1회)도 안내.

### Notes
- v2.8 풀사이클 재검증 완료 — inject 발췌·reply_to 체인·**레이스 자기 치유**(노크 디바운스로 누락된 추가 요청이 aged 재노크 + 미응답 큐로 회복)·워치독·transcript 자동 생성 전 항목 실전 동작 확인.

## [codex-1.8.0] - 2026-06-12

### Changed
- multi-round (Codex) — Claude 측과 동일: 워커 spawn 승인 우회 + GUIDE 트러블슈팅.

## [claude-2.8.0] - 2026-06-12

### Added
- **버스 시퀀스 프로토콜 (P1~P4)** — "워커가 요청 A 처리 중 추가 요청 B 가 오면 B 가 묻히는" 레이스 실측(사용자 발견)의 구조적 해결:
  - `reply_to` 필드 — 응답↔요청 기계적 연결 (CLI `--reply-to` + MCP `post_message` 인자)
  - **미응답 요청 큐** — check 가 "본인 대상 request 중 reply_to 응답 없는 것"을 읽음 커서와 독립으로 매번 재계산해 `⚠ 미응답 요청` 섹션 반복 노출 (자기 치유 — 읽고 빠뜨린 요청도 응답까지 계속 보임)
  - 처리 규칙 재정의 ("게시·응답 시점 무관, id 순 전부 처리") — check 출력·MCP 도구 설명·페르소나 4종 반영
  - 과거 데이터 관대 폴백 (reply_to 없는 구식 응답 호환)
- **`transcript` 서브커맨드 (C1~C7)** — board.jsonl → 가독 마크다운 회의록. multi-round 3인 회의 합의 사양 그대로:
  - Timeline (`### #id · type · ts`, `from → to`, `← #N 응답`), 신호 12종 강조, DONE 비최종행 경고
  - 세션 디렉토리 입력 시 `transcript.md` 자동 저장 기본 (`-o -` 로 stdout), MVP 옵션 3개 (positional·`-o`·`--full`)
  - 주입(페르소나) 메시지 기본 발췌 (`inject:true` 마커 — post `--inject` 신설 + frontmatter 휴리스틱 폴백), `--full` 전문 (동적 fence)
  - SKILL Phase 5 표준 호출 1줄 + 역할 분리 명시 (audit=board.jsonl / 가독=transcript.md / 종합=summary.md)
- parseArgs: `-o` short 옵션 + FLAG_OPTS (기존 `--json` 의 뒤 토큰 흡수 버그성 동작 교정)

### Notes
- agent-teams 첫 실전 운영으로 구현 (backendDev 구현 + qa 36케이스 REVIEW_PASS + Lead diff 검증) — multi-round 회의 합의 → work.md 설계 결정 → 팀 구현의 교차 참조 흐름 검증 완료.

## [codex-1.7.0] - 2026-06-12

### Added
- multi-round (Codex) — Claude 측과 동일: 버스 시퀀스 프로토콜 + transcript 서브커맨드 (`bin/multi-round-bus` 동기화, SKILL·페르소나 갱신).

## [claude-2.7.0] - 2026-06-12

### Added
- **`multi-round-bus watch` 서브커맨드 — 데드락 워치독**: Lead 는 노크로만 깨어나므로 워커가 막히면(권한 거부·crash) 회의가 조용히 정지하는 구조적 공백 발견 (3인 회의 실측). post 후 백그라운드로 watch 를 심으면 수신자 응답 시 RESPONDED, timeout(기본 300s) 시 자동 재노크 1회 + 읽음 커서 진단 포함 STALLED 보고 — 종료 자체가 Lead 를 깨우는 신호. SKILL Phase 4 필수 절차로 명시.

### Fixed
- **claude CLI 워커 발신 차단** — don't ask 등 제한 권한 모드에서 버스 도구가 allowlist 에 없어 post 가 자동 거부, "수신만 되고 발신 불가" 반쪽 참가자가 되는 문제 (실측 — 회의 데드락의 직접 원인). spawn 명령에 `--allowedTools mcp__bus__check_messages,mcp__bus__post_message,mcp__bus__list_participants` 표준 포함.
- GUIDE 트러블슈팅 2건 추가 (발신 차단 / 조용한 데드락).

## [codex-1.6.0] - 2026-06-12

### Added
- multi-round (Codex) — Claude 측과 동일: watch 워치독 (`bin/multi-round-bus` 동기화), claude 워커 `--allowedTools`, 트러블슈팅 2건.

## [claude-2.6.0] - 2026-06-11

### Added
- **버스 신뢰성 보강 3건** — multi-round 첫 실전 회의(버스 자체를 의제로 한 dialogue, 2라운드 CONSENSUS)에서 합의된 개선을 그대로 구현:
  - **lock pid 검증 (High)**: lock 에 owner pid 메타 기록, stale 판정 시 pid 생존 확인 — 살아있는 holder 의 lock 은 탈취하지 않음 (split-brain 방지). `writeJson` 에 fsync 추가.
  - **aged-knock 재노크 (High~Mid)**: 미확인 노크가 60초 경과하면 다음 post 때 재노크 (sent ≠ consumed 보정). knocks.json 을 `{id, ts}` 구조로 확장 (구버전 숫자 호환).
  - **stale surface 마킹 + 손상 줄 로깅 (Mid)**: 노크 실패 시 레지스트리에 `lastKnockFailedAt` 마킹 + post 결과에 stale 의심 표시. board.jsonl 손상 줄 skip 시 stderr WARN (조용한 발언 유실 방지).
- 단위 테스트 통과: aged 재노크 발화 / 신선 디바운스 skip / 죽은 holder 해제 / 살아있는 holder 10s timeout 대기 / stale 마킹 / 손상 줄 WARN.

### Changed
- SKILL 디바운스 설명에 aged 재노크·stale 마킹 반영.

## [codex-1.5.0] - 2026-06-11

### Added
- multi-round (Codex) — Claude 측과 동일한 버스 신뢰성 보강 3건 (`bin/multi-round-bus` 동기화) + SKILL 디바운스 문구 갱신.

## [claude-2.5.1] - 2026-06-11

### Fixed
- **SKILL.md frontmatter strict YAML 정합** — multi-round·agent-teams 의 `description` 값에 따옴표 없는 `예:` 콜론이 있어 strict YAML 파서(codex)에서 "mapping values are not allowed" 파싱 실패 → 작은따옴표 스칼라로 감쌈. 전 스킬 frontmatter `yaml.safe_load` 일괄 검증 통과.
- **multi-round-bus CLI: `--content` 값이 `--` 로 시작하면 stdin 대기로 빠지는 행(hang)** — 페르소나 frontmatter(`---`) 본문을 인자로 전달하는 실사용에서 발견. 값을 받는 옵션은 다음 토큰을 무조건 값으로 소비하도록 parseArgs 정정 + 회귀 테스트.

## [codex-1.4.1] - 2026-06-11

### Fixed
- multi-round (Codex) — Claude 측과 동일 2건: SKILL.md frontmatter strict YAML 정정 (codex 는 strict 파서라 스킬 로드 자체가 실패했음), multi-round-bus parseArgs 행 정정.

## [claude-2.5.0] - 2026-06-11

### Added
- **multi-round 메시지 버스 신규** (`bin/multi-round-bus`, node 단일 스크립트·의존성 0) — 브로드캐스트 보드 + 노크 아키텍처로 통신 계층 전면 재설계:
  - **한 코드 두 진입점**: 워커는 `mcp` 서브커맨드(stdio MCP 서버 — `post_message`/`check_messages`/`list_participants`), Lead 는 `post`/`check`/`register`/`history` CLI 를 Bash 직접 호출 (Lead MCP 등록 불필요).
  - **보드 = 데이터 채널**: 모든 발언이 `board.jsonl` 에 게시 (전원 공개·브로드캐스트). 줄바꿈·길이 제한 없음 — cmux send sanitize·캡처 노이즈 문제 구조적 해소.
  - **노크 = 제어 채널**: post 마다 발신자 제외 전원의 pane 에 `[bus] 메시지 확인` 한 줄 자동 주입 (Lead 포함 — 폴링 불필요). 참가자별 디바운스 (미확인 노크 존재 시 skip — 깨어나면 누적 일괄 처리).
  - **수신자 지정 + 전원 공개**: 수신자만 작업·응답, 비수신 참가자는 컨텍스트 검토 + 필요 시 자발 발언 (회의실 메타포).
  - 동시 쓰기 lock 직렬화 (`mkdir` atomic + stale 해제), 읽음 커서(`cursors.json`), 참가자 레지스트리(`participants.json`).

### Changed
- **multi-round SKILL Phase 2/3/4 전면 재편** — 통신 우선순위 매트릭스 신설:
  - AI mix·전원 claudex/codex (cmux): ① MCP 버스 ② send/capture 폴백 ③ multi-check 안내 후 중단
  - 전원 Claude: ① 팀메이트 기능 ② MCP 버스 ③ multi-check 안내 후 중단
  - cmux 외부: claudex MCP conversation (stateful) → 불가 시 multi-check 안내 후 중단
- **워커 MCP 인라인 주입** — 버스는 spawn 명령에 `-c mcp_servers.bus={...}` (claudex/codex TOML) 또는 `--strict-mcp-config --mcp-config <세션파일>` (claude) 로 주입. **사용자 환경 파일(`settings.json`/`config.toml`) 등록 절차 자체가 제거됨**.
- **실측 발견 3건 반영** (claudex 0.138 E2E 테스트 — handshake·check·post·Lead 노크 수신 전체 사이클 검증 완료):
  - `-c mcp_servers.*` 인라인은 기존 등록 서버에 **병합**(교체 아님) — 격리는 기존 서버 `enabled=false` 명시 비활성으로 (claude 측은 `--strict-mcp-config` 가 완전 격리).
  - MCP 도구 호출마다 승인 elicitation 발급 (`tool_call_mcp_elicitation` stable 기능) — 워커 spawn 에 `--disable tool_call_mcp_elicitation` 포함 (인스턴스 한정).
  - cmux surface 는 화면 렌더 시 쉘 기동(lazy-init) — 분할 직후 send 유실 방지용 readiness 마커 가드 신설 (§Phase 3-A (3.5)).
- 페르소나 (codex/claude-participant) — 버스 프로토콜 신설 (노크 수신 → check → 수신자 판단 → 작업·응답 / 검토·자발 발언). "모든 통신은 Lead 경유" 모델 폐기.
- 회의록 표준 변경 — 원본 `board.jsonl` + 종합 `summary.md` (구 round<N>-*.md 패턴 대체). agent-teams 연속성 절차의 회의 참조도 동일 갱신.
- GUIDE/README — 버스 아키텍처 반영 (통신 구조 다이어그램, 트러블슈팅 노크·버스 항목, FAQ).

### Removed
- **1-shot history 재전송 경로 금지 명문화** — 멀티라운드는 지속 대화가 본질. 해당 형태가 필요한 요구는 multi-check 가 올바른 도구이므로 안내 후 중단.

## [codex-1.4.0] - 2026-06-11

### Added
- multi-round (Codex) — Claude 측과 동일한 메시지 버스 아키텍처 포팅 (`bin/multi-round-bus` 동봉, Codex cache 경로 우선 자동 설치).

### Changed
- multi-round (Codex) SKILL/GUIDE/agents 전면 재편 — 통신 우선순위 매트릭스 (버스 → send/capture → multi-check 안내 / cmux 외부는 claudex MCP conversation).

### Removed
- **구 3-C (codex 내부 병렬 1-shot + history 누적 재전송) 제거** — 지속 대화 원칙 위반. multi-check 안내로 대체.

## [claude-2.4.4] - 2026-06-10

### Changed
- **CHANGELOG 과거 entry 일반화 정리** — 폐기된 외부 도구명·도메인·개인 환경 경로가 남아 있던 표현 20곳을 삭제 또는 일반화 ("외부 협업 도구", "외부 연결 검사", "이전 구성" 등). 변경 이력의 사실성(무엇이 언제 바뀌었는지)은 유지.

## [claude-2.4.3] - 2026-06-10

### Fixed
- **외부 참조 삭제의 동작 영향 검증 + 잔존 1건 정정** — 삭제한 참조 3종이 가리키던 내용의 skill 내 이식 여부 확인 (회의 모드 정의·응답 언어 규칙·자동 write 금지 모두 본문에 자기완결 확인). 검증 중 보안 가드 표의 "§6-3 사전 컨펌 정책 위반" 외부 정책 번호 잔존 1건 발견 → "사용자 환경 임의 변경" 으로 일반화.

## [claude-2.4.2] - 2026-06-10

### Removed
- **플러그인 전체 검토 — 개인 정보·외부 참조 잔존 일소** (제로베이스 정합):
  - multi-round GUIDE "더 깊이" 의 작성자 실명 + 개인 환경 경로 + 트래킹 파일 참조 2줄 삭제.
  - multi-round SKILL 의 외부 개인 환경 파일 참조 삭제 (자기완결 원칙).
  - 개인 정책 문서 참조 제거 (신호 프로토콜·응답 언어 줄 — 정책 내용 자체는 유지).
  - Phase 2 제목의 "사용자 정책 §6-3" → "사용자 환경 파일 — 자동 write 금지" 일반 표현으로.
- 유지 판정: agent-teams 의 "cwd 의 `AGENTS.md`/`CLAUDE.md` 컨벤션 준수" 표현은 사용자 본인 프로젝트 컨벤션 파일의 일반 참조이므로 정당 — 유지.

## [codex-1.3.2] - 2026-06-10

### Removed
- multi-round (Codex) — Claude 측과 동일한 개인 정보·외부 참조 잔존 일소 (GUIDE "더 깊이" 2줄, agents 페르소나의 개인 정책 참조, Phase 2 제목 정책 번호).

## [claude-2.4.1] - 2026-06-10

### Changed
- **agent-teams 강한 트리거 조합형으로 축소** — "작업" 단독 → **"코딩 작업"** 조합. "작업"은 일상어라 오발동 위험 ("파일 정리 작업" 같은 단순 요청에 팀 spawn 방지). multi-round 양쪽 라우팅 표의 대응 표기도 동일 갱신.
- **README (Claude/Codex) 에 "강한 트리거" + "사용 예제 문구" 섹션 신규** — skill 별 발동 문구·예시·work-id 연계 흐름을 plugin 진입점에서 바로 확인 가능.

## [codex-1.3.1] - 2026-06-10

### Changed
- multi-round (Codex) 라우팅 표 "작업" → "코딩 작업" 조합형 갱신 + README 트리거/사용 예제 섹션 신규.

## [claude-2.4.0] - 2026-06-10

### Added
- **강한 트리거 라우팅 규칙** — 호출 의도가 애매하던 multi-round ↔ agent-teams 경계를 단어 기반으로 명확화:
  - **"회의" / "미팅"** 단어 포함 → `multi-round` 발동 (예: "회의 열어줘", "이 주제로 미팅")
  - **"작업"** 단어 포함 → `agent-teams` 발동 (예: "IT-14610 작업 시작", "이거 작업해줘")
  - 두 단어가 함께 나오면 먼저 요구되는 쪽 발동 + 이어지는 단계는 같은 work-id 로 연계
  - frontmatter description + SKILL 본문 라우팅 표에 반영 (multi-round / agent-teams 양쪽)

### Fixed
- **multi-round Trigger 회피 매트릭스의 "회의" 모순 정리** — 과거 구성의 흔적으로 "회의"가 회피 어휘에 잔존 → 강한 트리거로 반전. 회피 어휘는 "한번 봐줘"/"검토해줘"(1발 의도) 류만 유지.

### Notes
- 호출 경로(트리거) 추가 → MINOR bump (claude-2.3.0 → claude-2.4.0).

## [codex-1.3.0] - 2026-06-10

### Added
- **multi-round (Codex) 강한 트리거** — "회의"/"미팅" 단어 포함 시 발동. "작업" 단어는 Codex 자체 task 실행으로 라우팅.

### Fixed
- Trigger 회피 매트릭스의 "회의" 모순 정리 (Claude 측과 동일).

## [claude-2.3.0] - 2026-06-10

### Added
- **work-id 규약을 deft 플러그인 공통으로 승격** — config 위치를 `agent-teams/config.json` → **`~/.claude/plugin-data/deft/config.json`** (공통 루트) 로 이동. agent-teams 와 multi-round 가 같은 규약·같은 config 를 공유 — 어느 skill 이 먼저 실행되든 최초 1회만 결정. 구버전(skill 전용 위치) config 는 공통 위치로 자동 마이그레이션 (agent-teams SKILL §3-3 ⑤).
- **multi-round work-id 연계 default** — 회의는 기본적으로 작업(work-id)에 연계. 사용자 입력에서 work-id 감지(티켓 번호 등), 감지 안 되면 1회 질문. **사용자가 "독립 토론" 명시 시에만** work-id 없이 진행. 세션 디렉토리 구조 분리: `sessions/<work-id>/<tag>/` (연계 기본) / `sessions/standalone/<tag>/` (독립).
- **agent-teams ↔ multi-round 양방향 교차 참조** (같은 work-id):
  - multi-round Phase 1-0: 회의 시작 시 `agent-teams/<work-id>/work.md` 존재하면 Read → 요건분석·영향도·설계결정을 라운드 1 prompt 에 컨텍스트로 inject.
  - agent-teams 연속성 절차 3단계 신규 + §3-5: 팀 시작/재개 시 `multi-round/sessions/<work-id>/` 회의록의 합의 결과를 work.md `## 설계 결정` 에 반영.
  - 작업 중 토론 호출 패턴: 팀 진행 중 결정이 갈리면 같은 work-id 로 multi-round 호출 → 합의 → work.md 기록 → 팀 재개.
- **GUIDE 갱신** — multi-round Before You Start 에 work-id 연계 항목, 작업 디렉토리 구조 갱신, FAQ 저장 경로 갱신. agent-teams GUIDE A-1 공통 config 반영.

### Notes
- 신규 동작(연계 default + 교차 참조) 추가 → MINOR bump (claude-2.2.2 → claude-2.3.0).
- 사용자 환경의 기존 독립 토론 transcript (`sessions/20260605-1735-design/`) 는 `sessions/standalone/` 하위로 이동됨.

## [codex-1.2.0] - 2026-06-10

### Added
- **multi-round (Codex) work-id 연계 default** — Claude 측과 동일 설계. config 읽기 순서: ① `~/.codex/plugin-data/deft/config.json` → ② Claude 측 `~/.claude/plugin-data/deft/config.json` (이미 결정했으면 복사 후 재사용) → ③ 최초 1회 메뉴. 세션 디렉토리 `sessions/<work-id>/<tag>/` (기본) / `sessions/standalone/<tag>/` (독립 명시 시).
- **Claude 측 agent-teams 작업노트 교차 참조** — work-id 확정 시 `~/.claude/plugin-data/deft/agent-teams/<work-id>/work.md` 존재하면 Read 후 라운드 1 컨텍스트로 inject.
- **GUIDE 갱신** — Before You Start work-id 항목 + 작업 디렉토리 구조.

### Notes
- 신규 동작 추가 → MINOR bump (codex-1.1.5 → codex-1.2.0).

## [claude-2.2.2] - 2026-06-10

### Fixed
- **multi-check (Claude) `claude-opus-4-6` 잔존 6군데 정정** — SKILL.md description 표기 ×2 + `agents/claude-reviewer.md` 의 `--model claude-opus-4-6` ×4 → `claude-fable-5`. (이전 2.2.1 에서 Codex 측 SKILL L170 한 곳만 고치고 누락된 부분.)

### Changed
- **multi-round (Claude) 워커 모델 버전 명시** — Phase 3-A MCP 호출 `model: "<model>"` placeholder → `model: "gpt-5.5"` 표준 명시. Phase 3-B TUI 기동 명령에 `-m gpt-5.5` (claudex/codex) / `--model claude-fable-5` (claude-only) 분기 추가.
- **multi-round (Claude) 결과 양식 예시** — "Claude(Opus 4.8)" → "Claude(Fable 5)".

## [codex-1.1.5] - 2026-06-10

### Changed
- **multi-round (Codex) 의 codex CLI 배포 버전 표기 제거** — "codex 0.134.0" → "codex". 설치 CLI 버전은 skill 본문에 명시할 필요 없음 (버전 갱신마다 stale 위험).

## [codex-1.1.4] - 2026-06-10

### Fixed
- **multi-check (Codex) `agents/claude-reviewer.md` 의 `claude-opus-4-6` ×2 정정** → `claude-fable-5`.
- **multi-round (Codex) Phase 3-C `claude` worker 호출 잠재 버그 정정** — `claude` CLI 에는 `exec` 서브명령이 없어 `"$WORKER_B" exec -` 가 실패하던 문제. CLI 별 명령 배열 분기로 교체: claudex/codex 는 `exec -m gpt-5.5 -`, claude 는 `claude -p - --model claude-fable-5`.

### Changed
- **multi-round (Codex) 워커 모델 버전 명시** — Phase 3-A `model: "gpt-5.5"` 표준 명시 + Phase 3-B TUI 기동 `-m gpt-5.5` / `--model claude-fable-5` 분기 + 결과 양식 예시 "Claude(Fable 5)".

## [claude-2.2.1] - 2026-06-10

### Added
- **agent-teams 팀원 모델 명시 복원** — teams-porter 가 프로젝트-중립 일반화 과정에서 제거한 모델 표기를 복구. 모든 팀원은 **Claude Fable 5 (`claude-fable-5`)** 로 통일 — 동질 시각, 컨벤션 강제 일관.
  - `agents/*.md` 8종(architect/backendDev/designer/frontendDev/lead/pm/qa/reviewer) 각 페르소나 본문 시작부에 모델 메타 라인 삽입 (`> **모델**: Claude Fable 5 (\`claude-fable-5\`) — Agent tool 호출 시 alias \`fable\``).
  - `SKILL.md` §2 도입부에 팀원 모델 한 줄 요약 + §4-3 spawn 템플릿에 **Agent 도구 호출 인자** 섹션 신규: `model: "fable"` alias 사용 명시 (Agent tool enum 제약: `sonnet`/`opus`/`haiku`/`fable` — 구체 ID 직접 지정 불가).

### Notes
- 본 버전은 모델 명시 복원. 동작 호환성 유지 (PATCH bump).

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
- 외부 협업 도구·외부 연결 검사 관련 표현 전수 제거 — multi-round 자체가 외부 호출을 만들지 않으므로 불필요한 잡음
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
- **multi-round (Claude) Phase 0 의 외부 도메인 차단 확인 블록** — multi-round 자체가 외부 호출을 만들지 않으므로 책임 영역 외. 잡음 제거.
- **multi-round (Claude) 보안 가드 표 정리** — `cmux search.db 권한 600` / 이전 구성 보존 관련 / "외부 연결 검사" 행 삭제. 가드 8개 → 6개 (참가자 CLI / MCP 컨텍스트 격리 / cmux send sanitize / settings.json write 금지 / 환경 진단 / `cmux identify` 사용).
- **multi-round (Claude) `5-C cmux search.db 잔존 처리` 섹션** — `chmod 600 search.db*` 권장 통째 삭제. cmux 자체 부산물이므로 skill 책임 영역 외.
- **multi-round (Claude) GUIDE FAQ 2건 (이전 구성 관계 / 외부 송신) 삭제** — 잡음 제거 + Q 번호 재정렬.
- **multi-round (Claude) agents/*-participant.md 의 "본업 코드 외부 송신 금지 / search.db 잔존 가능성" 라인 삭제**.
- **README (Claude) 불필요한 비교 표현 제거** — multi-round 행 + 3-도구 비교표 의존성 칸.

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
- **multi-round 작업 디렉토리 표준화** — skill 실행 시 사용하는 세션·메타·hooks 경로를 `/tmp/multi-round-session/` → **`~/.agents/skills/multi-round/`** 하위로 통일. 다른 사용자 skill들과 일관된 구조.
  - 새 구조: `sessions/<YYYYMMDD-HHMM-tag>/` (회의별 transcript) + `state/` (영구 메타) + `hooks/` (동작 훅)
  - SKILL.md: 작업 디렉토리 표준 섹션 신규 추가 + Phase 4-A 예시 경로를 `$SESSION_DIR` 변수로 변경
  - GUIDE.md: Before You Start에 작업 디렉토리 안내 추가 + Examples 9-5 메타 transcript 경로 갱신
- **상충 정정 (SKILL.md)** — 이전 2.1.1에서 Phase 0 외부 연결 체크 제거했으나 보안 가드 #1 + Error Handling에 잔존 표기가 있었던 부분 정정:
  - 보안 가드 #1: "Phase 0 preflight 통과 (외부 연결 0)" → "Phase 0 참가자 CLI 1개 이상 설치 확인"
  - Error Handling: "외부 연결 발견 (Phase 0) → abort" 제거 + 참가자 CLI 매트릭스 재정렬

### Notes
- 본 버전은 경로 표준화·문서 일관성 정정. 동작 호환성 유지 (PATCH).
- `/tmp/multi-round-session/` 임시 데이터는 사용자 환경에서 `~/.agents/skills/multi-round/sessions/<timestamp>/`로 이동 (개인 메타).

## [claude-2.1.1] - 2026-06-08

### Changed
- **multi-round Phase 0 Preflight 단순화** — 외부 연결 검사 제거. multi-round skill 자체는 외부 호출을 만들지 않으므로 본 검사는 skill 책임 영역 밖. 무관한 시스템 트래픽 false positive 제거.
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
- **multi-round** 신규 스킬 추가 — 여러 AI가 N라운드에 걸쳐 양방향으로 의견을 주고받는 멀티턴 토론 도구.
  - `claudex mcp-server` (내장 MCP 도구 `codex` / `codex-reply`) + cmux pane 제어 조합으로 동작.
  - 회의 모드: `consult` / `dialogue` (기본) / `collaborate` / `debate` 4종 정의.
  - 신호 프로토콜: `ACK`/`STATUS`/`BLOCKED`/`DONE` + 모드별 확장 (`CONSENSUS`/`AGREED`/`DISSENT`/`CONCEDE`/`REVIEW_PASS`/`REVIEW_FAIL`).
  - 초기 보안 가드 8종 구성 (preflight 검사, `-c mcp_servers={}` 강제, cmux send 줄바꿈 sanitize, settings.json 자동 write 금지, claudex/codex graceful fallback, `cmux identify` 사용 등).
  - 트리거: "멀티 라운드", "라운드 회의", "왔다갔다 토론", "주거니 받거니", "AI끼리 토론시켜", "수렴할 때까지 주고받아" 등 18종 — `multi-check` (1발 비교) / Agent Teams (파일 작업) 와 명확히 분리.
  - `agents/codex-participant.md`, `agents/claude-participant.md` 두 참가자 페르소나 동봉.

### Changed
- CHANGELOG 헤더를 "session-relocate 플러그인" → "**deft 플러그인**"으로 정정 (stale 헤더 보정).
- 버전 표기 정책 정렬: 본 changelog의 버전을 `claude-X.Y.Z` 접두 표기로 통일 (이전 `1.0.X` 표기는 그대로 유지하되 신규 엔트리부터 적용).

### Notes
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
