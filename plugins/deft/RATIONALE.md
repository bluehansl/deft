# deft — 설계 근거·실측 사고 기록 (RATIONALE)

> 이 문서는 deft 스킬(multi-round / agent-teams / multi-check)의 가드·규약이 **왜 존재하는지**의 근거를 모은다.
> SKILL.md 본문은 **간결한 지침만** 두고, "왜 이렇게 해야 하는가"(실측 사고·재현 조건·소스 확정)는 여기에 `R-N` 으로 보존한다.
> SKILL.md 에서 `(근거: R-N)` 으로 참조한다. 가드를 미래에 되돌리려는 사람이 먼저 이 기록을 읽도록 한다.
>
> 버전별 변경 요약은 `CHANGELOG.md`, 진행 중·보류 항목은 `PENDING.md` 참조.

---

## NTP / 수신 (multi-round)

### R-1. 자동주입(`<teammate-message>`) ≠ 신뢰 경로 — Lead 직접 회수가 1차
- **사고**: 워커 메시지는 `team-lead.json` 에 정상 적재되나(고빈도 폴링으로 `read:false` 포착), Claude Code(Lead) 런타임 watcher 가 읽어 mailbox 큐에 넣고 inbox 를 즉시 비운다. 그러나 Lead 의 현재 turn 이 *이미 답변 출력 중*(mailbox delivery phase = NextTurn)이면 그 큐가 이번 turn 에 주입 안 되고 **다음 turn 경계에서 누락** → inbox 는 이미 비워져 복원 불가 → 유실.
- **실측**: 회의 4워커(claude2+claudex2) 입장 표명이 inbox 엔 적재됐으나 Lead transcript 자동주입 **0건**(2026-06-25).
- **소스 확정**: claudex watcher 는 자기 inbox 만 건드림(무죄). drain 주체는 Lead = Claude Code 런타임이고 클로즈드라 수정 불가. → **스킬 레벨 우회**(Lead 직접 회수)가 유일 해법.
- **지침**: SKILL.md §Lead 직접 회수.

### R-2. 회수 루프 선점 순서 — "회수 루프 먼저, SendMessage 나중"
- **사고**: 회수를 SendMessage **직후** 시작하면 워커가 그 사이(수 초) 보낸 응답을 watcher(750ms 주기)가 먼저 비워 놓친다.
- **실측**: 회수 루프를 늦게 켜니 입장 본문 대신 idle_notification 만 잡힘 → 백그라운드로 먼저 켜니 본문 회수 성공(2026-06-25).
- **지침**: 회수 루프를 `run_in_background`(`&`)로 **먼저** 띄운 뒤 SendMessage. 기대 발신자 전원 모일 때까지 break 금지(한 명 잡고 끊으면 그 뒤 도착분 유실). idle_notification·shutdown 등 제어 메시지는 회수 대상 제외.

### R-3. send_message 필드명은 AI 마다 다르다 (소스 확정)
- Lead=Claude `SendMessage` 수신자 키 = **`to`** / claudex 워커 `send_message`(codex 도구) 수신자 키 = **`target`**, 본문 키 = `message`.
- claudex `send_message` 는 `{target, message}` 두 키만 받는다(`#[serde(deny_unknown_fields)]` — `to` 로 부르면 역직렬화 실패). 근거: claudex `SendMessageArgs{target,message}` (`core/src/tools/handlers/multi_agents_v2/message_tool.rs`).

---

## 종료 (multi-round / agent-teams / multi-check)

### R-4. 평문 종료 금지 — 구조화 `shutdown_request` 필수
- **사고**: Lead 가 "정리하고 종료해 주세요" 같은 **평문 문자열**로 종료 요청 → 워커는 일반 메시지로 받아 **보고만 하고 프로세스 안 내려감**.
- **실측**: claudex 는 종료됐으나 claude 워커는 잔존, 워커가 "shutdown 은 shutdown_response(approve:true)를 받아야 내려간다"며 올바르게 거부(2026-06-25).
- **지침**: 종료는 반드시 `SendMessage(to:"<name>", message:{type:"shutdown_request", reason:"…"})` 구조화 객체. claude 워커(in-process)는 kill 도 금지라 구조화 shutdown_request 가 **유일 종료 수단**. 안 죽으면 kill 말고 구조화 재발송.

### R-5. claude(Agent tool) 워커에 SIGTERM/kill/pkill 절대 금지
- in-process(별도 PID 없음 — `pgrep` 미포착)라 kill 이 안 통하고, 어설픈 kill 은 메인 세션 레지스트리에 **좀비 핸들**(`N teammate started` UI 잔재)을 남긴다. 좀비는 SendMessage·Esc·TaskStop·kill 다 안 먹어 **Lead 세션 재시작만이 유일 해법**.
- **실측**: 실험 워커를 SIGTERM 으로 정리하다 10+ 좀비 발생. 정상 흐름(`shutdown_request`→approved 대기)만 쓰면 좀비 0.

---

## 대기 / 데드락 (multi-round)

### R-6. foreground blocking 대기 절대 금지 (버스·NTP 무관)
- **사고**: Lead 가 응답 대기를 `for i in $(seq ...); do sleep 30; … done` 같은 foreground 루프로 구현 → 그 Bash 가 끝날 때까지(최대 8분) 모델 턴 전체 블록 → 워커 응답·노크가 도착해도 다음 행동 불가 → 무한 대기.
- **실측**: 사용자가 ESC 로 Bash 를 죽여야 큐의 노크를 그제서야 처리(`Flummoxing…`/`Forging…` 멈춤, 2026-06-25).
- **지침**: 응답 확인은 짧은 단발(check/read 1회) 후 **턴 종료** → 다음 노크/메시지가 다음 턴을 깨운다. 무응답 감시는 반드시 `run_in_background`/`&`. 합의+워커 전원 대기면 즉시 종료(Phase 5).

---

## 전송계층 / board (multi-round)

### R-7. 회의 모드 = MCP 버스 강제 (board 브로드캐스트 보장)
- **사고**: 출력 개선 작업 중 회의 spawn 이 NTP 직접회수 경로(board 없음)로 전환 → board 가 안 생겨 워커 상호 노출 사라지고 **star 로 퇴화**("토론" 요청이 1:1 분담 보고가 됨).
- **실측**: 정상 회의(13:35)는 board.jsonl + `to:"all"` + 워커 간 #번호 인용으로 토론, 회귀 회의(14:20)는 board 없이 r*-collected.jsonl 만(2026-06-25).
- **핵심**: NTP fan-out(워커가 전원 복제 전송)은 공유 타임라인을 못 만들어(파편화) 진짜 broadcast 가 아니다. **단일 허브(버스) board** 가 공유 진실 소스. 버스에 이미 "board 공유 + `ntpPush`(cmux 노크 대신 팀 inbox 자동주입 전파)"가 구현돼 있어(13:35 검증) board(공유)+속도 둘 다 성립.
- **지침**: 회의 모드는 claudex 유무 무관 MCP 버스 강제, spawn 후 `board.jsonl` 생성 확인(없으면 BLOCKED). NTP 직접회수는 작업 모드 전용.

---

## cmux 환경 (multi-round)

### R-8. 🔴 모든 cmux 호출에 `--workspace` 동반 (다른 워크스페이스 동작 보장)
- **사고**: Phase 3-A 의 `cmux send`/`send-key`/`focus-pane`/`new-split`/`close-surface` 가 `--workspace` 동반 없이 `--surface` 단독 호출 → caller stale 환경(다른 워크스페이스에서 스킬 실행·resume 후·비대화형)에서 surface ref 해석 실패 → 명령이 **caller(Lead) pane 으로 폴백 입력**(워커 안 뜸, touch/CLI 부팅이 Lead 에 흘러들어감).
- **잠복**: 2.5.0(버스 도입)부터 있었으나 모든 테스트가 Lead 와 같은 워크스페이스에서 돌아 우연히 안 터짐. 처음으로 다른 워크스페이스에서 날것 실행되며 드러남(2026-06-25).
- **검증 맹점**: 개발자가 직접 절차를 밟는 검증은 아는 함정(`--workspace`)을 무의식적으로 보정해 코드 버그를 못 잡는다 → **별도 세션이 스킬을 날것으로 다른 워크스페이스에서 실행**해야 진짜 검증.
- **불일치 이력**: NTP 헬퍼(`deft-claudex-native-spawn`)는 이미 이 패턴으로 고쳐져 있었으나(CHANGELOG claude-2.27 대) 버스 경로 send 엔 전파 누락.
- **영향**: multi-round 한정. agent-teams·multi-check 는 Agent tool 이 pane 생성+기동을 원자적으로 처리해 `cmux send` 단계가 없어 구조적 안전.
- **지침**: `LEAD_WORKSPACE`/`LEAD_PANE` 를 `cmux identify` 런타임 발견(하드코딩 금지), `WS=(--workspace "$LEAD_WORKSPACE")` 를 모든 cmux 호출에 동반.

### R-9. SESSION_DIR 일관성 — 공유 고정 임시파일 금지
- **사고**: Claude Code Bash 는 호출 간 셸 변수가 유지 안 돼, 모델이 SESSION_DIR 공유를 위해 공유 고정 임시파일(`/tmp/.mr_session_dir`)을 즉흥 생성 → 이전 세션 값 잔재로 오염(워커가 엉뚱한 디렉토리를 봄).
- **지침**: 세션 고유 파일에 저장·재사용 또는 리터럴 절대경로 직접 박기. `mapfile`/`readarray` 는 bash 전용(zsh 깨짐) — `while read`/`$(… | tr)` 로 대체. SESSION_TAG 는 초 단위(`%H%M%S`).

### R-10. cmux 잡다 (실측)
- `cmux new-split` 플래그는 `--surface`(또는 `--panel`) — `--pane` 은 존재하지 않아 "not_found" 분할 실패. 우측 pane 을 아래로 분할하면 컬럼 비율(60:40) 유지.
- 첫 워커 = 팀 생성자 = 참가자 (anchor/placeholder/seed 금지 — 군더더기 pane + in-process 좀비 핸들). team-id 는 첫 Agent spawn 결과(`<name>@session-<id>`)로만 얻는다(우회 생성 불가).
- Lead 세션 ID ≠ team-id (팀 config 의 `leadSessionId` 조차 Lead 세션 ID 아님).
- 회의 워커 `subagent_type` 은 반드시 `"claude"` — claude-code-guide/Explore 등 제한 타입은 SendMessage 비활성이라 조용한 데드락.
- `--allowedTools` 누락 시 제한 모드에서 post 자동 거부 → "수신만 되고 발신 불가" 반쪽 참가자(회의 데드락 직접 원인).

### R-16. 회의 워커 = NTP binding + 버스 board 2채널 공존 (이름표 + 토론, 실측 확정)
- **사고**: 2.40.0 에서 회의 워커를 "빈 pane + CLI 직접부팅"(`claudex -c mcp_servers.bus`, `claude --model …`)으로 띄우며 **`--claude-team-agent` binding 을 빠뜨림** → ① pane 이름표(`@logistics`) 사라짐 ② NTP 노크(ntpPush) 대신 cmuxKnock(느림) 폴백. 원래(첨부 이미지 정상) claudex 는 `--claude-team … --claude-team-agent … -c mcp_servers.bus` 로 떠서 binding+버스 공존했다(2026-06-25 사용자 세션 재확인).
- **2채널 공존 원리** (사용자 실측 확정):
  | 채널 | 용도 | 매체 |
  |---|---|---|
  | **NTP**(네이티브 팀원) | pane 이름표(`@name`) + 노크 깨우기 | Claude 팀 inbox(`--claude-team` binding) |
  | **MCP 버스**(board) | 토론 본문 전부(브로드캐스트 — 전원 열람) | `board.jsonl` + `multi-round-bus` MCP |
  → **NTP 로 띄우되 `DEFT_BUS_DIR` 주입**하면 같은 워커가 두 채널을 동시에 갖는다(이름표·노크=NTP, 본문=버스).
- **띄우는 절차** (실측 성공 — team-id: 첫 워커 Agent spawn 만이 생성, §H1·H4):
  1. **첫 워커 = claude `Agent` tool**(team 생성) → 반환 `<name>@session-<id>` 에서 team-id 획득. 이 워커는 board MCP 직결 불가 → board 는 Lead 가 `SendMessage` 로 중계.
  2. 첫 워커 pane:ref 를 `~/.claude/teams/<TID>/.last-worker-pane` 에 기록(헬퍼가 그 아래로 스택).
  3. **나머지 워커 = 헬퍼**(전부 `DEFT_BUS_DIR` 주입 → 이름표+board 공존):
     - claudex: `DEFT_BASE_WORKSPACE=<ws> DEFT_BUS_DIR=<SD> deft-claudex-native-spawn <TID> <name>`
     - claude CLI: `DEFT_LEAD_SESSION=$CLAUDE_CODE_SESSION_ID DEFT_BASE_WORKSPACE=<ws> DEFT_BUS_DIR=<SD> deft-claude-native-spawn <TID> <name> "" opus`
     - `DEFT_BUS_DIR` 설정 시 헬퍼가 자동 주입: claudex→`-c 'mcp_servers.bus={…}'`, claude→`--strict-mcp-config --mcp-config <bus>.json`.
  4. board 등록(`multi-round-bus register --name <w> --surface <surf>`) + 의제 게시(`post --inject`) → 발신자 제외 전원 노크, board 전원 공개 → 토론 성립.
  5. 응답 회수 2경로: board 워커는 `multi-round-bus check --as lead`, Agent 워커(첫 워커)는 `team-lead.json` 직접 회수(R-1·R-2).
- **시행착오 교훈**: ① 이름표 위해 순수 NTP(board 없이) 띄우면 토론이 자문으로 퇴화 → 회의=board 강제(R-7) ② **활성 team 디렉토리 `rm` 금지** — 런타임이 team-id 참조 못 해 spawn 에러(복구로 해결) ③ claude 헬퍼는 `DEFT_LEAD_SESSION=$CLAUDE_CODE_SESSION_ID` 필수(onboarding 회피).
- **후속 실측 (claude-2.44.0 — 2.43.0 배포 후 사용자 날것 검증에서 드러난 2건)**:
  - **(가) claude 헬퍼 pane 스택 누락 → 1:1:N 레이아웃**: `deft-claude-native-spawn` 이 무조건 `new-split right`(새 컬럼) 해서 추가 claude 워커가 첫 워커 아래로 안 쌓이고 Lead 옆 새 컬럼을 만들었다(claudex 헬퍼엔 있던 `.last-worker-pane` focus→down 연쇄가 claude 헬퍼엔 통째로 없었음). → 두 헬퍼를 **동일 `.last-worker-pane` 프로토콜**로 맞춰 혼합 회의도 단일 컬럼 스택(Lead 1 : 워커 N) 유지.
  - **(나) claude 워커가 board read 만·write 는 NTP 로 샘**: claude 워커는 NTP binding + board 버스를 **둘 다** 가져 응답 채널이 모호하다 — board 노크를 받아 읽고 다른 워커 발언을 인용까지 하면서도, 응답은 `post_message`(board)가 아니라 `SendMessage`(NTP)로 Lead 에 "보고"해 다른 워커가 그 입장을 board 에서 못 봤다(브로드캐스트 실패 — claudex 워커 vc 화면에 claude 입장 부재로 확인). 원인은 페르소나 §보고 채널 원칙의 "받은 채널로 답"을 claude 가 NTP 쪽으로 적용한 것. claudex 는 board MCP 만 통신 수단이라 이 문제가 없음(선택지 없음). → **회의 모드 한정 board 강제**(페르소나 "회의 모드=board post 전용·SendMessage 금지" + 의제 `응답 채널: board` 명시 + 헬퍼 `--allowedTools mcp__bus__*` 이중 안전망). **작업 모드(NTP mesh)는 board 없으니 `SendMessage` 보고 그대로** — 의제에 `응답 채널: board` 가 없는 것으로 모드를 구분.

### R-15. cmux send 3대 규약 (zsh 환경 실측 — 버스 경로 워커 부팅)
- **사고**: 버스 경로(claude CLI + claudex 인라인 MCP)에서 워커를 pane 에 띄울 때 — pane 분할은 됐으나 ① 입력창에 직전 send 잔여물이 남아 명령 오염(touch 텍스트가 prompt 에 박힌 채 실행 안 됨) ② MCP 인라인(`-c 'mcp_servers...'`)이 수백 자라 cmux send 한 번에 셸 미도달·유실 ③ `surface:N` 의 콜론이 `${pair%%:*}` 파싱을 깨고 zsh 위치파라미터(`set -- $row`)가 비표준이라 어긋남 — 세 가지가 겹쳐 워커가 안 떴다(2026-06-25, 사용자 세션 자체 보정으로 성공).
- **지침 (3대 규약)**:
  1. **send 전 입력창 클리어** — 매 `cmux send` 직전 `send-key C-u`. 잔여 텍스트·Enter 미전달 잔재 제거.
  2. **긴 명령은 `.sh` + `source`** — 부팅 명령을 `$SESSION_DIR/boot-<name>.sh` 에 저장, pane 엔 `source …` 한 줄만 send. 짧은 명령(touch 등)만 직접 send.
  3. **colon ref·zsh 파싱 회피** — 루프·구분자 파싱 금지, 워커별 surface ref 명시적 나열.
- **불일치 메모**: 헬퍼(`deft-claudex-native-spawn`)는 readiness 마커·`--workspace` 동반은 내장하나 C-u·source 파일화는 없다(헬퍼 NTP 경로는 LAUNCH 가 짧고 send 1회뿐이라 덜 취약). 버스 경로는 send 가 길고 많아 이 3규약이 특히 필요.

### R-11. lazy-init readiness — fail-fast 게이트
- cmux 는 surface 가 화면에 렌더될 때 쉘을 기동(lazy-init). 미기동 pane 에 send 하면 입력이 조용히 유실되거나, 사용자가 그새 다른 pane 으로 전환 시 잘못된 pane 에 명령이 들어간다.
- **실측**: FOMC 멀티라운드 셋업 차단 사례. → readiness 마커 확인 전 부팅 금지, 타임아웃 시 BLOCKED + 사용자 보고(무진행 침묵 금지).

---

## codex 워커 (multi-round)

### R-12. 진짜 codex 업데이트 프롬프트
- 진짜 `codex`(claudex 아님)는 첫 기동 시 "Update available" 프롬프트로 정지할 수 있다(claudex 는 자체 최신이라 안 뜸). spawn·readiness 후 감지되면 `"3"`(skip until next version) 입력. 사전 `codex update` 로 예방.

### R-13. 발언 time-box (속도)
- 회의는 의견·설계 토론이라 핵심 권장+근거 1~3줄로 간결히. 과도한 web search(수십 회)·장문 분석 금지(claudex/codex 워커가 web search 로 수 분 늘어지면 라운드 정체). 심층 사실확인은 multi-check/deep-research 가 적합.

### R-17. codex 모델 tool_mode 이원화 — code_mode_only 는 MCP 도구가 top-level 에 없다 (실측 사고 2026-08-03)
- **사고**: claudex 회의 워커(gpt-5.6-sol xhigh)가 `[bus] 메시지 확인` 노크를 여러 번 받고도 실제 MCP 도구 호출 없이 "ACK: 메시지 확인했습니다" 텍스트만 출력하고 턴 종료 — board 를 읽지도 post 하지도 않아 Lead 관점에선 무응답. 같은 세션을 gpt-5.5 로 바꾸자 정상 동작(check_messages → reply_to 응답 게시).
- **원인 (소스+캐시 확정)**: `~/.codex/models_cache.json` 의 `tool_mode` 가 모델별로 다르다 — gpt-5.5/5.4 는 `null`(direct: MCP 도구 top-level 직접 호출), **gpt-5.6-sol/terra/luna 는 `code_mode_only`**(top-level 도구는 사실상 `exec` 뿐, MCP 도구는 exec 내부 JS 의 `tools.<정규화 이름>` nested 로만 노출 — `mcp__bus.check_messages` → `tools.mcp__bus__check_messages`). direct 전제로 쓰인 "check_messages 를 호출하라" 프롬프트를 code_mode_only 모델은 자연어 작업처럼 처리해 텍스트 ACK 만 낸다. 도구가 죽은 게 아니라 **모델이 올바른 호출 표면을 못 고른 것** — exec 내부 호출을 강하게 지시하면 gpt-5.6-sol 도 실제 호출 가능(실측).
- **증폭 요인(부트스트랩 공백)**: 회의 프로토콜 상세는 board 첫 메시지(페르소나)로 전달되므로, 첫 check 를 못 하는 워커는 지침 자체를 영영 못 읽는다. 상시 지침은 노크 문구·버스 도구 설명뿐.
- **대응 (삼중 안전)**: ① **spawn 모델 고정** — `deft-claudex-native-spawn` 이 `-m`(deft-model codex 기본 gpt-5.5, `DEFT_CODEX_MODEL` 오버라이드)을 자동 주입해 사용자 config 기본 모델(5.6 계열) 위임을 차단 ② **노크 문구·버스 도구 설명에 exec 호출 표면 명시**(`tools.mcp__bus__check_messages({})`) — 부트스트랩 공백을 상시 지침이 메움 ③ **페르소나(§도구 호출 표면)에 tool_mode 이원화 표+호출 예제** 명시.
- **NTP 는 안전 (소스 확정)**: `send_message` 는 codex 네이티브 도구로 `multi_agent_v2.non_code_mode_only` 기본 `true` → `ToolExposure::DirectModelOnly` → code_mode_only 모델에서도 top-level 유지 (claudex `core/src/tools/spec_plan.rs`). 작업 모드(순수 NTP mesh)·첫 워커 SendMessage 중계는 영향 없음. agent-teams(전원 claude)·multi-check(`deft-review` 가 `-m gpt-5.5` 고정 + headless exec — MCP 불요)도 무관.

---

---

## 리뷰어 실행 (multi-check)

### R-18. timeout 은 실패가 아니라 "진행 중" — 결과 보고와 구분 못 하면 완성된 분석이 폐기된다 (실측 사고 2026-09-07)

- **사고**: multi-check 정규 경로(Agent 리뷰어)로 **양쪽 엔진 모두 결과 0**. Lead 가 CLI 를 직접 실행하는 우회로만 목적을 달성했다. 장애 기록 원본: `skills/multi-check/INCIDENT-2026-09-07-reviewer-timeout.md`.
- **연쇄 (4중 결함이 겹침)**:
  1. **timeout 예산 불일치** — 페르소나가 `Bash, timeout 120000`(2분)을 지시했으나 `gpt-5.5`+xhigh 로 수 KB 프롬프트를 검토하면 **3~6분**, web search 가 붙으면 **10분+**. 즉 **짧은 질문에서만 동작하고 스킬의 본래 용도(설계·코드 교차검증)에서는 구조적으로 항상 실패**했다. 게다가 페르소나가 `run_in_background` 를 금지해 리뷰어에게 우회 수단이 없었다.
  2. **실패 보고를 결과 보고로 오인** — Phase 4 는 "report 1건 수신 → 즉시 `shutdown_request`" 였고 **보고 종류를 구분할 분기가 없었다.** timeout 보고는 결과가 아니라 실패인데 Lead 가 종료를 보냈고, 리뷰어가 죽으면서 **background 로 밀려 아직 돌던 CLI 까지 함께 사라졌다**(출력 파일 말미가 `[killed]`). 8,416바이트가 남았지만 대부분 프롬프트 에코 + web search 로그였고 분석 본문은 시작 전이었다.
  3. **Error Handling 이 폐기를 제도화** — 표에 `Timeout (agent doesn't respond in 120s) | Synthesize with available results` 가 있어, 분기가 없는 정도가 아니라 **"있는 것만 갖고 취합하라"고 명시**돼 있었다. Phase 4 만 고치고 이 행을 두면 수정이 무효화된다.
  4. **git 리포 밖 실행 불가** — `deft-review codex` 가 `--skip-git-repo-check` 없이 `codex exec` 를 불러 리포 밖에서 `Not inside a trusted directory and --skip-git-repo-check was not specified` 로 **exit 1**. 스킬·페르소나 어디에도 "리포 안에서 실행" 전제가 없었고, Lead 우회 실행의 cwd 가 `~` 라 즉시 실패했다.
- **소스 확정**: `claudex exec --help` → `--skip-git-repo-check  Allow running Codex outside a Git repository`. 수정 후 `/tmp` 에서 `deft-review codex` 정상 응답 실측.
- **처방 (구조)**: **timeout 의 의미를 재정의**한다 — Bash 는 timeout 시 작업을 죽이지 않고 background 로 옮기므로 **작업은 살아 있다**. 따라서 timeout 은 "실패"가 아니라 "아직 진행 중"이다.
  - 리뷰어: 예산을 **600000(10분)** 으로 올리고, 그래도 넘치면 ① 첫 줄 `TIMEOUT_PARTIAL` 센티널로 **중간 보고** ② `BashOutput` 으로 완료를 이어받아 대기(간격 60초+, 상한 20분) ③ 완료 시 첫 줄 `RESULT` 로 **재보고**.
  - Lead: 보고 **첫 줄 센티널로 종류를 판별** — `RESULT`/확정 실패면 즉시 shutdown, `TIMEOUT_PARTIAL` 이면 **shutdown 보류**.
  - ⚠️ 예산 숫자만 올리는 처방은 **불충분**하다 — 10분을 넘기는 검토에서 동일 사고가 그대로 재발한다. 센티널 분기가 본질이다.
- **센티널을 쓰는 이유**: deft 취합자는 코드가 아니라 **LLM Lead** 라 JSON verdict 계약을 채택하지 않았다(claude-2.49.0 결정). 같은 사상으로 **첫 줄 센티널 + 자유 텍스트** 가 최소 계약이다 — Lead 가 기계적으로 분기할 수 있으면서 본문은 그대로 읽힌다.
- **time-box 는 금지형으로**: 권고형("과도한 다중 web search 는 하지 말 것")은 **claudex 에 효과가 없다** — 같은 세션에서 권고형에 web search **11회**를 수행했고, "웹 검색 절대 금지"로 바꾸자 즉시 준수하며 수 분 내 완료했다.
- **stderr 를 삼키지 말 것**: `deft-review` gemini 경로의 `2>/dev/null` 은 잡음과 함께 **실패 원인까지** 버려 빈 출력만 남긴다. codex/claude 경로처럼 흘려보내고 "경고는 무시" 규약으로 처리한다.
- **동형 결함은 엔진마다 확인할 것 (deft-test 검증 중 발견)**: trusted directory 제약은 codex 만의 것이 아니다 — **gemini 도** `not running in a trusted directory` 로 막히며, 승인 대기에 걸려 **무한 hang** 하고 `--approval-mode plan` 이 default 로 강등된다(`--skip-trust` 로 해소). 한 엔진에서 실행 계층 결함을 고치면 나머지 엔진에서 동형을 반드시 확인한다.
- **센티널은 실패 경로까지 덮어야 한다 (deft-test 검증 중 발견)**: "센티널 없음 = 결과"로 두면 **CLI 에러 본문이 검토 의견으로 취합**된다. 실행 실패(인증·티어·model·sandbox)는 첫 줄 `FAILED` 를 강제하고, Lead 는 센티널 없는 보고의 본문이 결과인지 에러인지 한 번 확인한다.
- **Codex 포트 차이**: 포트는 reviewer 가 **독립 pane 프로세스 + `tee` 파일**이라 폴링 예산이 끝나도 CLI 가 계속 돌고 출력 파일이 완성된다 — **조기 종료 사고는 포트에서 발생하지 않는다.** 다만 예산 120s 는 동일하게 짧아 600s 로 올렸다(미완료는 partial 보존, pane 을 닫지 않는다).
- **정상 동작했던 것 (오해 방지)**: orca 판정·가드 skip·페르소나 인라인·graceful 종료·`SendMessage` 보고 규약은 **전부 설계대로**였다. 실패는 **CLI 실행 계층**(timeout·trusted directory·검색 폭주)에서만 났다 — orca pane 조작을 의심하지 말 것.
- **지침**: multi-check `SKILL.md` §Phase 1 time-box·§Phase 4 ①보고 종류 판별·§Error Handling, `agents/*-reviewer.md` §실행(timeout 예외 절차), `bin/deft-review`.


### R-19. 완료 판정은 exit code 로만 — 출력 정체는 완료가 아니다 (설계 보강 2026-09-15)

- **계기**: R-18 처방(timeout=진행 중)을 정규 경로로 검증하던 multi-check 실행에서, 두 리뷰어가 **독립적으로** 같은 약점을 지적했다. Codex 리뷰어: "완료 판정이 output 안정성뿐 → 긴 정지 구간을 완료로 오판. `byte size/mtime` 은 참고만, 완료 판정 금지. `.done`/`status.json` sidecar 필수". Claude 리뷰어: "`echo $? > done.flag` 래핑 — exit code 파일이 유일한 완료 판정 기준".
- **문제**: R-18 의 이어받기는 리뷰어가 출력 파일을 `Read` 하며 기다리는데, **"파일이 더 안 자란다"가 완료와 구분되지 않는다.** xhigh 추론은 수십 초간 아무것도 쓰지 않는 침묵 구간이 있어, 그 순간을 완료로 읽으면 **미완성 출력이 최종 결과로 취합**된다.
- **`exec` 가 걸림돌이었다**: 종전 `deft-review` 는 마지막 줄이 `exec "$CLI" …` 였다. 프로세스를 교체하므로 **exit code 를 기록할 주체가 사라진다** — 리뷰어들은 헬퍼 소스를 보지 못해 이 제약을 몰랐고, 제안대로 래핑하려면 `exec` 제거가 선행돼야 했다.
- **처방**: `exec` 제거 → 자식으로 띄워 `rc` 캡처 → **job dir 에 `exit_code` 기록** → `exit $rc` 로 종료 상태 전파. 제어 신호는 **stdout 을 오염시키지 않도록 stderr 로만** 낸다(첫 줄 `DEFT_REVIEW_JOB=<dir>`, 마지막 줄 `__DEFT_REVIEW_EXIT__:<rc>:<nonce>`) — "헬퍼 출력을 그대로 사용" 규약 보존. `nonce` 는 모델이 제어 문자열을 흉내내도 위조할 수 없게 한다(Codex 리뷰어의 "모델 출력과 제어 신호 충돌" 지적 대응).
- **실측 확인**: 하네스의 timeout→background 출력 파일에 **stderr 가 포함**된다(`(echo out; echo err >&2; sleep 15)` 를 timeout 5s 로 검증) → timeout 경로에서도 마커를 읽을 수 있다.
- **🚨 `cancel` 의 자기 학살 결함 (실측 사고 2026-09-15)**: 상한 초과 시 자식을 정리하려면 **프로세스 그룹** kill 이 필요하다(claudex 는 `node → 네이티브 바이너리` 로 자식을 더 띄워 단일 PID kill 은 고아 4개를 남긴다 — 실측). 그런데 자식이 **새 프로세스 그룹을 갖지 못하면 pgid 가 호출자 그룹과 같아**, `kill -TERM -- -$PGID` 가 **취소를 요청한 리뷰어·Lead 세션까지 죽인다**(검증 중 호출자 Bash 가 SIGTERM 으로 종료, exit 144). 처방은 이중이다: ① `set -m`(job control)으로 자식을 새 프로세스 그룹에 띄운다(macOS bash 에서 새 pgid 부여 실측) ② `cancel`·trap 양쪽에 **자기 그룹 보호 가드** — `pgid == 호출자 pgid` 면 그룹 kill 을 포기하고 기록된 pid 만 정리. 가드 없이 배포했다면 리뷰어의 상한 초과 정리가 Lead 를 거뒀을 것이다.
- **시그널 semantics 보존**: `exec` 시절에는 시그널이 CLI 에 직접 갔다. 래퍼가 한 단계 끼면서 `trap TERM INT HUP` 으로 자식 그룹에 명시 전파한다 — 실측: 래퍼에만 SIGTERM 을 보내도 CLI 그룹 5개가 전부 종료되고 `exit_code=143` 이 기록된다. "리뷰어 종료 시 CLI 도 종료"(P2 의 전제)가 변하지 않는다.
- **양 트리 일관성이 이 보강의 두 번째 목적**: Codex 포트는 `deft-review` 를 **쓰지 않고** raw 명령을 pane 에 send 했고, 완료 판정이 `CMD | tee out; touch done` 이었다 — `;` 라 CLI 실패와 무관하게 `.done` 이 생기고, 파이프 exit code 는 `tee` 것(PIPESTATUS 미사용)이어서 **실패를 완료로 오판**했다. 같은 결함의 더 나쁜 형태다. 포트를 `deft-review --job-dir` + `deft-review status` 폴링으로 전환해 완료 판정 규약을 단일화했다.
- **🚨 취소 경로의 판정 모순 (E2E 실측 2026-09-15 · 초판 결함)**: `cancel` 초판은 시그널을 보낸 뒤 `exit_code` 를 `CANCELLED` 로 덮어썼다. 그런데 **claudex 는 SIGTERM 을 graceful 처리해 `exit 0` 으로 끝난다** — 래퍼가 먼저 `exit_code=0` + 마커 `:0:` 를 기록하고, 마커는 이미 stderr 로 나가 되돌릴 수 없다. 결과: **마커는 "성공 rc=0", `status` 는 "CANCELLED"** 로 두 판정 근거가 모순되고, 마커로 판정하면 **잘린 출력이 성공으로 취합**된다. 게다가 두 주체가 같은 파일을 경쟁적으로 써서 순서에 따라 `status` 가 `EXIT 0` 이 될 수도 있었다.
  - **처방**: `cancel` 은 시그널 **전에** `cancel_requested` 플래그만 쓰고 `exit_code` 를 건드리지 않는다(래퍼가 SIGKILL 로 사라진 경우만 보강). 래퍼는 `wait` 반환 후 플래그가 있으면 자식 rc 와 **무관하게** `exit_code=CANCELLED` + 마커 `__DEFT_REVIEW_EXIT__:CANCELLED:<nonce>` 를 기록한다. `status` 도 플래그 우선. → `exit_code` 작성자가 래퍼 하나로 줄어 경쟁이 사라지고 두 근거가 같은 값을 말한다(실측 재검증: status·exit_code·마커 3곳 모두 `CANCELLED`, 그룹 잔존 0, 호출자 생존, 재호출 멱등).
  - **교훈**: "종료 코드 0 = 성공" 은 **취소 경로에서 거짓**이다. 취소는 CLI 입장에서 정상 종료이므로, 취소 의도는 CLI 의 rc 가 아니라 **오케스트레이터가 별도로 기록**해야 한다.
- **제어 신호 누출 (E2E 실측)**: 헬퍼는 stdout 을 오염시키지 않았으나, **리뷰어가 Bash 도구 결과(stdout+stderr 병합)를 통째로 보고 본문에 붙여** `__DEFT_REVIEW_EXIT__` 줄이 검토 결과에 섞였다. 첫 줄 센티널 판별에는 영향이 없었지만 사용자가 제어 문자열을 결과로 읽는다. 처방: 페르소나·SKILL 에 "제어 두 줄은 보고 본문에서 제외, job 경로는 `job:` 줄로만" 명시. **규약을 헬퍼에서만 지켜도 소비자가 어기면 새는** 전형이다.
- **이어받기 재보고의 요약 손실 (E2E 실측 2026-09-15)**: 리뷰어가 background 완료를 이어받아 `RESULT` 로 재보고할 때, **27KB·89줄 출력을 6줄 요약으로 대체**했다. 페르소나의 "요약·변형 금지"를 어긴 것인데 **foreground 정상 경로(1KB 내외)에서는 발생하지 않았다** — 큰 출력을 `SendMessage` 본문으로 옮길 때만 나타나는 압축 성향이다.
  - **처방의 방향이 중요하다**: 페르소나 문구를 강화하는 것만으로는 부족하다(LLM 성향을 프롬프트로 완전히 막을 수 없다). **Lead 가 동봉된 `output_file:` 경로의 파일을 1차 소스로 읽어 취합**하는 구조적 안전망을 둔다 — 보고 본문과 파일이 다르면 **파일이 정답**이다. 페르소나에는 "요약 대신 경로만 줘도 된다"는 탈출구를 함께 준다(요약을 강요받는 상황 자체를 없앤다).
  - **Codex 포트는 구조적으로 면역**: 포트는 reviewer 출력이 애초에 `$OUT_DIR/<engine>.out` 파일로 떨어져 파일이 곧 1차 소스다. 이 차이가 "같은 규약, 다른 구조"의 값이다 — 다만 pane 스크롤백을 옮겨 적으면 같은 손실이 나므로 "반드시 파일을 읽어 취합" 을 명시했다.
- **P2(detach)와의 관계**: 이 job dir + `pid`/`pgid` + `cancel` 규약이 P2 의 전제(job registry·완료 marker·취소 API)를 그대로 만든다. P2 는 `set -m` 을 `setsid` 로 바꾸는 정도로 줄어든다 — 다만 착수 판단은 불변(PENDING 참조).
- **지침**: `bin/deft-review`(양 트리 동일), multi-check `SKILL.md` §Phase 4, `agents/*-reviewer.md` §실행, codex 포트 `SKILL.md` (3)(4).

## 출력 / UX (전 스킬 공통)

### R-14. Lead 출력 레지스터 — 의미 이벤트만
- 에이전트/cmux UI 가 pane·워커 상태를 이미 시각화하므로, 대화 화면 텍스트는 그 UI 가 못 보여주는 **의미**(누가·무엇을·어떤 결과)만 담는다. 프로세스 실황 중계는 중복이고 일반 사용자에게 잡음.
- **실측 피드백**(2026-06-25): spawn 단계별 나레이션("첫 워커 spawn / team-id 확인 / 두 번째 추가 …")이 과다 → **announce 지점을 고정**(시작 예고: 요청+인원+페르소나 한 번에 / 스폰 완료→시작 / 중간 결과 / 최종 결론 / 사용자 개입)하고 그 사이 spawn 은 한 턴에 묶어 말없이 연속 실행.
- 내부 메커니즘(CLI 부팅·버스 등록·pane 분할·페르소나 주입·헬퍼 동기화·레이아웃 정렬·team-id·"Ran N shell commands")은 `orchestration.log` 로만, 대화에 중계 금지.
