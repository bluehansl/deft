---
name: multi-round
description: '여러 AI(Claude/Claudex/Codex)가 두 통신 모드로 협업하는 멀티턴 skill — ① 회의 모드: N라운드 양방향 토론으로 의견을 좁혀 합의 도달(board 브로드캐스트 + 노크) ② 작업 모드: board 없는 순수 NTP mesh 로 이종 AI 가 일을 분담 실행(Lead↔mate 1:N + mate↔mate N:N, work.md 취합). 강한 트리거 — "회의"/"미팅"/"논의"/"토론" → 회의 모드 (예: "회의 열어줘", "이 주제로 미팅"), "작업지시"/"작업요청"/"의뢰" → 작업 모드 (예: "이 분석 작업지시해", "조사 의뢰해줘"). 그 외 트리거 — "멀티 라운드", "라운드 토론", "AI끼리 토론시켜", "수렴할 때까지 주고받아", "multi round". 단 "코딩 작업"(실제 파일 수정·구현)은 agent-teams, 1발 비교는 multi-check 를 쓰세요.'
---

# Multi-Round Skill

여러 AI가 **여러 라운드에 걸쳐 양방향으로 의견을 주고받는** 토론·합의 도구. **메시지 버스 (브로드캐스트 보드 + cmux 노크)** 로 동작 — 워커는 pane 의 살아있는 TUI 본체(지속 대화), 통신 본문은 버스 보드, 깨우기는 한 줄 노크.

> ## 🎯 Lead 운영 2대 원칙 (최우선 — 전 Phase 강제)
>
> **원칙 1 — Lead 본체는 즉각 반응 우선. 대기는 전부 백그라운드.**
> - 메인 세션의 **단 하나의 목표는 사용자 질의에 즉각 반응할 수 있는 idle 상태 유지**다. 실제 능동 작업(spawn·페르소나 생성·pane 분할)을 **실행하는 순간에만** 바쁘고, 그 외 — **특히 팀원 응답·노크를 기다리는 모든 구간** — 은 메인을 점유하지 않는다.
> - 🚫 **대기를 foreground 로 구현 절대 금지** (긴 `sleep` 루프·`wait`·동기 폴링·`watch` 포그라운드 실행 등). 그 Bash 가 도는 동안 메인 턴이 블록돼 사용자 입력·워커 노크 모두 못 받는다(실측 데드락 — `Flummoxing…`/`Forging…` 으로 수십 초~수 분 멈춤). **대기가 필요하면 `run_in_background`(`&`)로 던지고 메인은 즉시 턴을 끝낸다** — 결과는 노크/자동주입/백그라운드 완료 알림이 **다음 턴**에 가져온다. "응답 올 때까지 기다린다"를 Lead 가 능동 sleep 으로 구현하지 말 것.
>
> **원칙 2 — 출력은 "고정된 announce 지점"에서만. 단계 중계 전면 금지.**
> - 사용자는 스킬을 **직접 의도해서** 호출했다 — 상세 진행 보고가 필요 없다. Lead 가 대화에 말하는 지점은 **아래 5개로 고정**하고, 그 사이 모든 단계는 **말없이 연속 실행**한다(여러 spawn·bash 를 한 턴에 묶어 처리하고 중간에 한 줄씩 말하지 말 것):
>
>   | # | 유일한 announce 지점 | 예시 |
>   |---|---|---|
>   | 1 | **회의 시작 예고** — 요청 + 인원 + 각 페르소나를 **한 번에** | "claudex·claude 를 섞어 4명을 스폰합니다. 페르소나: 물류 / 로보틱스 / IT / 투자." |
>   | 2 | **스폰 완료 → 회의 시작** | "팀원 4명 스폰 완료 — 멀티 라운드 회의를 시작합니다." |
>   | 3 | **라운드 중간 결과** (라운드 전환 시 1회) | "라운드 1 결과: 3인 긍정·1인 신중 — 쟁점은 …" |
>   | 4 | **최종 결론/합의** | "합의 7.4/10 — 결론: …" |
>   | 5 | **사용자 개입 필요 시**(BLOCKED 등) | 사용자 친화 문구로 무엇이 필요한지만 |
>
> - 🚫 **위 5개 외 일체 출력 금지** — 특히 다음 단계 중계를 **하지 말 것**: "첫 워커를 spawn합니다 / team-id 확인 / 두 번째 워커 추가 / claudex 워커 2명 추가 / 먼저 pane 기록 / N번째 워커 기동 완료 / 회수 루프 먼저 띄웁니다 / 의제 발송합니다" 같은 **spawn·통신 단계별 나레이션**. spawn 은 1번 예고 후 **전부 한 번에 조용히** 실행하고 2번에서 완료만 알린다.
> - 🚫 **내부 메커니즘 출력 금지** (`orchestration.log` 로만): CLI 부팅·버스 등록·pane 분할·페르소나 주입·헬퍼 동기화·세션 초기화·레이아웃 정렬·readiness·team-id·rebalance·"Ran N shell commands".
> - 기준: cmux/agent UI 가 pane·워커 상태를 이미 시각화한다. 절차의 bash·헬퍼 호출은 **실행 지침**이지 읽어줄 대본이 아니다. (상세 §Lead 출력 레지스터 규약)

## 3-도구 멘탈 모델 (사용자 안내용)

| 도구 | 통신 방식 | AI 조합 | 의존성·기반 | 언제 쓰는가 |
|---|---|---|---|---|
| `multi-check` | **1회성** fan-out (응답 비교) | Codex/Claude/Gemini 동시 | CLI 직접 호출 (MCP 무관) | "한 번 물어보고 답만 비교" |
| **`multi-round`** | **지속 통신** (N라운드 양방향) | **Claude + Claudex (또는 Codex/Claude mix)** | **메시지 버스 + cmux pane** | "의견 갈려서 여러 번 주고받으며 좁히고 싶다 / 토론" |
| `agent-teams` | **지속 통신** (multi-turn 협업) | **Claude끼리만** | **Claude 팀 기능 베이스** | "실제 코드 분담·구현·리뷰·작업노트" |

판단 키워드: **답이 하나면 `multi-check`, 답을 좁혀가야 하면 `multi-round`, 코드를 만져야 하면 `agent-teams`.**

> `multi-round` 의 `collaborate` 모드는 **분담 검토 / 분담 설계 / 독립 의견 작성 후 상호 리뷰** 까지. 실제 파일 수정·테스트·작업노트 가 필요한 순간은 `agent-teams` 로 승격.

### 도구 선택 기준 — 사용자 입력 예시 매핑

| 사용자 입력 예시 | 발동 도구 | 이유 |
|---|---|---|
| "GPT랑 Claude 답 비교해" / "한 번 물어보고 답 모아" | `multi-check` | 1회성 비교 의도 |
| "**멀티 라운드로** 백엔드 로직 어떻게 짤지 논의해줘" | `multi-round` | 명시적 트리거 |
| "결제 트랜잭션 격리 수준 두 AI랑 토론해서 정해" | `multi-round` | 합의 도달 의도 |
| "REST vs GraphQL — Claude랑 Codex 의견 좁혀줘" | `multi-round` | 양방향 좁히기 |
| "AI끼리 합의될 때까지 주고받아" | `multi-round` | 합의 종료 조건 명시 |
| "기능 X 만들어 — backend·frontend·qa 셋 만들어 분담" | Agent Teams | 코드 분담·파일 작업 |
| "이 PR 두 명 시각으로 사인오프받아" | Agent Teams (review-fix-signoff-loop) | 사인오프 루프 |

## 환경 판정 — cmux vs orca (전 Phase 공통·최우선)

deft 스킬은 두 pane 환경을 지원한다: **cmux**(`cmux claude-teams`)와 **Orca**(stablyai/orca — `orca claude-teams`). pane 조작이 나오는 모든 절차 전에 아래 판정을 먼저 수행한다.

```bash
# ⚠️ 판정 순서 필수 — ORCA 먼저. Orca 터미널 안에서도 cmux CLI 가 소켓으로 **별도 실행 중인
#    cmux 앱**에 연결되어 정상 응답하므로(실측 — orca 안 `cmux list-panes --json` 이 cmux 앱의
#    pane 목록을 반환), `cmux identify` 성공 여부로 판정하면 orca 안에서 cmux 모드로 오판된다.
if [ -n "${ORCA_WORKTREE_ID:-}" ] || [ -n "${ORCA_TERMINAL_HANDLE:-}" ]; then
  DEFT_ENV=orca      # Orca 터미널 (ORCA_* 변수는 Orca 가 세팅 — ORCA_PANE_KEY/ORCA_TAB_ID 등도 존재)
elif command -v cmux >/dev/null 2>&1 && cmux identify >/dev/null 2>&1; then
  DEFT_ENV=cmux
else
  DEFT_ENV=none      # 어느 쪽도 아님 — pane 시각화 불가 환경
fi
echo "deft 환경: $DEFT_ENV"
```

### orca 모드 규칙 (오발사 가드 — 최우선)

- 🚨 **orca 모드에서 cmux CLI 호출 전면 금지** — 에러가 나는 게 아니라 **별도 cmux 앱의 엉뚱한 pane 을 조용히 조작**한다(오발사, 실측). deft bin 은 orca 를 자체 인지한다 — **spawn 헬퍼(deft-claudex/claude-native-spawn)와 버스 노크(cmuxKnock)는 orca 경로로 자동 분기**하고, rebalance 계열(cmux-rebalancing/-guard/-watch)·deft-cmux-shim 은 no-op/차단한다.
- **`tmux` 는 다르다 — orca claude-teams 의 tmux shim 이 팀원 pane 한정으로 실구현한다** (실측 — `which tmux` = `~/.orca/claude-agent-teams-bin/tmux`, 'tmux 3.4' 표방. 구현 소스: Orca.app `out/shared/claude-agent-teams-tmux-compat.js`):
  - 실구현: `list-panes`(-F/-t)·`send-keys`(-t/-l·특수키 변환)·`capture-pane`·`split-window`·`select-pane`·`kill-pane`·`last-pane`·`display-message`. 미지원: `swap-pane`·`list-windows`. **`resize-pane` 은 no-op**이고 `#{pane_width}` 등 geometry 포맷 변수도 빈 값 — 크기 측정·조정 모두 불가 확정.
  - **관할 한정**: shim 은 **Agent Teams 가 spawn 한 claude 팀원 pane(team.panes)만** 관리한다 — orca terminal 로 직접 만든 pane(claudex/codex 워커 등)·일반 워크스페이스 터미널은 비대상(실측: list-panes 가 리더+팀원 pane 만 반환). 따라서 **팀원 pane 의 화면 읽기/입력/정리는 tmux 문법 그대로 유효**하고, claudex/codex 워커 pane 은 **orca terminal read/send/wait/close 경로**를 쓴다.
- **pane 명령 대응표** (cmux → orca 등가, 실측 Orca 1.4.150):

| 용도 | cmux 모드 | orca 모드 |
|---|---|---|
| pane 분할 | `cmux new-split right\|down` | `orca terminal create` / `orca terminal split --direction vertical\|horizontal` — ⚠️ **direction 은 분할선 방향(실화면 실측 — orca-cli 가이드 문구와 반대)**: `vertical`=좌우 배치(anchor **우측** 생성), `horizontal`=상하 배치(anchor **아래** 생성) |
| 화면 읽기 | `cmux capture-pane` | `orca terminal read` (`--cursor`/`--limit` 커서 페이징). **claude 팀원 pane 은 `tmux capture-pane`(shim) 도 유효** |
| 물리 입력 | `cmux send` + `cmux send-key Enter` | `orca terminal send --text "<한 줄>" --enter`. **claude 팀원 pane 은 `tmux send-keys`(shim) 도 유효** |
| TUI 응답 대기 | (없음 — idle-stable 폴링) | `orca terminal wait --for tui-idle --timeout-ms <N>` (agent CLI idle 판정 내장) |
| pane 비율 조정 | `cmux-rebalancing` | **불가** — `orca terminal resize` 부재 + tmux shim `resize-pane` no-op·geometry 변수 빈 값(소스 실측 확정). "pane 비율은 UI 드래그로 조정" 안내로 대체 |
| pane 정리 | `cmux close-surface` / `tmux kill-pane` | orca terminal 직접 생성 pane(claudex 등): `orca terminal close --terminal <handle>` (실측 — ptyKilled 포함) / claude 팀원 pane: **`tmux kill-pane`(shim)만** — 🚨 팀원 pane 에 `orca terminal close` 를 쓰면 shim 레지스트리가 어긋나 이후 Agent spawn 이 `terminal_exited` 로 깨진다(실측 — 복구: `tmux kill-pane -t %N`). 어느 쪽이든 shutdown 정상 종료(워커 자기종료) 우선, orphan 만 close |

- 세부 플래그·터미널 핸들 지정·페이징 규약은 **`orca skills get orca-cli`** 가 버전 일치 단일 소스 — orca 명령 실행 전 확인한다(릴리즈마다 플래그가 변할 수 있음).
- **Agent tool 워커의 pane 시각화는 orca claude-teams 가 자동 처리** — Orca 는 Agent Teams 용 tmux shim(`~/.orca/claude-agent-teams-bin/tmux` → `orca agent-teams-tmux` exec 위임)을 PATH 에 넣어 팀 spawn 의 tmux 호출을 네이티브 pane 분할로 변환한다(실측). 즉 첫 워커(Agent tool)는 orca 모드에서도 절차 변경 없음.
- **rebalance 계열(cmux-rebalancing·cmux-rebalance-guard·cmux-rebalance-watch)은 orca 모드에서 호출하지 않는다** — 호출돼도 bin 가드가 no-op 종료하지만, 발사 지침이 나오는 모든 위치(§운영 용례 1·Phase 4-T·Phase 5-B)에서 orca 모드면 skip 한다.
- claudex 는 프로세스 실행·mcp-server 통신 모두 환경 무관으로 동작한다(실측) — orca 모드에서 달라지는 것은 **pane 기동·노크 전송 수단**뿐이다. board·inbox(ntpPush)는 파일 기반이라 양쪽 환경 동일.
- 이하 본문의 cmux pane·cmux 명령 서술은 **cmux 모드 기준**이다. orca 모드에서는 본 대응표와 각 Phase 의 `🟠 orca 모드` 분기를 따른다.

## 통신 모드 — 회의 vs 작업 (상위 분기)

multi-round 는 두 통신 모드로 동작한다. **차이는 브로드캐스트(board) 유무**다.

| 통신 모드 | 트리거 | 통신 구조 | board(브로드캐스트) | audit |
|---|---|---|---|---|
| **회의 모드**(기본) | "회의"/"미팅"/"논의"/"토론" | board 브로드캐스트 + 깨우기 NTP — 전원이 모든 발언을 보며 의견 수렴 | **있음**(`board.jsonl`) | `summary.md` + board 회의록 |
| **작업 모드** | "작업지시"/"작업요청"/"의뢰" | **순수 NTP mesh** — Lead↔mate 1:N + mate↔mate N:N 점대점. board 없음 | **없음** | agent-teams `work.md`(같은 work-id) |

- **회의 모드**: 의견을 모으고 좁혀 **합의에 도달**하는 게 목적. 전원이 board 를 보며 토론(회의실 메타포). 아래 회의 형태(consult/dialogue/...) 4종으로 세분.
- **작업 모드**: 일을 나눠 **분담 실행**하는 게 목적. Lead 가 각 mate 에 작업을 지시(1:N)하고, mate 끼리도 직접 협의(N:N) — 모두 NTP(`SendMessage`/`send_message`) 점대점. 결과는 `work.md` 에 Lead 단독 취합. 형태 구분 없는 단일 mesh. (상세 §작업 모드 워크플로)
- 트리거가 모호하면 §Phase 1 에서 사용자에게 확인. 기본은 회의 모드.

## 회의 모드 (형태 — 회의 모드일 때 세분)

| 모드 | 한 줄 설명 (사용자 노출용) | 종료 조건 |
|---|---|---|
| `consult` | **단발 자문** — 한 번 답변 받고 종료. 빠른 사실 확인용 | 첫 응답 1회 + DONE |
| `dialogue` (기본) | **양방향 토론** — 의견 좁혀 합의 도달까지 N라운드 주고받기 | `CONSENSUS` 양쪽 일치 또는 max-round 도달 (기본 5) |
| `collaborate` | **분담 협업** — 작업을 둘로 나눠 각자 진행하고 상호 리뷰 사이클 | 양쪽 `REVIEW_PASS` 교차 |
| `debate` | **반박 토론** — 강한 검증, 한쪽이 항복할 때까지 의견 부딪치기 | 한쪽 `CONCEDE` 또는 max-round 도달 |

### 사용자에게 회의 모드 선택 메뉴 (Phase 1에서 노출)

회의 모드가 사용자 요청에서 명확하지 않으면 다음 메뉴를 그대로 출력하고 1~4 입력 받음:

```
회의 형태를 골라 주세요:
  1. consult    — 단발 자문. 한 번 답변 받고 종료. 빠른 사실 확인용
  2. dialogue   — 양방향 토론. 의견 좁혀 합의 도달까지 N라운드 주고받기 (기본 추천)
  3. collaborate — 분담 협업. 작업을 둘로 나눠 각자 진행하고 상호 리뷰
  4. debate     — 반박 토론. 강한 검증, 한쪽이 항복할 때까지

번호 입력 (기본 2):
```

사용자가 "1~4"를 명시하지 않더라도 입력 문맥에서 의도 추출 가능하면 그 모드로 진행 (예: "토론해줘" → dialogue, "분담해서" → collaborate).

## 신호 프로토콜

기본: `ACK / STATUS / BLOCKED / DONE`
모드별 확장: `CONSENSUS / AGREED / DISSENT / CONCEDE / REVIEW_PASS / REVIEW_FAIL / VERDICT`

신호는 **버스 메시지 본문 안의 줄**로 표기한다 (예: 응답 마지막 줄 `DONE: ...`). pane 화면 캡처가 아니라 보드 본문으로 판정.

## 메시지 버스 아키텍처 (핵심)

### 통신 모델 — 브로드캐스트 보드 + 노크

```
[Lead pane (Claude Code TUI)]      [Worker1 pane (claudex TUI)]   [Worker2 pane ...]
        │  bin 헬퍼 Bash 호출               │  MCP 도구                    │  MCP 도구
        ▼                                   ▼                              ▼
   ┌─────────────────────────────────────────────────────────────────────────┐
   │                        메시지 버스 (SESSION_DIR 공유)                     │
   │  board.jsonl        — append-only 메시지 보드 (본문 전부. 전원 공개)        │
   │  participants.json  — 참가자 레지스트리 (이름 + cmux surface)              │
   │  cursors.json       — 참가자별 마지막 읽은 메시지 id                       │
   │  knocks.json        — 노크 디바운스 상태                                  │
   └─────────────────────────────────────────────────────────────────────────┘
        post 마다: 발신자 제외 전원의 pane 에 cmux send "[bus] 메시지 확인" 노크
```

**채널 분리** — 이 구조의 본질:

| 채널 | 매체 | 싣는 것 |
|---|---|---|
| **데이터** | 버스 보드 (`board.jsonl`, MCP 도구 / bin CLI 로 접근) | 본문 전부 — 줄바꿈·마크다운·길이 제한 없음 (파일 기반 — cmux/orca 환경 무관) |
| **제어** | 노크 — inbox `ntpPush`(회의 워커·orca 모드 유일 경로) 또는 `cmux send`(cmux 모드 surface 폴백) | `[bus] 메시지 확인` 한 줄만 |

→ `cmux send` 의 줄바꿈 조기 제출·sanitize·capture 노이즈 문제가 **구조적으로 사라진다**. pane 은 시각화·사용자 직접 개입 전용, 통신은 보드 전용.

### 6단계 메시지 흐름

1. Lead 가 pane 분할 → 워커 spawn (각 워커 TUI 에 버스 MCP 인라인 주입) + 참가자 레지스트리 등록
2. Lead 는 수신자(워커1)를 지정해 버스에 요청 게시 (`post`)
3. 버스는 게시 즉시 발신자 제외 전원에게 노크 — 보드는 전원 공개 (브로드캐스트)
4. 워커1: 노크 수신 → `check_messages` → 수신자=본인 → 작업 수행 → 응답을 버스에 게시 (수신자=요청자)
5. 워커2: 노크 수신 → `check_messages` → 수신자≠본인 → 컨텍스트로만 검토. 기여할 내용이 있으면 수신자를 지정해 자발 발언 가능
6. 워커1 의 응답 게시가 다시 전원에게 노크 → Lead 가 깨어나 `check` → 다음 라운드. 반복.

### push→pull 변환 (구현 원리)

표준 MCP 는 서버→클라이언트 push 가 불가하므로 "전달"을 두 단계로 변환:
- **게시(pull 대상)**: 보드에 append — 참가자가 `check_messages` 로 읽음
- **깨우기(push 대용)**: 버스가 레지스트리의 surface 로 노크 한 줄 send — TUI 입력창에 주입되어 참가자 턴이 발동

**디바운스 + aged 재노크**: 참가자별로 "마지막 노크 이후 아직 check 안 함" 상태면 추가 노크 skip — 단 그 노크가 60초 이상 경과했으면 다음 post 때 재노크한다 (sent ≠ consumed 보정). 깨어난 참가자는 미독 메시지를 한 번에 모두 읽으므로 노크 1회로 누적 처리된다. 노크 실패 participant 는 레지스트리에 stale 마킹되어 Lead 보고에 표시된다.

**단일 버스**: stdio MCP 서버는 워커마다 인스턴스가 따로 뜨지만 같은 `SESSION_DIR` 파일을 보므로 논리적으로 하나의 버스. 동시 쓰기는 lock 으로 직렬화. 노크는 post 를 접수한 인스턴스가 발사.

**한 코드 두 진입점**: 같은 `multi-round-bus` 스크립트가 — 워커에겐 `mcp` 서브커맨드(stdio MCP 서버, 도구 `post_message`/`check_messages`/`list_participants`), Lead 에겐 `post`/`check`/`register` CLI(Bash 직접 호출). Lead 는 MCP 등록이 전혀 필요 없다.

## 통신 우선순위 매트릭스 (Phase 2 에서 결정)

> 🚨 **전송계층은 모드 종속**: 통신 모드(회의 vs 작업)가 전송계층 선택을 지배한다. 아래 표는 *작업 모드* 기준이고, **회의 모드는 board 브로드캐스트가 본질이므로 무조건 MCP 버스를 쓴다**(claudex 0.139.1+ 가 있어도 NTP 네이티브 1순위 미적용). 회의 속도는 버스의 `ntpPush`(cmux 노크 대신 팀 inbox 자동주입 전파, `multi-round-bus` 내장)가 책임지므로 NTP 네이티브 없이도 빠르다. (근거: RATIONALE R-7)

**회의 모드 (board 토론) — 무조건 버스:**

| 참가자 구성 | 1순위 | 폴백 |
|---|---|---|
| **회의 모드 전부** (claude/claudex/mix 무관, pane 환경 — cmux/orca) | **MCP 버스** (board 공유 + `ntpPush` 빠른 전파 — §Phase 3-A. orca 모드는 워커 기동·노크만 orca 분기) | send/capture (§Phase 3-B — orca 모드는 orca terminal send/read/wait 등가) → 불가 시 `multi-check` 안내 후 중단 |
| pane 환경 외부 (`DEFT_ENV=none`) | claudex MCP conversation (§Phase 3-C) | `multi-check` 안내 후 중단 |

**작업 모드 (board 불요·1:N 분담) — NTP 우선:**

| 참가자 구성 | 1순위 | 2순위 | 3순위 |
|---|---|---|---|
| **Lead=Claude + claudex 워커 (claudex 0.139.1+)** | **NTP — Claude 네이티브 inbox** (board 불요 — §claudex 네이티브 팀원) | MCP 버스 | send/capture 폴백 |
| **AI mix 또는 전원 claudex/codex** (pane 환경 — cmux/orca) | NTP(claudex) / MCP 버스 | send/capture 폴백 | `multi-check` 안내 후 중단 |
| **전원 Claude** | 팀메이트 기능(Agent tool NTP) | MCP 버스 | `multi-check` 안내 후 중단 |

- **claudex 네이티브 팀원 (claudex 0.139.1+, Lead=Claude)**: claudex 가 Claude 네이티브 팀통신(파일 inbox 프로토콜)을 지원하면, 버스 대신 **Claude 의 `SendMessage` 로 직접** 통신한다(버스/노크 불요, Claude-side 변경 0 — Lead 는 평범한 SendMessage 만 씀). 절차·전제는 §claudex 네이티브 팀원. claudex 가 binding 미지원(0.139.0 이하)이거나 Lead 가 claudex 면 자동으로 **버스로 폴백**.
- 하위 순위로 내려가는 조건: 상위 경로의 전제(버스 스크립트·node·cmux·팀 기능)가 충족되지 않을 때. 내려갈 때마다 사용자에게 사유 1줄 보고.
- **헤드리스 1-shot + 컨텍스트 재전송 방식은 금지** — 멀티라운드는 지속 대화가 본질. 그 형태가 필요한 요구면 `multi-check` 가 올바른 도구이므로 안내 후 중단한다.

## NTP — claudex 네이티브 팀원 (claudex 0.139.1+ — 버스 대신 네이티브 통신)

이 통신 방식을 **NTP(Native Teammate Protocol)**라 한다 — Claude Code 의 파일 inbox 네이티브 팀 통신을 claudex 등 이종 AI 에 이식해, 서로 다른 AI 가 같은 팀 inbox 를 공유하며 `send_message` 로 직접 통신(Lead↔팀원·팀원↔팀원)하는 프로토콜. 버스·MCP·중계 없이 Claude 팀 메커니즘을 네이티브로 재사용한다.

claudex 0.139.1+ 는 Claude Code 의 **네이티브 팀원 통신(파일 inbox 프로토콜)**을 말한다(`--claude-team` / `--claude-team-agent` binding). 이때 claudex 워커를 버스 대신 **Claude 네이티브 팀원**으로 붙여, Lead 가 평범한 `SendMessage` 로 직접 통신한다. **Claude(Lead)는 수정 불필요** — 평범한 SendMessage 만 쓰고, claudex 가 프로토콜을 말함으로써 동작한다(전송계층만 네이티브로 교체, 회의 모드·신호·라운드 정책은 그대로).

### 전제
- **Lead = Claude** (claudex 가 Lead 면 이 경로 불가 → 버스).
- 설치된 claudex 가 **0.139.1+** (binding 지원). 미지원(0.139.0 이하)이면 spawn 후 inbox 무반응 → 버스로 폴백.
- pane 환경(cmux 또는 orca — §환경 판정). orca 모드도 claudex 워커 기동은 **같은 spawn 헬퍼**가 자동 분기(`orca terminal split --command` 원샷)로 처리한다(§운영 용례 1 의 🟠 — NTP 통신 자체는 파일 inbox 기반이라 환경 무관, 실측).

### 불변 하네스 규칙 (우회 장치 금지 — 반드시 준수)

> 과거 agent-teams 시절(`AGENTS.teams.md`)부터 팀원 spawn 은 **"첫 팀원 = 팀 생성 + 작업자"** 단일 경로였고, anchor·placeholder·seed 같은 "팀 생성 전용 워커"는 **존재한 적이 없다**(실측 — 그래도 spawn·SendMessage 전부 정상). 아래 규칙을 어기면 군더더기 pane + in-process 좀비 핸들(SendMessage·Esc·kill 다 안 먹는 데드락)이 생긴다.

- **H1. 첫 회의 워커 = 팀 생성자 = 참가자** — 팀을 "먼저 만들고" 워커를 "나중에 붙인다"고 **분해하지 말 것**. 첫 워커 spawn 그 자체가 팀을 만든다.
- **H2. "팀 생성 전용" Agent(anchor/placeholder/seed/team-seed 등)를 spawn 하는 것은 금지.** 어떤 이름이든 "team-id 만 얻으려고 띄우는 워커"는 전부 이 금지에 해당한다. team-id 가 필요하면 **첫 회의 워커**의 spawn 결과에서 얻는다.
- **H3. 회의에는 항상 첫 워커를 claude(`Agent` tool)로 둔다** — 사회자/참가자 역할을 겸하게. claudex 를 N명 띄우고 싶어도 **첫 1명은 claude**여야 그가 팀을 만들고, claudex 는 그 team-id 에 합류한다(claudex 는 외부 바이너리라 팀을 못 만듦). "claudex만 회의"라는 케이스는 만들지 않는다 → placeholder 가 필요할 일이 원천적으로 없다.
- **H4. team-id 를 우회 생성하지 말 것** — config.json 직접 작성·환경변수·`cmux claude-teams` 인자 어느 것으로도 team-id 를 미리 만들 수 없다(실측). 오직 첫 Agent spawn 만이 team-id 를 만든다.

### 절차
1. **첫 claude 워커 spawn = 팀 생성 + 참가 (H1·H3)**: Lead 가 **첫 회의 워커(claude 페르소나)를 `Agent` tool 로 직접 spawn** → 결과 `<name>@session-<id>` 에서 **team-session-id** 추출. 이 첫 워커가 ① 팀 materialize ② cmux 자동 pane 배치(우측 컬럼) ③ 회의 참가를 **겸한다**. (그 spawn 결과가 team-id 의 유일한 신뢰 출처 — 팀 config 의 `leadSessionId` 는 팀 자체 id 라 Claude 세션 id 와 다르므로 자동발견 불가, 실측.)
   - `cmux claude-teams` 는 `--teammate-mode auto` 로 팀 *모드*만 켜고 **team-id 는 첫 Agent spawn 때 비로소 생성**된다(Lead 세션 ID 와 다른 독립 UUID).
2. **claudex 네이티브 기동 (외부 바이너리라 헬퍼로 수동 분할)**: `deft-claudex-native-spawn <team-id> <claudex-agent-name> [cwd]` (Phase 0 자동 설치). claudex 는 Agent tool 로 못 띄우므로(subagent_type 에 claudex 없음) 헬퍼가 `cmux new-split` 로 pane 을 만든다 — 첫 claude 워커 pane **아래로 세로 스택**(2컬럼 유지). 헬퍼는 `--claude-team <team-id> --claude-team-agent <name> --dangerously-bypass-approvals-and-sandbox` 로 기동(readiness 가드 포함). 0.139.1 설치 전 테스트는 `CLAUDEX_NATIVE_BIN=<repo built 바이너리>` 로.
   - **환경 변수**: `DEFT_BASE_WORKSPACE=<Lead 워크스페이스(예: workspace:5)>` 명시 필수 — 비대화형 Bash·resume 후 caller stale 환경에서 cmux 가 `--surface` 단독 ref 를 해석 못 하므로(§cmux 환경 함정), 헬퍼는 `--workspace` 로만 분할한다. `DEFT_BUS_DIR=<회의 SESSION_DIR>` 설정 시 board 버스 공존(회의 모드).
   - **첫 워커가 Agent tool(claude)인 경우**: 헬퍼는 그 Agent pane 을 모르므로(상태파일 미기록), claudex 첫 호출 전에 **Lead 가 첫 워커 pane:ref 를 `~/.claude/teams/<team-id>/.last-worker-pane` 에 수동 기록**한다 → claudex 가 그 아래로 down. (헬퍼끼리는 `.last-worker-pane` 으로 자동 연쇄.)
3. **통신**: Lead 는 `SendMessage(to:"<claudex-agent-name>")` 로 요청. claudex 는 자기 inbox 를 watch·드레인해 자기 턴 경계에 주입받고, `send_message` 도구(평문)로 답신 → Lead inbox → Lead 에 `<teammate-message>` 자동 주입.
   - 🔑 **send_message 필드명은 AI 마다 다르다 (혼동 금지 — 소스 확정)**: 같은 이름(`send_message`)이라도 **수신자 키가 AI 별로 다르다**.

     | 주체 | 도구 | 수신자 키 | 본문 키 | 호출 예 |
     |---|---|---|---|---|
     | **Lead = Claude** | `SendMessage` (대문자, Claude 네이티브) | **`to`** | `message` | `SendMessage(to:"worker2", message:"…")` |
     | **claudex 워커** | `send_message` (소문자, codex 도구) | **`target`** | `message` | `send_message(target:"team-lead", message:"…")` |

     - claudex 의 `send_message` 는 `{target, message}` **두 키만** 받는다(`#[serde(deny_unknown_fields)]` — 그 외 키를 주면 역직렬화 실패). **claudex 가 `to` 로 부르면 도구 호출이 실패**한다. 반대로 Lead(Claude)는 `to` 로만 부른다. (근거: claudex `SendMessageArgs{target,message}` — `core/src/tools/handlers/multi_agents_v2/message_tool.rs`)
     - 즉 claudex 워커에게 보고 형식을 안내할 땐 **반드시 `send_message(target:"<수신자>", message:"<본문>")`** 로 적는다. claudex 페르소나·spawn 프롬프트는 이 형식을 그대로 박는다(§claudex 보고 형식 하네스).
   - ⚠️ **워커 보고 규칙 (출력 ≠ 전달 — 실측 확정·AI 무관)**: NTP 워커는 Lead 가 요청한 작업 결과를 — Lead 의 별도 지시가 없는 한 — **반드시 `send_message`(claudex) / `SendMessage`(claude) 로 보고**한다. 자기 세션에 출력만 하면 Lead 에 전달되지 않는다. 사용자가 워커 TUI 에 직접 친 것만 출력으로 답한다. (페르소나 `agents/*-participant.md` §보고 채널 원칙)
     - 🚨 **자동주입(`<teammate-message>`) ≠ 신뢰 경로 (실측+소스 확정 2026-06-25)**: 워커 메시지는 `team-lead.json` 에 정상 적재되나, **Lead(Claude Code) 런타임 watcher 가 그걸 읽어 비운 뒤 turn 경계(NextTurn phase)에서 대화 주입을 누락**해 유실된다(실측: 회의 4워커 입장이 inbox 적재됐으나 Lead transcript 자동주입 0건). 송신 측 `success:true` 는 inbox 적재까지만 보장한다.
     - ✅ **Lead 직접 회수 강제 (§Lead 직접 회수 — 1차 수신 경로)**: Lead 는 자동주입을 1차 경로로 신뢰하지 말고, **회수 루프를 백그라운드로 먼저 띄운 뒤(`&`) → 그 다음 `SendMessage`** 한다(순서 중요 — watcher 750ms 선점). `team-lead.json` 을 고빈도(0.3~0.5초)로 직접 read 해 잡는 즉시 `COLLECT` 로 복사, **기대 발신자 전원 모일 때까지 유지**(한 명 잡고 끊지 말 것). turn 경계 누락을 Bash 직접 읽기로 구조적 우회. 상세 절차·근원은 §Lead 직접 회수.

### 폴백
- 위 전제 중 하나라도 불충족(claudex 0.139.0 이하 / Lead=claudex / pane 환경 외부 `DEFT_ENV=none` — orca 는 pane 환경이므로 해당 없음)이면 **MCP 버스**(기존 경로)로 자동 폴백하고 사용자에게 사유 1줄 보고.

### 운영 용례 (복사실행 — 모두 실측 검증)

> Lead=Claude · cmux 환경 기준. `team-id` 는 `session-<8자리…>` 형식. 아래 `<…>` 만 치환해 그대로 실행한다.

**용례 0 — Lead 세션 ID 확인 (team-id 와 혼동 금지)**

```bash
echo "$CLAUDE_CODE_SESSION_ID"   # Lead(현재 Claude Code 세션)의 UUID — 1순위·확실
```

- 보조: 세션 transcript 가 `~/.claude/projects/<cwd 인코딩>/<세션ID>.jsonl` 로 저장되므로, 그 디렉토리의 최근 수정 파일명(확장자 제외)도 현재 세션 ID 다.
- 용도: `claude resume <세션ID>` 로 Lead 세션 자체를 이어가기·transcript 추적.
- ⚠️ **Lead 세션 ID ≠ team-id.** team-id(`session-<…>`)는 용례 1 의 `Agent` spawn 결과(`<name>@session-<id>`)로 얻으며, 팀 materialize 시 **독립 생성**된다. 팀 config 의 `leadSessionId` 조차 Lead 세션 ID 가 아니라 팀 자체 id 다(실측: `leadSessionId=ef9a6040…` ↔ 실제 Lead 세션 `$CLAUDE_CODE_SESSION_ID`=`7fc12b85…`). → team-id 를 Lead 세션 ID 에서 유도하려 하지 말 것.

**용례 1 — 첫 claude 워커가 팀 생성 겸 참가 → claudex 워커 추가**

> 🟠 **orca 모드 (§환경 판정)**: spawn 헬퍼(`deft-claudex-native-spawn`/`deft-claude-native-spawn`)는 **orca 를 자동 분기 지원**한다(ORCA_* 감지 시 `orca terminal split --command` 원샷 기동 — 빈 pane send·lazy-init readiness 문제가 구조적으로 없음, 실측 검증). **호출법은 cmux 와 동일**하되 다음만 다르다:
> - `DEFT_BASE_WORKSPACE` **불요**(orca 는 workspace ref 개념 없음). `DEFT_BUS_DIR`·`DEFT_LEAD_SESSION` 등 나머지 환경변수는 동일.
> - rebalance-guard/`GUARD_FLAG` 발사·touch 전부 skip(Orca resize CLI 미지원 — bin 가드 no-op. pane 비율은 UI 드래그 안내).
> - 상태파일: cmux 의 `.last-worker-pane` 대신 **`.last-worker-terminal`**(orca handle) — 헬퍼가 자동 연쇄(직전 워커 아래 상하 스택). 첫 claude 워커(Agent tool) 아래로 쌓고 싶으면 그 워커의 handle 을 `orca terminal list --worktree active --json` 에서 찾아 `~/.claude/teams/$TID/.last-worker-terminal` 에 심는다(선택 — 안 심으면 첫 헬퍼 워커는 Lead 우측 새 컬럼).
> - 헬퍼 JSON 출력의 **`.terminal`**(orca handle, `term_*`) 을 캡처해 (5) board register 의 `--surface` 로 쓴다 — 버스는 orca 모드에서 `term_*` 핸들을 `orca terminal send` 노크로 처리한다(cmux send 미사용). 깨우기 1차는 여전히 ntpPush(`--inbox`).
> - 첫 claude 워커(Agent tool)는 orca claude-teams 의 tmux shim 이 pane 배치를 자동 처리 — **절차 변경 없음**.
> - 워커 pane 정리는 `orca terminal close --terminal <handle>` (§5-B 🟠).

먼저(cmux 모드), 워커 spawn 을 시작하기 직전 **rebalance-guard 를 백그라운드로 1회 발사** — 이후 모든 워커 spawn 의 cmux 재계산 틀어짐을 자동 교정한다(claude Agent 워커는 spawn ~1.4초 후 Lead 비율을 깎으므로 필수):

```bash
# done-flag 방식: guard 는 플래그가 touch 되기 전엔 시간 무관하게 비율을 지킨다(느린 마지막 워커
#   재계산까지 커버). 마지막 워커 spawn 반환 후 플래그를 touch 하면 그때 마지막 안정 확인 후 종료.
GUARD_FLAG="$SESSION_DIR/.spawn-done"; rm -f "$GUARD_FLAG"
# expected-panes(7번째 인자) = Lead 포함 예정 총 pane = 스폰 확정한 워커 수 + 1. **≥3 이면** 첫 워커(2-pane)
#   단계부터 50:50 → 목표 60:40 으로 미리 당긴다(워커 2명 이상 회의/작업에 필수). 워커 1명뿐이면 EXP=2 → 50:50 유지.
EXP_PANES=$((WORKER_COUNT + 1))   # WORKER_COUNT = 이번 회의/작업에 스폰 확정한 총 워커 수
nohup cmux-rebalance-guard "$DEFT_BASE_WORKSPACE" 90 0.1 50 5 "$GUARD_FLAG" "$EXP_PANES" >/dev/null 2>&1 &
```
> ⚠️ **모든 워커 spawn 이 끝난 직후 반드시 `touch "$GUARD_FLAG"`** — 이게 guard 종료 신호다. 빠뜨리면 guard 가 max-sec(90초)까지 살아있다 종료(잔존은 아니나 늦음). spawn 호출 반환 ≠ pane 재계산 완료라 시간으로 못 끊으므로 플래그가 정확하다.
> ⚠️ **`EXP_PANES` 는 spawn 시작 전에 확정**한다 — Lead 가 띄울 워커 수를 정하는 순간 함께 정하는 값(워커 수 + 1). 워커 2명+ 면 ≥3 이 되어 첫 워커 단계부터 60:40 정렬, 워커 1명이면 2 라 50:50(기본 분할) 유지.

첫 claude 워커 (이 spawn 이 팀을 materialize → 여기서 team-id 를 얻고, 동시에 회의 참가자가 된다):

```
Agent(name:"<회의-역할-이름>", subagent_type:"claude", model:"fable",
      description:"<한 줄>", prompt:"<페르소나 + 회의 참가 + SendMessage 보고 규칙>")
# 반환된 "<name>@session-<id>" 의 session-<id> 가 곧 team-id.
# ⚠️ subagent_type 은 반드시 "claude"(범용) — claude-code-guide·Explore 등 제한 타입은
#    SendMessage 도구가 비활성이라 Lead 에 보고 불가 → 조용한 데드락(실측 사고). 회의 워커는 항상 "claude".
# cmux claude-teams 가 이 pane 을 우측 컬럼에 자동 배치(2컬럼). 멤버·leadSessionId 확인:
#   cat ~/.claude/teams/session-<id>/config.json
```

claudex 워커 추가 전 — 첫 claude 워커 pane 을 헬퍼 상태파일에 심는다 (claudex 가 그 아래로 down):

```bash
TID=session-<id>
# 첫 claude 워커 pane:ref 찾기 (Lead pane 제외, 가장 최근 우측 pane)
WPANE=$(cmux list-panes --workspace "$DEFT_BASE_WORKSPACE" --json \
  | jq -r '.panes|sort_by(.pixel_frame.x)|last|.ref')
echo "$WPANE" > ~/.claude/teams/$TID/.last-worker-pane
```

claudex 워커 (헬퍼로 첫 워커 아래 세로 스택 — `$DEFT_BASE_WORKSPACE` 는 위 `$LEAD_WORKSPACE`):

```bash
HELPER_OUT=$(DEFT_BASE_WORKSPACE="$LEAD_WORKSPACE" DEFT_BUS_DIR="$SESSION_DIR" \
  deft-claudex-native-spawn "$TID" <claudex-name> [cwd])
WSURF_x=$(printf '%s' "$HELPER_OUT" | jq -r '.surface')   # 회의 모드면 (5) register 에 사용
# 헬퍼가 .last-worker-pane(첫 claude 워커) focus → new-split down → 그 아래로.
# 이후 claudex 워커는 .last-worker-pane 자동 연쇄(직전 claudex 아래로).
# 🔑 DEFT_BUS_DIR 설정(회의 모드) → 헬퍼가 --claude-team-agent(이름표·ntpPush) + -c mcp_servers.bus(board)
#    를 함께 박는다 = NTP+버스 2채널 공존(근거: RATIONALE R-16). 작업 모드면 DEFT_BUS_DIR 생략(순수 NTP).
# 팀 config 미등록 이름도 SendMessage 가 그대로 배달하므로 멤버 stub 선등록 불요.
```

추가 claude CLI 워커가 필요하면 (claudex 외에 claude 도 다인 회의에 섞을 때) — 헬퍼로 띄워 binding+board 공존:

```bash
HELPER_OUT=$(DEFT_LEAD_SESSION="$CLAUDE_CODE_SESSION_ID" DEFT_BASE_WORKSPACE="$LEAD_WORKSPACE" DEFT_BUS_DIR="$SESSION_DIR" \
  deft-claude-native-spawn "$TID" <claude-name> "" fable)
WSURF_c=$(printf '%s' "$HELPER_OUT" | jq -r '.surface')
# DEFT_LEAD_SESSION=$CLAUDE_CODE_SESSION_ID 필수 — 없으면 claude 가 parent 를 못 찾아 onboarding 에 갇힘(실측).
# 단, 첫 워커는 항상 Agent tool(팀 생성). 헬퍼 claude 워커는 board 직결되나 자동주입은 불가 → 응답 회수는 board check 경로.
```

**모든 워커 spawn 이 끝나면 — guard 종료 신호 (필수)**:

```bash
# 마지막 워커 spawn 호출이 반환된 직후. guard 가 이 플래그를 보고 마지막 재계산까지 잡은 뒤 종료한다.
touch "$SESSION_DIR/.spawn-done"
```

**회의 모드면 이어서 — board 등록 + 의제 게시 (§Phase 3-A (5))**: 위 spawn 골격(rebalance-guard·첫 워커 Agent·`.last-worker-pane`·헬퍼) 다음에, 헬퍼 워커를 `multi-round-bus register --name <w> --surface "$WSURF_x" --inbox ~/.claude/teams/$TID/inboxes/<w>.json` 로 등록(→ ntpPush) → `post --inject` 로 의제 게시 → `board.jsonl` 생성 확인. 첫 워커(Agent)는 board 미등록 — `SendMessage` 중계 + `team-lead.json` 회수. (작업 모드는 board 없이 SendMessage mesh — Phase 4-T.)

**용례 2 — 기존 claudex 세션을 팀원으로 편입(resume)**

이미 떠서 작업 중인 claudex 세션을 새로 spawn 하지 않고 내 팀에 합류시킨다(대화 맥락 보존):

```bash
claudex --dangerously-bypass-approvals-and-sandbox \
  --claude-team session-<id> --claude-team-agent <name> \
  resume <claudex-session-uuid>
```

- `<claudex-session-uuid>`: 합류시킬 그 claudex 세션의 UUID (claudex `/resume` 목록·세션 파일에서).
- binding 플래그(`--claude-team`/`--claude-team-agent`)를 `resume` 에 함께 주면, 그 세션이 내 팀 inbox 를 watch 하기 시작 → **기존 작업 맥락을 유지한 채** 팀원이 된다.
- ⚠️ `session-<id>` 는 반드시 **내가 materialize 한 그 팀**(용례 1)이어야 한다. 다른 팀 id 로 묶으면 자동주입이 끊기고 직접 파일(team-lead.json) 폴링만 된다.

**용례 3 — NTP 로 메시지 송수신·종료**

```
SendMessage(to:"<name>", summary:"<5~10단어>", message:"<본문>")
# → {success:true, routing:{target:"@<name>"}} 면 inbox 배달 성공.
```

- 팀원 응답은 `<teammate-message>` 로 자동 주입될 수 **있으나** 이를 신뢰하지 말 것 — turn 경계에서 누락돼 유실되는 사고가 잦다(§Lead 직접 회수). **Lead 는 회수 루프를 먼저 띄운 뒤 SendMessage 하고, `team-lead.json` 을 직접 read 해 회수하는 것을 1차 경로로 삼는다.**
- 자동주입(보너스 채널) 전제: 팀원이 **내 현재 팀**(용례 1 의 session-<id>)에 binding 돼 있을 것.

**🚨 Lead 직접 회수 (필수 — NTP 1차 수신 경로. 자동주입은 신뢰 대상 아님)**

**자동주입(`<teammate-message>`)을 1차 수신 경로로 신뢰하지 말 것** — NTP 는 송신·inbox 적재는 견고하나 Lead 자동주입(수신)이 turn 경계에서 구조적으로 누락된다(근거: RATIONALE R-1). Lead 는 워커에 `SendMessage` 한 직후부터 `team-lead.json` 을 **직접 read 하여 회수**한다(자동주입은 보너스 보조 채널). Bash 직접 읽기라 turn delivery phase 와 무관하게 누락을 우회한다.

> 🚨 **순서가 핵심 — "회수 루프 먼저(`&`), SendMessage 나중"** (근거: RATIONALE R-2). 회수를 SendMessage 직후 시작하면 watcher(750ms)가 그 사이 응답을 먼저 비워 놓친다. 반드시 회수 루프를 백그라운드로 **먼저** 띄운 뒤 SendMessage.

**원칙 1 준수 — 회수 루프는 `run_in_background` 로 던지고 메인 턴은 즉시 끝낸다(foreground `wait` 금지).** 회수 스크립트가 끝나면(전원 회수 또는 타임아웃) `*.done` 플래그를 touch 하고, harness 가 그 백그라운드 완료로 **다음 턴**을 깨운다 — 그때 COLLECT 를 읽어 진행한다. 메인은 그 사이 사용자 입력에 반응 가능.

```bash
# 회수 스크립트 (run_in_background:true 로 실행 — 메인 블록 안 함). 인자: LB, COLLECT, EXPECTED_REPLIES.
LB=~/.claude/teams/<team-id>/inboxes/team-lead.json
COLLECT=<SESSION_DIR>/collected.jsonl; : > "$COLLECT"; DONE="$COLLECT.done"; rm -f "$DONE"
EXPECTED_REPLIES=<기대 발신자 수>
for i in $(seq 1 120); do                # ~36초 (필요시 연장)
  if [ -s "$LB" ] && [ "$(jq 'length' "$LB" 2>/dev/null)" -gt 0 ] 2>/dev/null; then
    # idle_notification·shutdown 등 제어 메시지 제외 — 실제 보고 본문만.
    jq -c '.[] | select(.text != null and ((.text|type)=="string") and (.text|contains("idle_notification")|not))' \
      "$LB" 2>/dev/null >> "$COLLECT"
    jq 'map(.read=true)' "$LB" > "$LB.tmp" 2>/dev/null && mv "$LB.tmp" "$LB"
  fi
  # 기대 발신자 전원 모일 때까지 break 금지(한 명 잡고 끊으면 나머지 놓침 — 실측).
  [ "$(jq -r '.from' "$COLLECT" 2>/dev/null | grep -c . )" -ge "$EXPECTED_REPLIES" ] && break
  sleep 0.3
done
touch "$DONE"   # 완료 신호 — harness 가 이 백그라운드 종료로 다음 턴을 깨운다
```

- **실행 순서**: ① 위 스크립트를 **`run_in_background:true` 로 먼저 기동**(watcher 선점 — SendMessage 보다 선행) → ② 같은 턴에서 워커들에게 `SendMessage(to:"<worker>", …)` × N 발송 → ③ **메인 턴 종료**(여기서 `wait`·`sleep` 으로 기다리지 말 것). ④ 백그라운드 완료 알림이 오는 **다음 턴**에 `cat "$COLLECT"` 로 실제 수신본을 읽어 라운드 진행. (자동주입 대화에 안 떠도 COLLECT 가 진실.)

- **적용 범위 — 작업 모드(NTP mesh) + 종료 대기 전용. 회의 모드 라운드 수신엔 쓰지 말 것.**: ① **작업 모드** mate 작업 지시 후 응답 대기 ② mate↔mate 협의 추적 ③ 종료 시 `shutdown_approved` 대기. ⚠️ **회의 모드는 MCP 버스(board)로 동작**하므로 라운드 응답을 이 직접회수로 받지 않는다 — 버스의 `check`/board 로 받는다(이 직접회수를 회의에 쓰면 board 를 우회해 워커 상호 노출이 사라진다 — 실측 회귀).
- **순서·전원 대기가 핵심 (실측 2026-06-25)**: watcher 가 750ms 마다 비우므로 — (a) **회수 루프를 SendMessage 보다 먼저** 띄워야 선점 가능(직후 시작은 수 초 지각해 본문을 뺏긴다), (b) **기대 발신자 전원이 모일 때까지 break 금지**(한 명 잡고 끊으면 그 뒤 도착분 유실). 30초 같은 느린 폴링은 빈 inbox 만 보고 "유실"로 오판한다(claude-2.37.0 의 "느린 폴링 권고"로는 부족했던 이유).
- **자동주입이 우연히 정상이면**: 그 메시지는 inbox 에서 이미 비워져 `COLLECT` 에 안 잡힐 수 있다 — 그건 정상(이미 대화에 떴으므로). 즉 **두 경로(자동주입 / 직접 회수) 중 하나라도 잡으면 수신 성공**, 직접 회수가 누락을 메운다.
- **다른 팀 binding 으로 끊긴 경우**(용례 2 의 잘못된 team-id 등): 자동주입이 아예 안 오므로 이 직접 회수가 **유일** 수신 경로다.
- **작업 모드(§Phase 4-T) 및 종료 대기 전용** — 회의 모드 라운드 수신엔 적용하지 않는다(회의는 버스 board 로 수신).
- 🚨 **종료는 반드시 구조화 `shutdown_request` 메시지로 — 평문 종료 요청 절대 금지 (실측 사고 2026-06-25)**:
  - 종료 신호는 **`SendMessage(to:"<name>", message:{type:"shutdown_request", reason:"<사유>"})`** — `message` 를 **구조화 객체**로 보낸다(평문 문자열 아님).
  - 🚫 **"정리하고 종료해 주세요" 같은 평문 문자열로 종료를 부탁하지 말 것.** 평문은 워커에게 *일반 메시지*로 전달돼 워커가 **보고만 하고 프로세스는 안 내려간다**(실측: Lead 가 평문으로 종료 요청 → claudex 는 종료됐으나 claude 워커는 잔존, 워커가 "shutdown 은 shutdown_response(approve:true)를 받아야 내려간다"며 올바르게 거부). claude 워커(in-process)는 **kill 도 금지**라 구조화 `shutdown_request` 가 **유일한 종료 수단**이다 — 평문으로 보내면 영영 안 죽는다.
- 종료 (워커 종류별 동작 다름 — 실측. **claude 워커는 kill 폴백 절대 금지**):
  - **claudex 워커**(헬퍼 spawn, 외부 프로세스): `SendMessage(to:"<name>", message:{type:"shutdown_request"})` → watcher 가 `shutdown_approved` 후 process::exit → pane 자동 close(즉시·깔끔). 미종료 시 `pkill -f -- "--claude-team-agent <name>"` 폴백 허용(소유 확인 후 — **외부 프로세스라 kill 해도 좀비 핸들 안 생김**).
  - **claude 워커**(Agent tool, in-process): `SendMessage(to:"<name>", message:{type:"shutdown_request", reason:"…"})` → **`shutdown_approved`/`teammate_terminated` 가 자동주입될 때까지 기다린다**(graceful 6초+, 느리면 수십 초). idle_notification 은 "아직 처리 중" 신호일 뿐 — 이걸 "안 죽었다"로 오판하지 말 것. **여러 명이면 shutdown 을 모두 보낸 뒤 한꺼번에 대기**(순차 kill 루프 만들지 말 것). 안 죽었으면 **kill 이 아니라 구조화 `shutdown_request` 를 다시 보낸다**(평문으로 바뀌지 않았는지 점검).
  - 🚫 **claude(Agent tool) 워커에 SIGTERM/`kill`/`pkill` 절대 금지** — in-process 라 kill 이 안 통하고 좀비 핸들(Lead 세션 재시작만이 해법)을 남긴다. 정상 흐름(`shutdown_request`→approved 대기)만 쓰면 좀비 0. (근거: RATIONALE R-5)
  - 정리 시간 단축이 필요하면 — kill 이 아니라 **shutdown 을 일찍·일괄 발송**하고 그 사이 다른 작업(요약·정리)을 진행하며 approved 를 비동기로 받는다.

## 작업 디렉토리 표준 + work-id 연계 (skill 실행 시 사용)

skill 실행 시 사용하는 데이터·세션·hooks는 `~/.claude/plugin-data/deft/multi-round/` 하위에 저장한다.

### work-id 연계 — 기본값

회의는 **기본적으로 특정 작업(work-id)에 연계**된다. work-id 는 `agent-teams` 와 공유하는 **deft 플러그인 공통 영속 키** — 같은 키로 두 skill 의 산출물(작업노트 ↔ 회의록)을 상호 참조한다.

- **work-id 명명 규약**: `~/.claude/plugin-data/deft/config.json` (플러그인 공통). 미설정이면 최초 1회 메뉴로 결정 — 규약 메커니즘·메뉴·변경 절차는 agent-teams SKILL §3-3 과 동일 (어느 skill 이 먼저 실행되든 한 번 정하면 양쪽 공유).
- **work-id 값 확정**: 사용자 입력에서 감지 (예: "IT-14610 격리 수준 토론해줘" → `IT-14610`). 감지 안 되면 1회 질문.
- **독립 토론**: 사용자가 명시적으로 "독립 토론", "work-id 없이", "그냥 토론만" 이라고 밝힌 경우에만 work-id 없이 진행.

```
~/.claude/plugin-data/deft/
├── config.json           # work-id 규약 (deft 공통 — agent-teams 와 공유)
├── CONVENTION.md         # 규약 사람용 명시
└── multi-round/
    ├── README.md             # 작업 디렉토리 용도·정책
    ├── sessions/
    │   ├── <work-id>/                  # 연계 회의 (기본)
    │   │   └── <YYYYMMDD-HHMM-tag>/
    │   │       ├── board.jsonl         # 버스 보드 = 회의록 원본 (전 메시지)
    │   │       ├── participants.json   # 참가자 레지스트리
    │   │       ├── cursors.json        # 읽음 커서
    │   │       ├── knocks.json         # 노크 디바운스 상태
    │   │       ├── summary.md          # Phase 5 종합 결과
    │   │       └── state.sh            # LEAD_SURFACE, W_*_SURFACE 등
    │   └── standalone/                 # 독립 토론 (사용자 명시 시만)
    │       └── <YYYYMMDD-HHMM-tag>/
    ├── state/                # 영구 메타 (cumulative)
    └── hooks/                # skill 동작 훅 (필요 시)
```

skill 실행 시 다음 환경 변수 설정 후 모든 경로 이걸 통해 참조:

```bash
SKILL_BASE="$HOME/.claude/plugin-data/deft/multi-round"
SESSION_TAG="$(date +%Y%m%d-%H%M%S)-<주제slug>"   # 예: 20260610-143052-api-design (초까지 — 충돌 방지)
# 연계 회의 (기본):
SESSION_DIR="$SKILL_BASE/sessions/<work-id>/$SESSION_TAG"
# 독립 토론 (사용자 명시 시만):
# SESSION_DIR="$SKILL_BASE/sessions/standalone/$SESSION_TAG"
mkdir -p "$SESSION_DIR"

# 진행 로그 시작 + 사용자에게 실시간 관찰 경로 안내 (§진행 로그 — 관찰성)
deft-log "$SESSION_DIR" STEP "multi-round 세션 시작 (tag=$SESSION_TAG)"
echo "📋 진행 로그: tail -f $SESSION_DIR/orchestration.log  (다른 터미널/pane 에서 실시간 관찰)"
```

> 🚨 **SESSION_DIR 일관성 — bash 호출 간 셸 변수가 유지 안 된다 (Claude Code Bash 는 매 호출 새 셸).** 그래서 SESSION_DIR 을 **한 번만 정하고**, 이후 모든 bash 호출에서 같은 값을 써야 한다. **공유 고정 임시 파일(`/tmp/.mr_session_dir` 등) 절대 금지** — 이전 세션 값이 잔재해 SESSION_DIR 이 오염된다(실측 사고: 옛 경로가 남아 워커가 엉뚱한 디렉토리를 봄). 올바른 방법: **SESSION_DIR 을 정한 직후 세션 고유 파일에 저장하고, 이후 호출은 그걸 읽는다.** 예:
> ```bash
> # 최초 1회: scratchpad(세션 고유 — /tmp 고정 경로 아님)에 저장
> MR_DIR_FILE="${SCRATCHPAD:-$HOME/.claude/plugin-data/deft/multi-round/.cur}-$$-$(date +%s).path"  # 세션 고유 이름
> echo "$SESSION_DIR" > "$MR_DIR_FILE"
> # 이후 bash 호출: SESSION_DIR=$(cat "$MR_DIR_FILE")   ← 같은 값 재사용 (재계산·고정 /tmp 금지)
> ```
> 또는 SESSION_DIR 을 매 bash 호출 첫 줄에 **리터럴 절대경로로 직접 박아** 쓴다(date 재계산 금지 — 분/초가 바뀌면 다른 경로가 됨). ⚠️ **`mapfile`/`readarray` 는 bash 전용 — 로그인 셸이 zsh 면 깨진다. `while read` 루프나 `$(... | tr)` 로 대체**한다.
```

### agent-teams 작업노트 교차 참조 (연계 회의)

work-id 가 확정되면 회의 시작 전 같은 키의 작업노트를 확인한다:

```
~/.claude/plugin-data/deft/agent-teams/<work-id>/work.md 존재?
  ├─ 있음 → Read → 요건분석·영향도·설계결정·작업계획을 라운드 1 prompt 에
  │         컨텍스트로 inject (워커들이 작업 배경을 알고 토론 시작)
  └─ 없음 → skip (회의만 단독 선행하는 경우 — 정상)
```

회의 종료(Phase 5) 후 합의 결과는 `summary.md` + `board.jsonl` 로 보존된다. 이후 `agent-teams` 가 같은 work-id 로 시작/재개될 때 이 회의록을 읽어 work.md `## 설계 결정` 에 반영한다 (agent-teams SKILL §3-5).

**금지**:
- 시스템 임시 경로(`/tmp/multi-round-session/` 등) 사용 금지 (재부팅 시 손실, 다른 skill과 경계 모호)
- 본업 프로젝트 cwd 안에 세션 파일 생성 금지 (`.gitignore` 누락 시 commit 위험)

## 진행 로그 (관찰성) — deft-log

오케스트레이션(pane 분할·readiness 대기·워커 부팅·페르소나 주입·라운드 진행·정리)은 `cmux send` 로 조용히 진행돼 사용자에게 "지금 무엇을 하는지"가 안 보인다. 특히 워커 셸 **lazy-init 으로 멈추면 무진행 침묵**이 생겨 위험하다 — 사용자가 빈 pane 을 보다 다른 pane 을 건드리면 의도치 않은 명령이 실행될 수 있다(실측 — FOMC 셋업 차단 사례). 이를 막기 위해 **단계마다 진행 로그를 남긴다**.

- **로그 파일**: `$SESSION_DIR/orchestration.log` (`deft-log` 헬퍼가 기록 — Phase 0-F 에서 설치. PATH 에 없으면 `~/.local/bin/deft-log` 절대경로).
- **세션 시작 직후 사용자에게 `tail -f $SESSION_DIR/orchestration.log` 를 안내**한다 (실시간 관찰 경로). 사용자가 별도 pane/터미널에서 이 로그를 보며 진행을 따라갈 수 있다.
- 각 단계 전환 시 `deft-log "$SESSION_DIR" <LEVEL> "<무엇>"` 한 줄을 남긴다. 레벨:
  - `STEP` 단계 진입/전환 · `WAIT` 5초+ 대기 시작(readiness·노크 응답) · `DONE` 대기/단계 해소 · `BLOCKED` 차단(사용자 개입 필요·진행 중단) · `WARN`/`ERROR`.
- **무진행 침묵 금지**: 5초 이상 걸리는 대기(readiness·노크 응답)는 진입 시 `WAIT`, 해소 시 `DONE`, 타임아웃 시 `BLOCKED` 를 반드시 남긴다. `BLOCKED` 는 단순 기록이 아니라 **fail-fast 게이트** — 기록 후 그 단계 진행을 멈추고 사용자에게 보고한다(예: spawn 헬퍼가 pane 쉘 미기동으로 `BLOCKED`/exit 2 반환 시 — lazy-init readiness, 근거: RATIONALE R-11).
- 최근 로그 빠른 확인: `deft-log "$SESSION_DIR" --tail` (기본 20줄).

### 🪟 Lead 출력 레지스터 규약 (대화 화면 ≠ 진행 로그 — 채널 분리)

진행 로그(`orchestration.log`)는 **상세 오케스트레이션 기록 채널**이고, Lead 가 사용자 대화 화면에 출력하는 텍스트는 **별개의 의미 이벤트 채널**이다. 둘을 혼동해 상세 메커니즘을 대화 화면에 중계하지 말 것.

- **대화 화면에는 "의미 이벤트"만 출력한다** — 사용자가 궁금한 것:
  1. **어떤 페르소나(워커)가 소환되는가** (예: "물류·로봇·IT·투자 전문가 4인이 회의를 시작합니다")
  2. **회의/작업의 진행 마일스톤** (예: "라운드 2 진행 중 — 쟁점은 마진 vs 물량")
  3. **중간 결과·합의·최종 결론** (예: "3인 합의: …, 1인 이견: …")
- **대화 화면에 출력 금지 (= orchestration.log 로만)** — 사용자가 알 필요 없는 내부 메커니즘:
  - spawn 헬퍼 호출, `cmux new-split`/`focus-pane`/`send`, rebalance-guard 발사, `.last-worker-pane`·done-flag 등 상태파일, readiness 마커, team-id 문자열, claudex 버전 게이트(`0.142.0 ≥ 0.139.1`), NTP/버스 경로 선택 같은 **전송계층·오케스트레이션 디테일**.
  - 이런 것은 `deft-log` 로 `orchestration.log` 에 남기고, 대화에는 **올리지 않는다**.
- **불가피하게 프로세스를 언급해야 할 때**(예: 사용자 개입이 필요한 `BLOCKED`)는 **사용자 친화적 문구**로 바꾼다 — 내부 식별자·명령어·플래그를 노출하지 말고 "무엇이 필요한지"만 자연어로.
  - ✗ "rebalance-guard 발사 후 첫 claude 워커를 Agent tool 로 spawn, team-id=session-36ffcb20 획득"
  - ✓ "물류 전문가를 회의에 소환합니다." (또는 무출력 — pane UI 가 이미 보여줌)
  - ✗ "워커 pane lazy-init 미기동 — surface 셸 readiness 마커 미생성"
  - ✓ "회의 창이 아직 화면에 안 떠서 워커가 시작되지 못했습니다. cmux 창을 화면 전면으로 활성화해 주세요."
- **근거**: 에이전트 팀/cmux 가 pane 분할·워커 상태 UI 를 이미 시각적으로 제공하므로, 대화 화면 텍스트는 그 UI 가 못 보여주는 **의미**(누가·무엇을·어떤 결과)만 담당한다. 프로세스 실황 중계는 중복이고 일반 사용자(개발자·비개발자 공통)에게 잡음이다(실측 피드백 2026-06-25).

## Workflow

> 🪟 **전 Phase 공통 — Lead 출력 레지스터**: 아래 모든 단계에서 Lead 가 사용자 대화 화면에 출력하는 것은 **의미 이벤트(소환 페르소나·진행 마일스톤·중간/최종 결과)만**이다. spawn 헬퍼·cmux 명령·rebalance·상태파일·team-id·버전 게이트 등 오케스트레이션 디테일은 `orchestration.log` 로만 남기고 대화에 중계하지 않는다(§Lead 출력 레지스터 규약). 아래 절차의 bash·헬퍼 호출은 **실행 지침**이지 사용자에게 읽어줄 대본이 아니다.
>
> ⏳ **전 Phase 공통 — foreground blocking 대기 금지 (버스·NTP 무관)**: Lead 는 워커 응답을 기다릴 때 **긴 `sleep` 루프를 foreground Bash 로 돌리지 말 것.** 그 Bash 가 끝날 때까지 모델 턴이 블록돼, 응답이 도착해도 다음 행동으로 못 넘어가는 무한 대기에 빠진다(실측 — ESC 로 죽여야 재개). 응답 확인은 **짧은 단발 후 턴 종료**(다음 노크/메시지가 다음 턴을 깨움)로, 무응답 감시는 **반드시 `run_in_background`/`&`** 로 한다. 합의 도달 + 워커 전원 대기면 더 기다리지 말고 **종료(Phase 5)로 진행**한다.

### Phase 0: Preflight (참가자 환경 확인)

회의 시작 전 다음을 확인:

```bash
# A. 참가자 CLI 확인 — claude / claudex / codex
HAVE_CLAUDE=0
HAVE_CLAUDEX=0
HAVE_CODEX=0
which claude   >/dev/null 2>&1 && HAVE_CLAUDE=1
which claudex  >/dev/null 2>&1 && HAVE_CLAUDEX=1
which codex    >/dev/null 2>&1 && HAVE_CODEX=1

if [ "$HAVE_CLAUDE" -eq 0 ] && [ "$HAVE_CLAUDEX" -eq 0 ] && [ "$HAVE_CODEX" -eq 0 ]; then
  echo "ABORT: 참가자 CLI(claude / claudex / codex) 중 1개 이상 설치 필요"; exit 1
fi

# 결과별 진행 모드
if   [ "$HAVE_CLAUDE" -eq 1 ] && [ "$HAVE_CLAUDEX" -eq 1 ]; then
  PARTICIPANTS_MODE="mix"      # default — claude + claudex 양쪽 mix
elif [ "$HAVE_CLAUDE" -eq 1 ] && [ "$HAVE_CODEX" -eq 1 ]; then
  PARTICIPANTS_MODE="mix"      # claude + codex mix (claudex 없어도 codex로 대체)
elif [ "$HAVE_CLAUDE" -eq 1 ]; then
  PARTICIPANTS_MODE="claude-only";  echo "WARN: claudex/codex 미설치 — claude만으로 진행"
elif [ "$HAVE_CLAUDEX" -eq 1 ]; then
  PARTICIPANTS_MODE="claudex-only"; echo "WARN: claude 미설치 — claudex만으로 진행"
else
  PARTICIPANTS_MODE="codex-only";   echo "WARN: claude/claudex 미설치 — real codex만으로 진행"
fi
echo "참가자 모드: $PARTICIPANTS_MODE"

# B. deft 헬퍼 동기 (갱신형 — 구버전 잔재 자동 최신화)
# ⚠️ 종전엔 각 헬퍼를 `if ! command -v $H`(없으면 설치)로 깔았는데, ~/.local/bin 에 구버전 잔재가 있으면
#    plugin update 를 해도 영원히 갱신 안 됐다(실측 배포 결함 — PATH 의 ~/.local/bin 이 캐시보다 앞서
#    구버전이 최신 캐시를 가림). → deft-bin-sync 가 "캐시 sort -V tail 최신본 ↔ ~/.local/bin cmp,
#    다르거나 없으면 cp" 로 **항상 최신화**한다. 부트스트랩(자기 자신)은 단순 cp.
DEFT_SYNC_SRC=$(ls -1 ~/.claude/plugins/cache/bluehansl/deft/*/bin/deft-bin-sync 2>/dev/null | sort -V | tail -1)
[ -z "$DEFT_SYNC_SRC" ] && DEFT_SYNC_SRC=$(ls -1 ~/.codex/plugins/cache/bluehansl-codex/deft/*/bin/deft-bin-sync 2>/dev/null | sort -V | tail -1)
if [ -n "$DEFT_SYNC_SRC" ]; then
  mkdir -p ~/.local/bin && cp "$DEFT_SYNC_SRC" ~/.local/bin/deft-bin-sync && chmod +x ~/.local/bin/deft-bin-sync
  deft-bin-sync   # multi-round-bus·cmux-rebalancing·cmux-rebalance-guard·deft-model·deft-log·deft-claudex/claude-native-spawn 등 전체 갱신형 동기
else
  echo "WARN: deft-bin-sync 미발견(구버전 캐시) — 헬퍼 자동 동기 비활성"
fi
# 환경 판정 (§환경 판정 — ⚠️ ORCA 먼저. orca 안에서도 cmux identify 가 성공해 오판되므로 순서 필수)
DEFT_ENV=none
if [ -n "${ORCA_WORKTREE_ID:-}" ] || [ -n "${ORCA_TERMINAL_HANDLE:-}" ]; then
  DEFT_ENV=orca
else
  # cmux CLI gap-fill (deft-cmux-shim → ~/.local/bin/cmux) — cmux 후보 환경에서만 수행
  command -v cmux >/dev/null 2>&1 || deft-bin-sync cmux 2>/dev/null
  command -v cmux >/dev/null 2>&1 && cmux identify >/dev/null 2>&1 && DEFT_ENV=cmux
fi
HAVE_CMUX=$([ "$DEFT_ENV" = "cmux" ] && echo 1 || echo 0)   # 종전 분기 표기 호환용
echo "deft 환경: $DEFT_ENV"

# C. 버스 가용성 판정 — node + multi-round-bus (설치는 B 의 deft-bin-sync 가 이미 처리)
HAVE_BUS=0
if command -v node >/dev/null 2>&1; then
  command -v multi-round-bus >/dev/null 2>&1 && HAVE_BUS=1
else
  echo "WARN: node 미설치 — 메시지 버스 비활성 (send/capture 폴백)"
fi
BUS_BIN=$(command -v multi-round-bus 2>/dev/null)
echo "메시지 버스: $([ "$HAVE_BUS" -eq 1 ] && echo "YES ($BUS_BIN)" || echo NO)"
```

> **헬퍼 설치·갱신은 `deft-bin-sync` 단일 도구로 일원화**(claude-2.34.0~). 종전의 개별 `if ! command -v` 블록(D~G: cmux-rebalancing·cmux-rebalance-guard·deft-model·deft-log·deft-claudex-native-spawn 등)은 **"없으면 설치"라 구버전 잔재를 갱신 못 하던 결함**이 있어 제거했다. `deft-bin-sync` 는 캐시 최신본과 `cmp` 해 다르면 갱신하므로 plugin update 후 항상 최신 헬퍼가 쓰인다. (agent-teams·multi-check 도 동일.)

**핵심**:
- **참가자 CLI**: 어느 쪽이든 Lead 가 될 수 있음. mix 가 default. 한쪽만 있으면 그쪽만으로 진행 (abort 안 함. WARN 후 계속).
- **`DEFT_ENV` + `HAVE_BUS` 조합이 Phase 3 통신 경로를 결정** (§통신 우선순위 매트릭스):
  - `DEFT_ENV=cmux && HAVE_BUS=1` → **Phase 3-A (메시지 버스)** — 기본
  - `DEFT_ENV=orca && HAVE_BUS=1` → **Phase 3-A orca 분기** — board 버스 동일, 워커 기동은 orca terminal(§용례 1 🟠), 깨우기는 ntpPush(inbox) 전용
  - `DEFT_ENV=cmux && HAVE_BUS=0` → Phase 3-B (send/capture 폴백)
  - `DEFT_ENV=orca && HAVE_BUS=0` → Phase 3-B orca 등가 (orca terminal send/read/wait — §Phase 3-B 🟠)
  - `DEFT_ENV=none` → Phase 3-C (claudex MCP conversation) 또는 multi-check 안내
- `~/.local/bin` 이 PATH 에 없으면 `BUS_BIN` 변수로 절대경로 호출.

### Phase 1: work-id + 회의 모드 + 참가자 결정

#### 1-0. work-id 확정 (기본 — 독립 토론 명시 시만 skip)

1. `~/.claude/plugin-data/deft/config.json` 읽기. 미설정이면 최초 1회 규약 메뉴 출력 (agent-teams SKILL §3-3 메커니즘 동일) 후 저장
2. 사용자 입력에서 work-id 감지 (규약 형식 매칭 — 예: 티켓 번호 패턴). 감지 안 되면 1회 질문: "이 회의를 연계할 작업(work-id)을 알려주세요. 독립 토론이면 '독립'이라고 답해 주세요."
3. **사용자가 "독립 토론" 명시** → work-id 없이 `sessions/standalone/` 사용
4. work-id 확정 시 → `agent-teams/<work-id>/work.md` 존재하면 Read → 라운드 1 prompt 컨텍스트로 inject (§작업 디렉토리 표준 참조)

#### 1-0.5. 통신 모드 결정 — 회의 vs 작업 (먼저)

회의 형태를 정하기 전, **통신 모드**(§통신 모드 — 회의 vs 작업)부터 가른다:

1. 트리거로 자동 판정: "회의"/"미팅"/"논의"/"토론" → **회의 모드** / "작업지시"/"작업요청"/"의뢰" → **작업 모드**.
2. 모호하면 1회 확인: "이 작업을 **① 회의(서로 의견 보며 합의)**로 할까요, **② 작업(분담 실행·결과 취합)**으로 할까요?"
3. **작업 모드**면 → §Phase 4-T 진행(회의 형태·board 불요, work.md audit). 아래 1-1 회의 형태 결정은 **건너뛴다**.
4. **회의 모드**면 → 1-1 로 회의 형태(consult/dialogue/...) 결정.

#### 1-1. 회의 형태 (회의 모드일 때만)

1. 사용자 요청에서 의도 추출 — "토론해줘", "분담해서", "합의될 때까지" 등 키워드 매핑
2. 의도 명확하지 않으면 **위 회의 모드 선택 메뉴 (4지선다)** 그대로 출력 + 사용자 입력 1~4 받음
3. 기본값(사용자가 입력 없이 진행 요청): **dialogue**

#### 1-2. 참가자 (Phase 0의 `PARTICIPANTS_MODE` 따라)

- **`mix` (default)**: Lead가 Claude면 worker는 Claudex 우선 / Lead가 Claudex면 worker는 Claude. **양쪽 시각 mix가 multi-round의 핵심 가치**
- **`claude-only`**: Lead + 워커 전원 Claude → **§통신 우선순위 매트릭스의 "전원 Claude" 행 적용** — 팀메이트 기능 1순위 (agent-teams 의 통신 모델 차용. 단 본 skill 의 회의 모드·신호 프로토콜·라운드 정책은 그대로 적용)
- **`claudex-only` / `codex-only`**: 설치된 한쪽만으로 N명 진행 (시각 다양성은 감소하지만 회의 자체는 가능)

#### 1-3. Lead는 누구인가 (양방향 가능)

- **본 skill은 Claude / Claudex 양쪽에서 시작 가능**.
- Claude Code에서 `/multi-round` 또는 트리거로 발동 → Lead = Claude
- Claudex CLI에서 동일 skill 발동 → Lead = Claudex
- **어느 쪽이 Lead든 동작 동일** — Lead 는 버스의 bin CLI 진입점을 Bash 로 호출하고, 워커는 MCP 도구로 같은 버스에 접근.

#### 1-4. 참가자 수 — 기본 3명 (페르소나별)

| 인원 | 조건 |
|---|---|
| **워커 3명 (기본)** | 별도 지정 없으면 항상 3명 — 주제에 맞는 **보완적 페르소나 3개**를 정해 1명씩 배정 |
| 워커 1명 | **사용자가 명시할 때만** (예: "워커 1명으로", "간단히 한 명만") |
| 워커 4명+ | **사용자가 명시할 때만** (예: "5명 띄워") — 인지·pane 분할 부담 고지 후 진행 |

**페르소나 결정 절차 (워커 3명 기본일 때)**:

1. 주제에서 보완적 관점 3개를 도출한다 — 예: 설계 토론이면 `구현(implementation)·운영/사용성(ops/ux)·리스크/검증(risk)`, 기술 선정이면 `성능·유지보수·마이그레이션 비용`, 정책 결정이면 `찬성 강화·반대 강화·중립 종합`.
2. 주제만으로 관점이 **명확하면** 자동 배정하고 사용자에게 1줄 보고 (예: "페르소나: 구현 / 사용성 / 리스크 3인으로 진행").
3. **애매하면 사용자에게 질문** — 후보 페르소나 조합 2~3개를 제시하고 선택받는다 (자동 추측으로 진행하지 않는다).
4. 워커 이름은 `worker<N>-<페르소나slug>` (예: `worker1-impl`, `worker2-ux`, `worker3-risk`). 페르소나 관점은 버스 첫 메시지(agents/ 베이스 페르소나 + 관점 주입)에 명시한다.

**엔진 배정 (mix 기본)**: 가용 엔진을 번갈아 배정해 시각 다양성 확보 — 예: claudex·claude 모두 가용이면 `claudex / claude / claudex`. 단일 엔진만 가용이면 그 엔진으로 3명 (페르소나 차이가 다양성을 보완).

> 워커 2명 이상부터 버스의 진가 — 수신자 아닌 워커도 보드를 보며 자발 발언 가능 (회의실 메타포).

### Phase 2: 통신 계층 확정

> 🚨 **회의 모드 = MCP 버스 강제 (board 보장 가드 — 절대 우회 금지)**: 회의 모드면 claudex 0.139.1+ 가 있어도 어떤 이유로도 **반드시 MCP 버스 경로(Phase 3-A)로 spawn**. NTP 직접회수로 띄우면 board 가 안 생겨 star 로 퇴화한다. 회의 spawn 후 **`board.jsonl` 생성을 반드시 확인**(없으면 BLOCKED + 사용자 보고). 작업 모드만 NTP 우선. (근거: RATIONALE R-7)

Phase 0 결과 + 참가자 구성으로 §통신 우선순위 매트릭스에서 경로 1개를 확정하고 사용자에게 1줄 보고:

```
통신 계층: MCP 버스 (cmux pane 워커 + 브로드캐스트 보드 + 자동 노크)
```

- **MCP 버스 경로**: 사용자 환경 파일(`~/.claude/settings.json`, `~/.codex/config.toml`) 등록이 **불필요** — 버스 MCP 는 워커 spawn 명령에 인라인 주입된다 (Phase 3-A). 영구 등록이 아니므로 환경 파일 자동 write 금지 정책과도 충돌 없음.
- **전원 Claude 구성**: 팀메이트 기능 1순위. 팀 기능 불가 시 MCP 버스로 강등 (claude CLI 워커도 인라인 `--mcp-config` 로 버스 주입 가능).
- 어떤 경로도 불가하면: "현재 환경에선 지속 대화형 회의가 불가합니다. 1-shot 비교가 목적이면 `multi-check` 를 사용해 주세요." 안내 후 **중단** (1-shot 재전송 방식으로 우회하지 않는다).

### Phase 3: 워커 spawn + 버스 초기화

#### 3-A. 메시지 버스 경로 (pane 환경 && `HAVE_BUS=1` — 기본)

> 🟠 **orca 모드 (§환경 판정)**: 이하 (1)~(5)의 bare cmux 호출은 전부 금지(오발사) — ① (1)의 `cmux identify` 캡처(LEAD_SURFACE/LEAD_WORKSPACE) skip. Lead 등록은 (2) 첫 워커 spawn 으로 TID 확보 **후** `--surface "$ORCA_TERMINAL_HANDLE"`(Lead 터미널 핸들 — 버스가 `orca terminal send` 로 노크) + `--inbox ~/.claude/teams/$TID/inboxes/team-lead.json`(ntpPush) 로 한다. 자동주입 유실 대비 무응답 시 `check --as lead` 수동 1회 병행. ② (3) `.last-worker-pane` 기록 skip — orca 는 헬퍼가 `.last-worker-terminal` 로 자동 연쇄(§용례 1 🟠). ③ (4) 헬퍼 호출은 **cmux 와 동일**(orca 자동 분기 — `DEFT_BASE_WORKSPACE` 만 불요). ④ (5-a) 워커 register 는 헬퍼 JSON 의 `.terminal` 핸들을 `--surface` 로 + `--inbox` 병행.

**(1) Lead surface 캡처 + Lead 등록** (cmux 모드)

```bash
LEAD_SURFACE=$(cmux identify 2>/dev/null | jq -r '.caller.surface_ref' 2>/dev/null)
[ -z "$LEAD_SURFACE" ] && LEAD_SURFACE="${CMUX_SURFACE_ID:-}"
# fallback 실패 시 사용자에게 직접 surface id 요청

# 🚨 LEAD_WORKSPACE 런타임 발견 (필수 — 모든 cmux 호출에 동반). 세션 고유값 하드코딩 금지 — cmux identify 로 발견.
#    이게 없으면(또는 동반 안 하면) 다른 워크스페이스에서 스킬 실행 시 --surface ref 해석이 깨져
#    명령이 Lead pane 으로 폴백 입력된다(실측 잠복버그 — touch/CLI 가 워커 pane 이 아니라 Lead 에 들어감).
LEAD_WORKSPACE=$(cmux identify 2>/dev/null | jq -r '.caller.workspace_ref // .focused.workspace_ref // empty' 2>/dev/null)
[ -z "$LEAD_WORKSPACE" ] && LEAD_WORKSPACE="${DEFT_BASE_WORKSPACE:-}"
LEAD_PANE=$(cmux identify 2>/dev/null | jq -r '.caller.pane_ref' 2>/dev/null)

"$BUS_BIN" register --session "$SESSION_DIR" --name lead --kind lead --surface "$LEAD_SURFACE"
deft-log "$SESSION_DIR" STEP "Lead 등록 (surface=$LEAD_SURFACE, ws=$LEAD_WORKSPACE)"
```

Lead 도 레지스트리에 등록한다 — 워커가 post 하면 **Lead pane(Claude Code 입력창)에도 노크가 주입**되어 Lead 턴이 자동 발동된다 (폴링 불필요).

> 🚨 **이하 (2)~(5)에서 Lead 가 직접 치는 모든 cmux 호출(`focus-pane`·`list-panes` 등)과 워커 spawn 헬퍼 호출은 반드시 `$LEAD_WORKSPACE`(헬퍼는 `DEFT_BASE_WORKSPACE`)를 동반한다 (실측 잠복버그 — 2.5.0~2.40.0, 근거: RATIONALE R-8).** caller stale 환경(다른 워크스페이스에서 스킬 실행·resume 후·비대화형)에서 `--surface` 단독 ref 는 해석이 깨져 명령이 **Lead pane 으로 폴백 입력**된다. 헬퍼(`deft-claudex-native-spawn`/`deft-claude-native-spawn`)는 `--workspace` 동반·readiness 가드를 **내장**하므로(spawn 의 pane 분할·send 는 헬퍼 책임), Lead 는 `DEFT_BASE_WORKSPACE` 만 정확히 넘기면 된다. **스킬은 어느 워크스페이스·어느 PC·어느 세션에서나 동작해야 하므로, 워크스페이스는 위 `cmux identify` 런타임 발견값(`$LEAD_WORKSPACE`)만 쓰고 특정 번호를 박지 않는다.**

```bash
DEFT_BASE_WORKSPACE="$LEAD_WORKSPACE"   # 헬퍼에 넘길 워크스페이스 (런타임 발견값 — 하드코딩 금지)
```

> **(2)~(5) 설계 (회의 워커 = NTP binding + board 버스 2채널 공존, 근거: RATIONALE R-16)**: 회의 워커는 **① NTP**(`--claude-team-agent` binding → pane 이름표 `@name` + 노크 ntpPush)와 **② MCP 버스**(board.jsonl 브로드캐스트 — 토론 본문 전원 열람) **두 채널을 동시에** 가져야 한다. 둘 다 갖는 유일한 방법은 **NTP binding 으로 띄우되 `DEFT_BUS_DIR` 를 주입**하는 것 — 헬퍼가 그러면 `--claude-team-agent`(NTP) + 버스 MCP 인라인을 함께 박아 준다. 그래서 (2)~(5)는 **빈 pane + CLI 직접부팅이 아니라**(그건 2.40.0 회귀 — binding 누락으로 이름표·ntpPush 상실) **첫 워커 Agent tool + 나머지 헬퍼(DEFT_BUS_DIR 주입)** 로 띄운다. 아래는 그 절차의 요지이며, **복사실행 가능한 전체 명령은 §운영 용례 1**에 있다(중복 방지 — 용례 1 이 단일 소스). (2)~(5)는 용례 1 의 각 단계가 "왜"인지를 설명한다.

**(2) 첫 워커 = claude `Agent` tool (팀 생성 + 회의 참가 겸임 — H1·H3)**

```
Agent(name:"<회의-역할>", subagent_type:"claude", model:"fable", description:"<한 줄>",
      prompt:"<페르소나 + 회의 참가 + SendMessage 보고 규칙>")
# 반환 "<name>@session-<id>" 의 session-<id> = team-id (TID). 이 값이 team-id 의 유일한 신뢰 출처.
```

- 이 첫 spawn 이 ① 팀 materialize(TID 생성) ② cmux 우측 컬럼 자동 배치 ③ 회의 참가를 **겸한다**(H1 — "팀 생성 전용 placeholder" 금지). `subagent_type` 은 반드시 `"claude"`(제한 타입은 SendMessage 비활성 → 데드락, 근거: RATIONALE R-10).
- **첫 워커는 board MCP 직결 불가**(in-process Agent 라 인라인 MCP 주입 경로가 없음) → board 토론 본문은 **Lead 가 `SendMessage` 로 중계**하고, 응답은 **`team-lead.json` 직접 회수**(아래 (5)·§Lead 직접 회수, 근거: RATIONALE R-1·R-2). 즉 첫 워커는 board participant 로 등록하지 않는다(NTP 경로로만 다룬다).
- spawn 직전 `cmux-rebalance-guard` 를 백그라운드로 1회 발사(done-flag 방식) — 상세는 §용례 1.

**(3) 첫 워커 pane:ref 를 헬퍼 상태파일에 기록 (pane 레이아웃 유지)**

```bash
TID=session-<id>                                  # (2) 의 Agent spawn 결과에서
WPANE=$(cmux list-panes --workspace "$LEAD_WORKSPACE" --json \
  | jq -r '.panes|sort_by(.pixel_frame.x)|last|.ref')   # Lead 제외 최우측 pane = 첫 워커
echo "$WPANE" > ~/.claude/teams/$TID/.last-worker-pane
```

- 헬퍼는 첫 워커가 Agent tool 인 경우 그 pane 을 모르므로(상태파일 미기록), Lead 가 **첫 claudex/claude-CLI 헬퍼 호출 전에** 첫 워커 pane:ref 를 `.last-worker-pane` 에 심는다 → 헬퍼 워커가 그 **아래로 세로 스택**(2컬럼 유지). 이후 헬퍼끼리는 `.last-worker-pane` 자동 연쇄. (이것이 "빈 pane 선분할 레이아웃 유지" 제약을 만족하는 방식 — 새 레이아웃을 설계하지 않는다.)

**(4) 나머지 워커 = 헬퍼 (전부 `DEFT_BUS_DIR` 주입 → 이름표 + board 공존)**

```bash
# claudex 워커 (NTP binding + board 버스 공존) — JSON 한 줄 출력에서 surface 캡처
HELPER_OUT=$(DEFT_BASE_WORKSPACE="$LEAD_WORKSPACE" DEFT_BUS_DIR="$SESSION_DIR" \
  deft-claudex-native-spawn "$TID" <claudex-name> [cwd])
WSURF_claudex=$(printf '%s' "$HELPER_OUT" | jq -r '.surface' 2>/dev/null)   # (5-a) register 에 사용

# 추가 claude CLI 워커 (헬퍼 — onboarding 회피 위해 DEFT_LEAD_SESSION 필수)
HELPER_OUT=$(DEFT_LEAD_SESSION="$CLAUDE_CODE_SESSION_ID" DEFT_BASE_WORKSPACE="$LEAD_WORKSPACE" DEFT_BUS_DIR="$SESSION_DIR" \
  deft-claude-native-spawn "$TID" <claude-name> "" fable)
WSURF_claude=$(printf '%s' "$HELPER_OUT" | jq -r '.surface' 2>/dev/null)
```

- `DEFT_BUS_DIR` 설정 시 헬퍼가 board 버스를 **자동 주입**: claudex → `-c 'mcp_servers.bus={…}'`, claude → `--strict-mcp-config --mcp-config <bus>.json`. 그 결과 워커는 `--claude-team-agent` binding(이름표·ntpPush) + 버스 MCP(board) 를 **동시에** 갖는다.
- 헬퍼는 `--workspace` 동반·pane 분할(첫 워커 아래 down)·readiness 가드·members 등록을 **내부에서** 처리하고, 결과를 **JSON 한 줄**(`{"spawned":..,"surface":"surface:N",..}`)로 출력한다 — Lead 는 위 환경변수만 정확히 주면 되고, `.surface` 를 캡처해 (5-a) register 에 쓴다. (claudex/codex 미설치 시 다음 claude 워커도 헬퍼로 추가; 첫 워커만 Agent tool.)
- ⚠️ **활성 team 디렉토리 `rm` 금지**(근거: RATIONALE R-16) — 런타임이 TID 참조를 잃어 spawn 에러. 상태파일(`.last-worker-pane`)만 갱신한다.

**(5) board 등록 + 의제 게시 + 응답 회수 2경로**

```bash
# (5-a) 헬퍼 워커를 board 에 등록 — --inbox 로 NTP 깨우기(ntpPush) 활성화. --surface 는 워치독 재노크 폴백.
"$BUS_BIN" register --session "$SESSION_DIR" --name <claudex-name> --surface "$WSURF_claudex" \
  --inbox ~/.claude/teams/$TID/inboxes/<claudex-name>.json
"$BUS_BIN" register --session "$SESSION_DIR" --name <claude-name> --surface "$WSURF_claude" \
  --inbox ~/.claude/teams/$TID/inboxes/<claude-name>.json
# (5-b) 의제 게시 → 발신자 제외 전원 노크(헬퍼 워커는 ntpPush, board 전원 공개) → 토론 성립
"$BUS_BIN" post --session "$SESSION_DIR" --from lead --to <worker> --type request --inject \
  --content "<페르소나 본문 + 회의 정보 + 라운드 1 의제>"
```

- 🔑 **`--inbox` 가 ntpPush 의 스위치**(근거: RATIONALE R-16, 버스 178행 `info.inbox ? ntpPush : cmuxKnock`): 헬퍼로 띄운 워커는 `~/.claude/teams/$TID/inboxes/<name>.json` 을 watch 하므로, register 에 그 경로를 `--inbox` 로 주면 노크가 **느린 cmuxKnock 대신 빠른 ntpPush**(팀 inbox 직접 적재 → 워커 턴 자동 주입)로 간다. 이 인자를 빠뜨리면 surface 노크로 폴백(회귀).
- **응답 회수 2경로 (워커 유형별 — 근거: RATIONALE R-1·R-16)**:
  - **헬퍼 워커**(claudex / claude-CLI): board 로 응답 → `"$BUS_BIN" check --session "$SESSION_DIR" --as lead`.
  - **첫 워커**(Agent tool): board MCP 직결 불가 → `SendMessage` 로 의제·후속을 중계하고, 응답은 **`team-lead.json` 직접 회수**(회수 루프를 `&` 로 먼저 띄운 뒤 SendMessage — §Lead 직접 회수).
- board 등록·게시 후 **`board.jsonl` 생성을 반드시 확인**(없으면 BLOCKED + 사용자 보고 — 회의=버스 강제 가드, 근거: RATIONALE R-7).

<details>
<summary>※ 폐기된 경로 — 빈 pane + CLI 직접부팅 (2.40.0~2.42.x 회귀, 참고용)</summary>

2.40.0 에서 회의 워커를 `cmux new-split`(빈 pane) + pane 안에서 `claude --model`/`claudex -m -c mcp_servers.bus` 를 직접 부팅하는 방식으로 단순화했으나 — **`--claude-team-agent` binding 을 빠뜨려** ① pane 이름표(`@name`) 가 사라지고 ② 노크가 ntpPush 대신 cmuxKnock(느림) 으로 폴백하는 **회귀**가 발생했다(근거: RATIONALE R-16). 위 (2)~(5)(헬퍼 기반)가 이를 대체한다. CLI 직접부팅 시 필요했던 cmux send 3대 규약(C-u 클리어·source 파일화·colon 회피, RATIONALE R-15)은 **헬퍼가 send 를 1회로 짧게 처리**하므로 버스 경로에서는 더 이상 Lead 책임이 아니다(헬퍼 내부 관심사).

</details>

#### 3-B. send/capture 폴백 (pane 환경 && `HAVE_BUS=0`)

버스 불가 시 구형 경로 — pane TUI 에 직접 prompt 주입 + 화면 캡처로 응답 수집.

- TUI 기동: `claudex -m gpt-5.5 -c mcp_servers={}` (claudex 없으면 codex, 그것도 없으면 `claude --model "$(deft-model claude 2>/dev/null||echo claude-fable-5)"`)
- prompt 주입 시 **줄바꿈 sanitize 필수**: `PROMPT_SAFE=$(tr '\n' ' ' < file)` 후 `cmux send` + `cmux send-key Enter` (`\n` 은 Enter 로 해석되어 조기 제출됨)
- 긴 prompt 는 `$SESSION_DIR/round<N>-<worker>.md` 저장 후 "Read <경로>" 한 줄만 send
- 응답 감지 2단: ① `capture-pane --scrollback` 에서 `DONE:` 센티넬 grep ② idle-stable 폴링 (20줄 캡처 동일 반복 시 완료 간주, 8초 간격 최대 30회)
- 🟠 **orca 모드 등가 (§환경 판정 대응표)**: pane 생성 `orca terminal split --direction vertical`(=우측 생성 — direction 실측 의미는 대응표 참조) / prompt 주입 `orca terminal send --text "<한 줄>" --enter`(줄바꿈 sanitize 동일 적용) / 응답 감지는 idle-stable 폴링 대신 **`orca terminal wait --for tui-idle --timeout-ms <N>` → `orca terminal read`(`--cursor`/`--limit`) 2단을 권장** — orca 의 tui-idle 판정이 agent CLI idle 을 내장 인식하므로 "20줄 동일 반복" 휴리스틱보다 정확하고 빠르다. 세부 플래그는 `orca skills get orca-cli` 확인.

#### 3-C. pane 환경 외부 (`DEFT_ENV=none`) — claudex MCP conversation

pane 시각화 불가 환경(cmux/orca 어느 쪽도 아님)의 지속 대화 경로 (claudex 가 Claude Code 에 MCP 로 등록되어 있을 때):

```
mcp__claudex__codex(prompt: "<페르소나 + 라운드1>", model: "gpt-5.5", developer-instructions: "<agents/codex-participant.md 본문>")
→ conversationId 저장. 이후 라운드는 mcp__claudex__codex-reply(conversationId, prompt) — stateful 지속 대화 (1-shot 재전송 아님)
```

claudex MCP 미등록·미설치면 multi-check 안내 후 중단.

### Phase 4: 라운드 진행 (버스 기반)

#### 4-A. 기본 루프 — 노크가 턴을 굴린다

```
Lead post(요청, to=워커) ─→ 버스가 전원 노크 ─→ 워커들 check
   ▲                                              │
   │                          수신자 워커: 작업 → post(응답, to=lead)
   │                          비수신 워커: 검토만 (필요 시 자발 post)
   │                                              │
   └── Lead pane 에 "[bus] 메시지 확인" 주입 ←── 버스가 전원 노크
       → Lead check → 종료 조건 판정 → 다음 라운드 post
```

Lead 의 라운드 동작:
```bash
# 노크 수신("[bus] 메시지 확인" 입력이 들어옴) 시 — 새 메시지 회수
"$BUS_BIN" check --session "$SESSION_DIR" --as lead

# 종료 조건 미충족 → 다음 라운드 게시 (다른 워커 의견 요약 + Lead 입장 + 질문)
# 워커 응답에 대한 후속 요청이면 --reply-to <응답 id> 로 연결 (시퀀스 그래프 — 회의록에 ← #N 표기)
"$BUS_BIN" post --session "$SESSION_DIR" --from lead --to "$NEXT_WORKER" --type request --content "..."
```

- **미응답 요청 큐**: check 출력의 `⚠ 미응답 요청` 섹션은 "본인 대상 request 중 reply_to 응답이 없는 것"을 매번 재계산해 반복 노출한다 — 워커가 읽고 빠뜨린 요청도 응답할 때까지 계속 보임 (게시·응답 시점 교차 레이스에 의한 묻힘 방지). Lead 의 check 에도 동일 적용.
```bash
```

- **폴링 불필요 — 워커 응답 post 가 Lead 를 노크로 깨운다.**
- 🚨 **foreground blocking sleep 폴링 절대 금지** (근거: RATIONALE R-6): `for i in $(seq ...); do sleep 30; … done` 같은 foreground 대기 루프를 본체 턴에서 돌리지 말 것 — 모델 턴 전체가 블록돼 무한 대기(ESC 로 죽여야 재개)에 빠진다. **올바른 대기**: ① 응답 확인은 짧은 단발(`check`/inbox read 1회) 후 **턴 종료** → 다음 노크가 다음 턴을 깨운다 ② 무응답 감시는 반드시 `run_in_background`(`&`) ③ "응답 올 때까지 기다린다"를 sleep 으로 구현 금지.
- **종료 데드락 주의**: 모든 워커가 합의(CONSENSUS)·DONE 으로 "Lead 종합 대기" 상태면 **더 이상 워커가 post 하지 않아 Lead 를 깨울 노크가 없다.** 이때 Lead 가 또 응답을 기다리면 영구 대기 → **합의 도달 + 워커 전원 대기면 즉시 Phase 5(종합·종료)로 진행**한다(§4-C 종료 판정). 응답 대기와 종료 판정을 혼동하지 말 것.
- **데드락 워치독 (필수)**: Lead 는 응답을 기다리는 post 직후 워치독을 **백그라운드로** 심는다 — Lead 는 노크로만 깨어나므로, 워커가 막히면(권한 거부·crash·무한 대기) 아무도 post 하지 않아 회의가 조용히 정지하는 구조적 공백을 메운다:

```bash
# run_in_background (또는 `&`) 로 실행 — 종료 자체가 Lead 를 깨우는 신호
"$BUS_BIN" watch --session "$SESSION_DIR" --to "$NEXT_WORKER" --message-id <방금 post 한 id> --timeout 300
# RESPONDED → 정상 (노크와 함께 도착). STALLED → 수신자 무응답: 재노크 자동 1회 + 커서 진단 출력
#   → Lead 는 해당 pane 의 권한 모드·프롬프트 상태를 점검하고 사용자에게 보고
```
- 본문은 길이·줄바꿈 제한 없음 (보드 경유) — 3-B 의 sanitize 패턴은 버스 경로에선 불필요.

#### 4-B. 워커 측 프로토콜 (페르소나에 명시 — agents/*.md)

1. `[bus] 메시지 확인` 입력 수신 → 즉시 `check_messages`
2. 새 메시지 각각에 대해:
   - **수신자 = 본인 (또는 all)** → 작업 수행 → `post_message`(to=요청자, type=response) 로 응답. 마지막 줄 `DONE:` 센티넬
   - **수신자 ≠ 본인** → 컨텍스트로만 검토 (작업 X). 논의에 기여할 내용이 있을 때만 수신자를 지정해 자발 발언 (`type=comment`)
3. 자발 발언은 라운드당 최대 1회 권장 (노이즈 방지)

#### 4-C. 라운드 진행 — 자동 진행 (사용자 질문 X)

**기본 정책**: 회의 종료 조건은 **'스폰된 모든 AI의 합의 (CONSENSUS)' 또는 '사용자 개입'**. Lead는 사용자에게 라운드별 계속/중단 여부를 묻지 않고 **자체적으로 라운드를 계속 진행**.

| 상황 | Lead 동작 |
|---|---|
| 모든 워커 응답에 CONSENSUS 신호 일치 | 회의 종료 → Phase 5 종합 |
| 모든 워커 응답에 CONSENSUS 없음 (DISSENT 등 이견 잔존) | 다음 라운드 prompt 자동 작성 → 진행 |
| max-round (기본 5) 도달 | 회의 종료 → 미합의 항목 명시한 채 Phase 5 종합 |
| 사용자가 라운드 중 메시지 보냄 | 즉시 그 메시지를 반영 (모드 변경, 종료 요청, 의견 추가 등) |

**전제**: Lead는 회의 수행 중에도 사용자 입력을 받을 수 있어야 한다. 사용자가 자발적으로 개입하면 즉시 처리. 노크 입력(`[bus] 메시지 확인`)과 사용자 실제 입력은 문구로 구분한다.

**사용자 명시적 변경만 종료 조건 교체**:
- "max-round 10으로 늘려" → 그 시점부터 max-round=10
- "한쪽이 항복할 때까지" → 모드를 debate로 변경
- "지금 종료해줘" → 즉시 Phase 5 종합

별도 명시 없으면 위 기본 정책 유지.

#### 4-D. 사용자 pane 직접 개입

사용자는 언제든 워커 pane 으로 전환해 직접 대화할 수 있다 (워커 = 살아있는 TUI). 사용자 직접 지시로 워커 입장이 바뀌면 워커가 다음 post 에 반영 — 버스 보드가 단일 진실 소스이므로 Lead 흐름과 충돌하지 않는다.

### Phase 4-T: 작업 모드 진행 (순수 NTP mesh — board 없음)

> 트리거가 "작업지시"/"작업요청"/"의뢰" 면 회의(Phase 3·4) 대신 **작업 모드**로 진행한다. board 브로드캐스트가 없고, 모든 통신이 NTP 점대점(`SendMessage`/`send_message`)이다. 워커 spawn 은 Phase 3-A 와 같되 **board 버스를 주입하지 않는다**.

**(T-1) 워커 spawn — 회의와 같은 하네스, 버스 OFF**

- 첫 claude 워커 `Agent` tool spawn(팀 생성 겸 참가) → claudex 워커 `deft-claudex-native-spawn`(헬퍼 down. 🟠 orca 모드도 헬퍼 그대로 — 자동 분기, `DEFT_BASE_WORKSPACE` 만 불요. §용례 1 🟠). **§NTP 불변 하네스 H1~H4 그대로**(anchor/placeholder 금지).
- ⚠️ 회의와 유일한 차이: 헬퍼에 **`DEFT_BUS_DIR` 를 설정하지 않는다**(board 버스 미주입 = 순수 NTP — cmux/orca 동일). claude 워커는 Agent tool 이라 어차피 버스 없음.
- spawn 시작 시 `cmux-rebalance-guard` 발사(§용례 1 과 동일 — done-flag + expected-panes 방식: `GUARD_FLAG="$SESSION_DIR/.spawn-done"; rm -f "$GUARD_FLAG"; EXP_PANES=$((WORKER_COUNT + 1)); nohup cmux-rebalance-guard "$DEFT_BASE_WORKSPACE" 90 0.1 50 5 "$GUARD_FLAG" "$EXP_PANES" &`). **모든 mate spawn 후 `touch "$GUARD_FLAG"`** 로 guard 종료. (mate 2명+ 면 EXP_PANES≥3 → 첫 워커 단계부터 60:40 정렬.) 🟠 orca 모드는 guard 발사·touch 전부 skip(resize CLI 미지원).

**(T-2) 작업 분배 — Lead↔mate 1:N**

- Lead 가 각 mate 에게 `SendMessage(to:"<mate>", message:"<작업 지시 + 산출 형식 + 보고 규칙>")` 로 **개별 작업 지시**. board 가 없으므로 각자 자기 작업만 본다(회의처럼 전원 공개 아님).
- 작업 지시에 포함: 담당 범위 / 산출물 형식 / **결과는 반드시 통신 도구로 Lead 에 보고**(출력 ≠ 전달 — §보고 채널 원칙. claudex=`send_message(target:"team-lead", message:…)`, claude=`SendMessage(to:"team-lead", …)`) / mate 간 협의가 필요하면 상대 mate 이름으로 직접 보고.

**(T-3) mate↔mate N:N 직접 협의**

- mate 끼리 의존(예: 한 mate 의 산출이 다른 mate 입력)이 있으면 **서로 직접 보고**(claudex=`send_message(target:"<상대 mate>", message:…)`, claude=`SendMessage(to:"<상대 mate>", …)`) — Lead 경유 불요. 헬퍼가 config members 에 등록해 두므로(claudex·claude 모두) 라우팅 성립(미등록이면 조용히 드롭 — 실측).
- Lead 는 mesh 통신에 끼지 않아도 되지만, 진행 상황은 work.md 취합(T-4)으로 추적.

**(T-4) audit — agent-teams `work.md` 재사용 (같은 work-id)**

- 작업 모드 산출은 **agent-teams 와 같은 `work.md`** 에 Lead 단독 취합한다(회의의 `summary.md`/board 대신):
  - 경로: `~/.claude/plugin-data/deft/agent-teams/<work-id>/work.md` (work-id 규약은 deft 공통 config.json — §작업 디렉토리 표준).
  - 있으면 이어쓰기, 없으면 생성(agent-teams SKILL §6-1 템플릿). mate 보고를 Lead 가 `## FRONTEND/BACKEND/...` 또는 작업 항목별로 취합.
- 이로써 작업 모드 회의 결과가 agent-teams 작업노트와 **같은 키로 연속** — 이후 agent-teams 가 같은 work-id 로 이어받을 수 있다.
- **산출물 라우팅**: mate 보고를 **파일 형태의 대외 완성물**(사용자 보고서·타팀 공유 문서·배포 SQL 등)로 낼 때는 agent-teams SKILL §3-4-1 라우팅을 따른다 — work-id 가 티켓(`IT-\d+`)이면 `~/.ai/tickets/<work-id>/`, 프로젝트·OSS 작업이면 해당 repo. work.md 에는 취합 내용과 그 경로 링크만 남긴다(plugin-data 에 완성물 금지).

**(T-5) 진행·종료**

- 라운드 정책: 회의(Phase 4-C)와 동일하게 자동 진행 — mate 보고를 받아 다음 작업 지시 또는 종료 판단. **자동주입 누락 대비 §Lead 직접 회수**(SendMessage 직후 team-lead.json 고빈도 직접 read·COLLECT 보존) 적용.
- 종료: **§종료 규칙 그대로** — claude 워커는 `shutdown_request`→approved 대기(kill 금지), claudex 는 shutdown 후 pkill 폴백. work.md 최종 취합 후 정리.

### Phase 5: 종합 + 정리

#### 5-A. 결과 종합 (Lead 단독)

회의록 원본은 `board.jsonl` 전체. 종합은 `$SESSION_DIR/summary.md` 로 저장 + 사용자 보고:

> **산출물 라우팅 (agent-teams SKILL §3-4-1 과 동일 규칙)**: `board.jsonl`/`summary.md`/`transcript.md` 는 **회의 세션 기록(내부)** — SESSION_DIR 유지. 그러나 회의 결론을 **파일 형태의 대외 완성물**(사용자 보고서·타팀 공유 문서)로 낼 때는 plugin-data 가 아니라 — work-id 가 티켓(`IT-\d+`)이면 `~/.ai/tickets/<work-id>/`, 프로젝트·OSS 작업이면 해당 repo 에 저장하고, summary.md(연계 회의면 work.md)에 그 경로 링크를 남긴다.

```markdown
## Multi-Round Results

### 회의 정보
- 모드: {consult|dialogue|collaborate|debate}
- 참가자: {Claudex(GPT-5.5), Claude(Opus), ...}
- 진행 라운드: {N/M}
- 종료 사유: {CONSENSUS 도달 | max-round | 사용자 조기 종료}
- 회의록 원본: $SESSION_DIR/board.jsonl

### Consensus (합의된 부분)
- ...

### Unresolved (라운드 종료 시 미합의)
- 각 입장 + Lead 판단

### 결론
- 최종 권장안 (Lead 종합)
```

가독 회의록 자동 생성 (Lead 종합 직후 표준 호출 — `$SESSION_DIR/transcript.md` 자동 저장):

```bash
"$BUS_BIN" transcript "$SESSION_DIR"   # 즉석 확인: -o - / 주입문 전문: --full
```

회의록 전문 확인: `"$BUS_BIN" history --session "$SESSION_DIR"` (원본 audit 은 board.jsonl, 가독 파생물은 transcript.md, Lead 종합은 summary.md — 역할 분리)

#### 5-B. 정리 (워커 + pane) — 소유권 안전 (파괴 행위)

> 🟠 **orca 모드 (§환경 판정)**: 이하의 `close-surface`/`tmux kill-pane`/`cmux-rebalancing`/`focus-pane` 은 전부 금지(오발사·resize 미지원). 정리 순서 — ① **shutdown 정상 종료 우선**: 첫 워커(Agent tool)는 `shutdown_request`→approved 대기(동일·kill 금지), 헬퍼 워커(claudex/claude-CLI)는 shutdown 후 미종료 시 `pkill -f -- "--claude-team-agent <name>"` 폴백 허용(외부 프로세스). ② **orphan pane 은 spawn 시 캡처한 orca handle(헬퍼 JSON `.terminal`)로만** `orca terminal close --terminal <handle>` (실측 — ptyKilled 포함. 다른 워크트리/터미널 handle 추측 close 금지). 레이아웃 복원 단계는 없음(resize 미지원).

**소유권 (필수)**: cmux 는 **다중 워크스페이스·다중 세션** 환경이다. **본 회의가 spawn 한 워커만** 정리한다 — 첫 워커(Agent tool)는 `shutdown_request`(§종료 규칙, kill 금지), 헬퍼 워커(claudex/claude-CLI)는 spawn 시 캡처한 surface(`WSURF_*`)로 닫는다. 다른 워크스페이스/세션의 pane·`surface:N` 을 추측으로 닫지 말 것 — **전체 surface 순회·와일드카드 close 금지**.

- 정리 시작: `deft-log "$SESSION_DIR" STEP "회의 종료 — 워커 pane 정리 시작"`.
- 종료 알림 게시: `"$BUS_BIN" post --session "$SESSION_DIR" --from lead --to all --type signal --content "VERDICT: 회의 종료. 참여 감사합니다."` (워커들이 마지막 노크로 종료 인지)
- **첫 워커(Agent tool)**: `SendMessage(to:"<첫워커>", message:{type:"shutdown_request", reason:"…"})` → approved 대기(in-process 라 close-surface·kill 금지 — pane 은 워커 자기종료 시 정리). (근거: RATIONALE R-5)
- **헬퍼 워커 pane(spawn 시 캡처한 `WSURF_*`)만 닫는다**: 먼저 `shutdown_request`(pane auto-close), 미종료 orphan 만 `cmux close-surface --surface "$WSURF_x" --workspace "$LEAD_WORKSPACE"` … (워커 수만큼, `--workspace` 동반). 회의록은 board.jsonl·transcript.md 로 보존되므로 관찰 손실 없음.
- `close-surface` 가 못 닫는 orphan(세션 종료됐는데 pane 잔존)이면 **그 워커 pane 의 tmux id 로만** 직접 닫는다: `tmux kill-pane -t <해당 pane id>` (전체 tmux 순회·다른 세션 pane 절대 금지).
- 닫은 뒤 `cmux-rebalancing` 1회로 레이아웃 복원 + `cmux focus-pane --pane "$LEAD_PANE" "${WS[@]}"` 로 Lead focus 복원(`--workspace` 동반). 완료 후 `deft-log "$SESSION_DIR" DONE "회의 종료·정리 완료"`.
- 버스 MCP 서버 프로세스는 각 워커 TUI 의 자식 — pane 종료 시 함께 정리됨. 잔존 확인: `pgrep -f "multi-round-bus mcp"`
- 3-C 경로의 conversation 은 별도 종료 명령 없음 (다음 사용 시 새 conversationId)

## 보안 가드 요약

| # | 가드 | 위반 시 |
|---|---|---|
| 1 | Phase 0 참가자 CLI 1개 이상 설치 확인 (`claude` / `claudex` / `codex` 중) | abort |
| 2 | 워커 MCP 는 버스만 인라인 주입 (`mcp_servers={bus=...}` / `--strict-mcp-config`) — downstream MCP 차단 | 의도와 다른 MCP 도구 노출 |
| 3 | 사용자 환경 파일(`settings.json`, `config.toml`) 자동 write 금지 — 인라인/세션 파일 주입만 | 사용자 환경 임의 변경 |
| 4 | 3-B 폴백에서만 cmux send 줄바꿈 sanitize (버스 경로는 보드 경유라 불필요) | 조기 제출 / prompt 손상 |
| 5 | claudex/claude/codex 모두 없으면 명시 에러 (silent 실패 X) | 사용자 혼란 |
| 6 | Lead surface 캡처는 `cmux identify` 의 `.caller.surface_ref` 사용 | fallback 미작동 |
| 7 | 1-shot + history 재전송 방식 금지 — 불가 환경은 multi-check 안내 후 중단 | 지속 대화 원칙 위반 |
| 8 | orca 모드에서 cmux CLI 호출 전면 금지 (§환경 판정 — ORCA_* 우선 판정 + bin 가드 이중). `tmux` 는 shim 관할(claude 팀원 pane) 한정 유효 — 그 외 대상엔 무의미 | 별도 cmux 앱 pane 오조작 (조용한 오발사) |

## Error Handling

| 시나리오 | 동작 |
|---|---|
| `claudex` 미설치 + `codex` 있음 | real codex로 graceful fallback + WARN 로그 |
| `claudex` + `codex` 미설치 + `claude`만 있음 | `claude-only` 모드 — 팀메이트 기능 1순위, 불가 시 버스 (claude CLI 워커) |
| `claude` 미설치 + `claudex` 또는 `codex` 있음 | 그 쪽만으로 진행 + WARN |
| 셋 다 미설치 | abort + "참가자 CLI 1개 이상 설치 필요" 보고 |
| node 미설치 또는 버스 헬퍼 없음 (`HAVE_BUS=0`) | Phase 3-B (send/capture) 폴백 + 사유 1줄 보고 (orca 모드는 orca terminal 등가 — §Phase 3-B 🟠) |
| `DEFT_ENV=none` (pane 환경 아님) | Phase 3-C (claudex MCP conversation). 불가 시 multi-check 안내 후 중단 |
| orca 모드에서 cmux 등가가 없는 기능 (pane 비율 조정 등) | 실행하지 않고 명확히 안내 — "Orca 는 resize CLI 미지원, pane 비율은 UI 드래그로 조정" (§환경 판정 대응표) |
| orca 모드에서 rebalance 계열/deft-cmux-shim 이 "orca 모드" no-op/차단 출력 | 정상 가드 동작 — cmux 경로 재시도 금지. spawn 헬퍼·버스 노크는 orca 자동 분기라 차단되지 않는다 |
| 노크 실패 (cmux send 에러) | 버스가 결과에 `failed` 로 보고 — 메시지는 보드에 안전하게 남아 다음 check 때 수신. Lead 는 timeout 시 수동 check |
| 라운드 timeout (기본 300s, 노크 안 옴) | Lead 수동 `check` 1회 + 해당 워커 pane 상태 확인 → 그래도 무응답이면 skip 하고 남은 워커로 종합 |
| 워커가 spawn 직후 사망 (바이너리 경로 오류 등) | 죽은 pane 정리(프로세스 0 확인 후 close-surface) → 재spawn → rebalancing 재호출 |
| 한 워커 BLOCKED | 사용자에게 즉시 보고 + 결정 위임 |
| max-round 도달 (기본 5) | Phase 5 종합 — 미합의 항목 명시 + Lead 권장안 1개 제시 |

## Trigger 라우팅 규칙 (강한 키워드)

| 사용자 입력에 포함된 문구 | 발동 skill |
|---|---|
| **"회의"** / **"미팅"** / "논의" / "토론" | **`multi-round` 회의 모드** — 예: "회의 열어줘", "이 주제로 미팅" |
| **"작업지시"** / **"작업요청"** / **"의뢰"** | **`multi-round` 작업 모드** — 예: "이 분석 작업지시해", "조사 의뢰해줘" (이종 AI 분담 — board 없는 NTP mesh, §Phase 4-T) |
| **"코딩 작업"** | **`agent-teams`** — 예: "IT-14610 코딩 작업 시작", "이거 코딩 작업해줘" |
| "비교" / "교차 검증" | `multi-check` |

> **작업 모드 vs agent-teams 경계**: 둘 다 "분담 실행"이지만 — **"코딩 작업"**(실제 파일 수정·구현·테스트)은 `agent-teams`(전원 claude, 내장 팀). **"작업지시"/"의뢰"**(이종 AI 분담 — 분석·조사·설계·리뷰 등 코드 외 또는 다른 AI 시각이 필요한 작업)는 `multi-round` 작업 모드. 즉 **"코드를 만지면 agent-teams, AI 시각을 섞어 일을 나누면 multi-round 작업 모드"**.
> "작업" 단독은 일상어라 라우팅 안 함 — **"코딩 작업"/"작업지시"/"의뢰"** 조합일 때만. 회의·미팅과 코딩 작업이 **함께** 나오면 (예: "코딩 작업 시작 전에 회의부터") 문맥상 먼저 요구되는 쪽을 발동하고, 이어지는 단계는 work-id 로 연계한다.

`multi-round` 가 매칭되어선 안 되는 어휘 (단독 사용 시):
- "한번 봐줘", "같이 봐줘", "검토해줘" (1발 검토 의도 — multi-check 또는 단독)
- "워커 띄워", "둘이서 얘기해봐" (의도 불명 — 1회 확인)

## 워커 prompt 표준 inject (버스 첫 메시지에 포함)

```
- 응답 언어: 한국어
- **응답 채널: board (post_message) 전용** — '[bus] 메시지 확인' 노크 수신 시 즉시 check_messages → 수신자 본인이면 작업 후 **post_message 로 board 에 응답** / 아니면 검토만 (자발 발언은 기여할 내용 있을 때 1회). 🚨 **claude 워커도 board 에 post 한다 — NTP `SendMessage` 로 Lead 에 보고하지 말 것**(두 채널 보유 시 혼동 금지). board 가 단일 진실 소스라 다른 참가자가 네 입장을 board 에서 봐야 토론 성립.
- **발언 time-box (속도 — 실측 검증)**: 핵심 권장 + 근거 1~3줄로 **간결히**. 회의는 의견·설계 토론이므로 **과도한 web search(수십 회)·장문 분석 금지** — 아는 지식으로 신속히 응답해 라운드 지연을 막는다. (multi-check 의 time-box 와 동일 사상 — claudex/codex 워커가 web search 로 수 분 늘어지면 라운드가 정체됨. 심층 사실확인이 핵심이면 multi-check/deep-research 가 적합)
- 응답 마지막 줄에 'DONE:' 센티넬 (버스 메시지 본문 안에)
- 회의 모드: {consult|dialogue|collaborate|debate}
- 신호 프로토콜 사용 (ACK/STATUS/BLOCKED/DONE + 모드별 확장)
```

## 참가자 페르소나

상세 페르소나는 `agents/` 하위 파일 참조:
- `agents/codex-participant.md` — claudex/codex 워커용
- `agents/claude-participant.md` — claude CLI 워커용 (선택)
