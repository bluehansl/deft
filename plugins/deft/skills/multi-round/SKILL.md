---
name: multi-round
description: '여러 AI(Claude/Claudex/Codex)가 두 통신 모드로 협업하는 멀티턴 skill — ① 회의 모드: N라운드 양방향 토론으로 의견을 좁혀 합의 도달(board 브로드캐스트 + 노크) ② 작업 모드: board 없는 순수 NTP mesh 로 이종 AI 가 일을 분담 실행(Lead↔mate 1:N + mate↔mate N:N, work.md 취합). 강한 트리거 — "회의"/"미팅"/"논의"/"토론" → 회의 모드 (예: "회의 열어줘", "이 주제로 미팅"), "작업지시"/"작업요청"/"의뢰" → 작업 모드 (예: "이 분석 작업지시해", "조사 의뢰해줘"). 그 외 트리거 — "멀티 라운드", "라운드 토론", "AI끼리 토론시켜", "수렴할 때까지 주고받아", "multi round". 단 "코딩 작업"(실제 파일 수정·구현)은 agent-teams, 1발 비교는 multi-check 를 쓰세요.'
---

# Multi-Round Skill

여러 AI가 **여러 라운드에 걸쳐 양방향으로 의견을 주고받는** 토론·합의 도구. **메시지 버스 (브로드캐스트 보드 + cmux 노크)** 로 동작 — 워커는 pane 의 살아있는 TUI 본체(지속 대화), 통신 본문은 버스 보드, 깨우기는 한 줄 노크.

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
| **데이터** | 버스 보드 (`board.jsonl`, MCP 도구 / bin CLI 로 접근) | 본문 전부 — 줄바꿈·마크다운·길이 제한 없음 |
| **제어** | `cmux send` 노크 | `[bus] 메시지 확인` 한 줄만 |

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

| 참가자 구성 | 1순위 | 2순위 | 3순위 |
|---|---|---|---|
| **Lead=Claude + claudex 워커 (claudex 0.139.1+ — 네이티브 binding 지원)** | **NTP — Claude 네이티브 inbox** (Lead 가 `SendMessage` 직접 — §claudex 네이티브 팀원) | **MCP 버스** | send/capture 폴백 |
| **AI mix 또는 전원 claudex/codex** (cmux 환경) | **MCP 버스** (본 아키텍처) | send/capture 폴백 (§Phase 3-B) | `multi-check` 사용 안내 후 중단 |
| **전원 Claude** (Lead + 워커 모두 Claude) | **팀메이트 기능** (Claude 팀 기능 — agent-teams 통신 모델) | MCP 버스 | `multi-check` 사용 안내 후 중단 |
| cmux 외부 환경 | claudex MCP conversation (§Phase 3-C — stateful 지속 대화) | `multi-check` 사용 안내 후 중단 | — |

- **claudex 네이티브 팀원 (claudex 0.139.1+, Lead=Claude)**: claudex 가 Claude 네이티브 팀통신(파일 inbox 프로토콜)을 지원하면, 버스 대신 **Claude 의 `SendMessage` 로 직접** 통신한다(버스/노크 불요, Claude-side 변경 0 — Lead 는 평범한 SendMessage 만 씀). 절차·전제는 §claudex 네이티브 팀원. claudex 가 binding 미지원(0.139.0 이하)이거나 Lead 가 claudex 면 자동으로 **버스로 폴백**.
- 하위 순위로 내려가는 조건: 상위 경로의 전제(버스 스크립트·node·cmux·팀 기능)가 충족되지 않을 때. 내려갈 때마다 사용자에게 사유 1줄 보고.
- **헤드리스 1-shot + 컨텍스트 재전송 방식은 금지** — 멀티라운드는 지속 대화가 본질. 그 형태가 필요한 요구면 `multi-check` 가 올바른 도구이므로 안내 후 중단한다.

## NTP — claudex 네이티브 팀원 (claudex 0.139.1+ — 버스 대신 네이티브 통신)

이 통신 방식을 **NTP(Native Teammate Protocol)**라 한다 — Claude Code 의 파일 inbox 네이티브 팀 통신을 claudex 등 이종 AI 에 이식해, 서로 다른 AI 가 같은 팀 inbox 를 공유하며 `send_message` 로 직접 통신(Lead↔팀원·팀원↔팀원)하는 프로토콜. 버스·MCP·중계 없이 Claude 팀 메커니즘을 네이티브로 재사용한다.

claudex 0.139.1+ 는 Claude Code 의 **네이티브 팀원 통신(파일 inbox 프로토콜)**을 말한다(`--claude-team` / `--claude-team-agent` binding). 이때 claudex 워커를 버스 대신 **Claude 네이티브 팀원**으로 붙여, Lead 가 평범한 `SendMessage` 로 직접 통신한다. **Claude(Lead)는 수정 불필요** — 평범한 SendMessage 만 쓰고, claudex 가 프로토콜을 말함으로써 동작한다(전송계층만 네이티브로 교체, 회의 모드·신호·라운드 정책은 그대로).

### 전제
- **Lead = Claude** (claudex 가 Lead 면 이 경로 불가 → 버스).
- 설치된 claudex 가 **0.139.1+** (binding 지원). 미지원(0.139.0 이하)이면 spawn 후 inbox 무반응 → 버스로 폴백.
- cmux 환경(pane 기동).

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
   - ⚠️ **워커 보고 규칙 (출력 ≠ 전달)**: NTP 워커는 Lead 가 요청한 작업 결과를 — Lead 의 별도 지시가 없는 한 — **반드시 `send_message` 로 보고**한다. 자기 세션에 출력만 하면 Lead 에 전달되지 않는다(실측 사고: 워커가 결과를 세션에 출력만 하고 send_message 미호출 → Lead 미수신). 사용자가 워커 TUI 에 직접 친 것만 출력으로 답한다. (페르소나 `agents/*-participant.md` §보고 채널 원칙)

### 폴백
- 위 전제 중 하나라도 불충족(claudex 0.139.0 이하 / Lead=claudex / cmux 외부)이면 **MCP 버스**(기존 경로)로 자동 폴백하고 사용자에게 사유 1줄 보고.

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

먼저, 워커 spawn 을 시작하기 직전 **rebalance-guard 를 백그라운드로 1회 발사** — 이후 모든 워커 spawn 의 cmux 재계산 틀어짐을 자동 교정한다(claude Agent 워커는 spawn ~1.4초 후 Lead 비율을 깎으므로 필수):

```bash
# 워커 spawn 오케스트레이션 시작 직전 1회. 마지막 spawn 후 5초 무틀어짐이면 스스로 종료(별도 정지 불요).
nohup cmux-rebalance-guard "$DEFT_BASE_WORKSPACE" 90 0.1 50 5 >/dev/null 2>&1 &
```

첫 claude 워커 (이 spawn 이 팀을 materialize → 여기서 team-id 를 얻고, 동시에 회의 참가자가 된다):

```
Agent(name:"<회의-역할-이름>", subagent_type:"claude", model:"opus",
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

claudex 워커 (NTP — 외부 바이너리라 헬퍼로 첫 워커 아래 세로 스택):

```bash
DEFT_BASE_WORKSPACE=workspace:<N> DEFT_BUS_DIR="$SESSION_DIR" \
  deft-claudex-native-spawn session-<id> <claudex-name> [cwd]
# 헬퍼가 .last-worker-pane(첫 claude 워커) focus → new-split down → 그 아래로.
# 이후 claudex 워커는 .last-worker-pane 자동 연쇄(직전 claudex 아래로).
# 팀 config 미등록 이름도 SendMessage 가 그대로 배달하므로 멤버 stub 선등록 불요.
# 추가 claude 워커는 다시 Agent tool 로(자동배치 — 기존 우측 컬럼에 합류, 실측 정합 확인).
```

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

- 팀원 응답은 `<teammate-message>` 로 **자동 주입**된다 — 정상 경로에선 inbox 를 수동 확인하지 않는다.
- 자동주입 전제: 팀원이 **내 현재 팀**(용례 1 의 session-<id>)에 binding 돼 있을 것.

**⚠️ Lead 자동주입 폴백 워치독 (필수 — NTP 수신 간헐 실패 대응)**

NTP 는 **송신은 견고하나 Lead 자동주입(수신)이 간헐 실패**한다(실측 사고: 워커가 `send_message` 로 보고했는데 Lead inbox 에 `read=false` 로 남고 `<teammate-message>` 자동주입이 안 옴 — porter 수신 사고). 그래서 Lead 는 **자동주입에만 의존하지 말고**, 응답을 기다리는 구간에서 **team-lead.json inbox 를 직접 폴링**한다(버스 경로의 `watch` 데드락 워치독과 같은 사상).

```bash
# Lead 가 mate 에 SendMessage 한 뒤 응답을 기다리는데 N초(예: 30s) 자동주입이 없으면 직접 드레인:
LB=~/.claude/teams/<team-id>/inboxes/team-lead.json
# 미읽음(read=false) 메시지 확인 — 자동주입이 누락돼도 여기엔 남아 있다
jq -r '.[] | select(.read==false) | "[\(.from)] \(.text // .summary // .message // "")"' "$LB" 2>/dev/null
# 새 응답이 보이면 그 내용으로 진행하고, 처리한 메시지는 read=true 로 마킹(런타임이 자동주입 시 마킹하나,
#   직접 드레인 시엔 중복 처리를 피하려 본인이 마킹):
jq '(.[] | select(.read==false)) |= (.read=true)' "$LB" > "$LB.tmp" && mv "$LB.tmp" "$LB"
```

- **적용 시점**: ① 회의 라운드/작업 지시 후 응답 대기 ② 종료 시 `shutdown_approved` 대기(자동주입 누락 시 inbox 의 approved 확인). 단 read 마킹 충돌을 피해 **자동주입이 정상이면 폴링하지 않는다**(중복 방지) — "N초 무응답"일 때만 폴백.
- **다른 팀 binding 으로 끊긴 경우**(용례 2 의 잘못된 team-id 등): 자동주입이 아예 안 오므로 이 직접 폴링이 유일 수신 경로가 된다.
- 작업 모드(§Phase 4-T)·회의 모드 공통 — 워커 응답 대기 구간 어디서나 적용.
- 종료 (워커 종류별 동작 다름 — 실측. **claude 워커는 kill 폴백 절대 금지**):
  - **claudex 워커**(헬퍼 spawn, 외부 프로세스): `SendMessage(to:"<name>", message:{type:"shutdown_request"})` → watcher 가 `shutdown_approved` 후 process::exit → pane 자동 close(즉시·깔끔). 미종료 시 `pkill -f -- "--claude-team-agent <name>"` 폴백 허용(소유 확인 후 — **외부 프로세스라 kill 해도 좀비 핸들 안 생김**).
  - **claude 워커**(Agent tool, in-process): `shutdown_request` → **`shutdown_approved`/`teammate_terminated` 가 자동주입될 때까지 기다린다**(graceful 6초+, 느리면 수십 초). idle_notification 은 "아직 처리 중" 신호일 뿐 — 이걸 "안 죽었다"로 오판하지 말 것. **여러 명이면 shutdown 을 모두 보낸 뒤 한꺼번에 대기**(순차 kill 루프 만들지 말 것).
  - 🚫 **claude(Agent tool) 워커에 SIGTERM/`kill`/`pkill` 폴백을 절대 쓰지 말 것** — in-process(별도 PID 없음 — `pgrep` 으로 안 잡힘)라 kill 이 통하지도 않고, 어설픈 kill 은 메인 세션 레지스트리에 **좀비 핸들**(`N teammate started`/`N queued` UI 잔재)을 남긴다. 좀비는 SendMessage·Esc·TaskStop·kill 다 안 먹어 **Lead 세션 재시작만이 유일 해법**이다(실측 사고 — 실험 워커를 SIGTERM 으로 정리하다 10+ 좀비 발생). 정상 흐름(`shutdown_request`→approved 대기)만 쓰면 좀비는 0.
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
SESSION_TAG="$(date +%Y%m%d-%H%M)-<주제slug>"   # 예: 20260610-1430-api-design
# 연계 회의 (기본):
SESSION_DIR="$SKILL_BASE/sessions/<work-id>/$SESSION_TAG"
# 독립 토론 (사용자 명시 시만):
# SESSION_DIR="$SKILL_BASE/sessions/standalone/$SESSION_TAG"
mkdir -p "$SESSION_DIR"

# 진행 로그 시작 + 사용자에게 실시간 관찰 경로 안내 (§진행 로그 — 관찰성)
deft-log "$SESSION_DIR" STEP "multi-round 세션 시작 (tag=$SESSION_TAG)"
echo "📋 진행 로그: tail -f $SESSION_DIR/orchestration.log  (다른 터미널/pane 에서 실시간 관찰)"
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
- **무진행 침묵 금지**: 5초 이상 걸리는 대기(readiness·노크 응답)는 진입 시 `WAIT`, 해소 시 `DONE`, 타임아웃 시 `BLOCKED` 를 반드시 남긴다. `BLOCKED` 는 단순 기록이 아니라 **fail-fast 게이트** — 기록 후 그 단계 진행을 멈추고 사용자에게 보고한다(아래 Phase 3-A (3.5)).
- 최근 로그 빠른 확인: `deft-log "$SESSION_DIR" --tail` (기본 20줄).

## Workflow

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

# B. cmux 환경 검출 — spawn 정책 분기
# B-0. cmux CLI 가 PATH 에 없으면 deft wrapper 를 ~/.local/bin/cmux 로 설치 (조건부 gap-fill).
#   신 cmux(2026-06~)는 `cmux` 를 PATH 바이너리가 아니라 셸 통합 precmd 훅(`_cmux_fix_path`)으로
#   **첫 대화형 프롬프트에만** PATH 에 주입한다 → 비대화형 셸(Bash 도구)엔 `cmux` 부재 → bare cmux 깨짐.
#   wrapper 는 매 호출 env(CMUX_BUNDLED_CLI_PATH 등)→표준경로로 진짜 cmux 를 해석해 exec(신·구·환경 무관).
#   ⚠️ 조건부라 구버전(이름으로 동작)·기존 cmux 는 가리지 않는다(gap-fill, not shadow).
if ! command -v cmux >/dev/null 2>&1; then
  SRC=$(ls -1 ~/.claude/plugins/cache/bluehansl/deft/*/bin/deft-cmux-shim 2>/dev/null | sort -V | tail -1)
  [ -z "$SRC" ] && SRC=$(ls -1 ~/.codex/plugins/cache/bluehansl-codex/deft/*/bin/deft-cmux-shim 2>/dev/null | sort -V | tail -1)
  [ -n "$SRC" ] && mkdir -p ~/.local/bin && cp "$SRC" ~/.local/bin/cmux && chmod +x ~/.local/bin/cmux \
    && echo "INFO: cmux CLI 가 PATH 에 없어 deft wrapper 를 ~/.local/bin/cmux 로 설치 (비대화형 셸 PATH 누락 대응)"
fi
HAVE_CMUX=0
which cmux >/dev/null 2>&1 && cmux identify >/dev/null 2>&1 && HAVE_CMUX=1
echo "cmux 환경: $([ "$HAVE_CMUX" -eq 1 ] && echo YES || echo NO)"

# C. 버스 가용성 — node + multi-round-bus 헬퍼 (미설치 시 plugin 동봉본 자동 설치)
HAVE_BUS=0
if command -v node >/dev/null 2>&1; then
  if ! command -v multi-round-bus >/dev/null 2>&1; then
    SRC=$(ls -1 ~/.claude/plugins/cache/bluehansl/deft/*/bin/multi-round-bus 2>/dev/null | sort -V | tail -1)
    [ -z "$SRC" ] && SRC=$(ls -1 ~/.codex/plugins/cache/bluehansl/deft/*/bin/multi-round-bus 2>/dev/null | sort -V | tail -1)
    if [ -n "$SRC" ]; then
      mkdir -p ~/.local/bin && cp "$SRC" ~/.local/bin/multi-round-bus && chmod +x ~/.local/bin/multi-round-bus
      echo "INFO: multi-round-bus 자동 설치 완료 (~/.local/bin/)"
    fi
  fi
  command -v multi-round-bus >/dev/null 2>&1 && HAVE_BUS=1
else
  echo "WARN: node 미설치 — 메시지 버스 비활성 (send/capture 폴백)"
fi
BUS_BIN=$(command -v multi-round-bus 2>/dev/null)
echo "메시지 버스: $([ "$HAVE_BUS" -eq 1 ] && echo "YES ($BUS_BIN)" || echo NO)"

# D. cmux-rebalancing 헬퍼 설치 확인 — 미설치 시 plugin 동봉본으로 자동 설치
if ! command -v cmux-rebalancing >/dev/null 2>&1; then
  SRC=$(ls -1 ~/.claude/plugins/cache/bluehansl/deft/*/bin/cmux-rebalancing 2>/dev/null | sort -V | tail -1)
  [ -z "$SRC" ] && SRC=$(ls -1 ~/.codex/plugins/cache/bluehansl/deft/*/bin/cmux-rebalancing 2>/dev/null | sort -V | tail -1)
  if [ -n "$SRC" ]; then
    mkdir -p ~/.local/bin && cp "$SRC" ~/.local/bin/cmux-rebalancing && chmod +x ~/.local/bin/cmux-rebalancing
    echo "INFO: cmux-rebalancing 자동 설치 완료 (~/.local/bin/)"
  else
    echo "WARN: cmux-rebalancing 미설치 + plugin 동봉본 없음 — pane 비율 자동 조정 비활성"
  fi
fi

# D-2. cmux-rebalance-guard 설치 — 워커 spawn 중 cmux 재계산으로 Lead 비율이 틀어지는 것을 자동 교정
#   (claude Agent tool 워커는 spawn ~1.4초 후 cmux 가 레이아웃 재계산하며 Lead 를 26%까지 깎는다 — 실측.
#    guard 가 0.1초 폴링으로 틀어짐을 ~1초 내 교정하고 마지막 spawn 후 5초 무틀어짐이면 자동 종료. §Phase 3-A)
if ! command -v cmux-rebalance-guard >/dev/null 2>&1; then
  SRC=$(ls -1 ~/.claude/plugins/cache/bluehansl/deft/*/bin/cmux-rebalance-guard 2>/dev/null | sort -V | tail -1)
  [ -z "$SRC" ] && SRC=$(ls -1 ~/.codex/plugins/cache/bluehansl/deft/*/bin/cmux-rebalance-guard 2>/dev/null | sort -V | tail -1)
  [ -n "$SRC" ] && mkdir -p ~/.local/bin && cp "$SRC" ~/.local/bin/cmux-rebalance-guard && chmod +x ~/.local/bin/cmux-rebalance-guard
fi

# E. deft 공용 모델 ID 헬퍼(deft-model) 설치 — 모델 차단·버전업 시 단일 관리 지점
if ! command -v deft-model >/dev/null 2>&1; then
  SRC=$(ls -1 ~/.claude/plugins/cache/bluehansl/deft/*/bin/deft-model 2>/dev/null | sort -V | tail -1)
  [ -z "$SRC" ] && SRC=$(ls -1 ~/.codex/plugins/cache/bluehansl-codex/deft/*/bin/deft-model 2>/dev/null | sort -V | tail -1)
  [ -n "$SRC" ] && mkdir -p ~/.local/bin && cp "$SRC" ~/.local/bin/deft-model && chmod +x ~/.local/bin/deft-model
fi

# F. deft-log 진행 로그 헬퍼 설치 — 오케스트레이션 단계를 세션 로그로 남겨 사용자 관찰성 확보
#    (무진행 침묵 방지 + readiness 차단 시 BLOCKED 기록 → 사후 추적. §진행 로그 — 관찰성)
if ! command -v deft-log >/dev/null 2>&1; then
  SRC=$(ls -1 ~/.claude/plugins/cache/bluehansl/deft/*/bin/deft-log 2>/dev/null | sort -V | tail -1)
  [ -z "$SRC" ] && SRC=$(ls -1 ~/.codex/plugins/cache/bluehansl-codex/deft/*/bin/deft-log 2>/dev/null | sort -V | tail -1)
  [ -n "$SRC" ] && mkdir -p ~/.local/bin && cp "$SRC" ~/.local/bin/deft-log && chmod +x ~/.local/bin/deft-log
fi

# G. deft-claudex-native-spawn 설치 — claudex(0.139.1+)를 Claude 네이티브 팀원으로 붙이는 헬퍼 (§claudex 네이티브 팀원)
#    Lead=Claude 전용. claudex 가 binding 지원할 때만 네이티브 경로에 사용(미지원/claudex-Lead 면 버스 폴백이라 불요).
if ! command -v deft-claudex-native-spawn >/dev/null 2>&1; then
  SRC=$(ls -1 ~/.claude/plugins/cache/bluehansl/deft/*/bin/deft-claudex-native-spawn 2>/dev/null | sort -V | tail -1)
  [ -n "$SRC" ] && mkdir -p ~/.local/bin && cp "$SRC" ~/.local/bin/deft-claudex-native-spawn && chmod +x ~/.local/bin/deft-claudex-native-spawn
fi
```

**핵심**:
- **참가자 CLI**: 어느 쪽이든 Lead 가 될 수 있음. mix 가 default. 한쪽만 있으면 그쪽만으로 진행 (abort 안 함. WARN 후 계속).
- **`HAVE_CMUX` + `HAVE_BUS` 조합이 Phase 3 통신 경로를 결정** (§통신 우선순위 매트릭스):
  - `HAVE_CMUX=1 && HAVE_BUS=1` → **Phase 3-A (메시지 버스)** — 기본
  - `HAVE_CMUX=1 && HAVE_BUS=0` → Phase 3-B (send/capture 폴백)
  - `HAVE_CMUX=0` → Phase 3-C (claudex MCP conversation) 또는 multi-check 안내
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

Phase 0 결과 + 참가자 구성으로 §통신 우선순위 매트릭스에서 경로 1개를 확정하고 사용자에게 1줄 보고:

```
통신 계층: MCP 버스 (cmux pane 워커 + 브로드캐스트 보드 + 자동 노크)
```

- **MCP 버스 경로**: 사용자 환경 파일(`~/.claude/settings.json`, `~/.codex/config.toml`) 등록이 **불필요** — 버스 MCP 는 워커 spawn 명령에 인라인 주입된다 (Phase 3-A). 영구 등록이 아니므로 환경 파일 자동 write 금지 정책과도 충돌 없음.
- **전원 Claude 구성**: 팀메이트 기능 1순위. 팀 기능 불가 시 MCP 버스로 강등 (claude CLI 워커도 인라인 `--mcp-config` 로 버스 주입 가능).
- 어떤 경로도 불가하면: "현재 환경에선 지속 대화형 회의가 불가합니다. 1-shot 비교가 목적이면 `multi-check` 를 사용해 주세요." 안내 후 **중단** (1-shot 재전송 방식으로 우회하지 않는다).

### Phase 3: 워커 spawn + 버스 초기화

#### 3-A. 메시지 버스 경로 (`HAVE_CMUX=1 && HAVE_BUS=1` — 기본)

**(1) Lead surface 캡처 + Lead 등록**

```bash
LEAD_SURFACE=$(cmux identify 2>/dev/null | jq -r '.caller.surface_ref' 2>/dev/null)
[ -z "$LEAD_SURFACE" ] && LEAD_SURFACE="${CMUX_SURFACE_ID:-}"
# fallback 실패 시 사용자에게 직접 surface id 요청

"$BUS_BIN" register --session "$SESSION_DIR" --name lead --kind lead --surface "$LEAD_SURFACE"
deft-log "$SESSION_DIR" STEP "Lead 등록 (surface=$LEAD_SURFACE)"
```

Lead 도 레지스트리에 등록한다 — 워커가 post 하면 **Lead pane(Claude Code 입력창)에도 노크가 주입**되어 Lead 턴이 자동 발동된다 (폴링 불필요).

**(2) pane 분할 — Option 2 (전체 pane 먼저 분할 → 밸런싱 → 그다음 CLI 부팅)**

multi-round 워커는 `cmux new-split`(빈 pane) + pane 안 CLI 실행 모델이라 **pane 생성과 CLI 부팅을 분리**할 수 있다. 그래서 **모든 워커 pane 을 먼저 분할**(빠름) → 밸런싱(부팅 전에 완료) → 그다음 (3.5)~(5)에서 CLI 부팅·등록한다. "찌부러진 비율" 노출이 최소화된다.

첫 워커는 우측 분할(새 컬럼), 이후 워커는 직전 워커 pane 기준 아래 분할 — **워커 수만큼 반복해 W1..Wn_SURFACE 를 모두 확보**:
```bash
SPLIT=$(cmux new-split right --focus false 2>&1)                          # W1 (우측 새 컬럼)
W1_SURFACE=$(printf '%s' "$SPLIT" | grep -oE 'surface:[0-9]+' | head -1)
SPLIT=$(cmux new-split down --surface "$W1_SURFACE" --focus false 2>&1)   # W2 (W1 아래로)
W2_SURFACE=$(printf '%s' "$SPLIT" | grep -oE 'surface:[0-9]+' | head -1)
# ... Wn 까지 반복 (직전 워커의 W*_SURFACE 아래로). 이 단계에서는 CLI 를 아직 띄우지 않는다(빈 pane 만).
# ⚠️ 플래그는 **--surface** (또는 --panel). `--pane` 은 존재하지 않아 "not_found" 로 분할 실패 → 워커가 컬럼에 안 쌓임. 우측 pane 을 아래로 분할하면 컬럼 비율(60:40)이 유지된다(실측).
# ⚠️ **caller stale 환경(resume 후·비대화형)**: 위 `--surface "$W*_SURFACE"` ref 해석이 "not_found" 로 깨진다.
#    이때는 `--workspace "$LEAD_WORKSPACE"` 컨텍스트를 동반하고, down 대상은 "직전 워커 pane 을
#    cmux focus-pane → new-split down"(focused 기준)으로 우회한다(§cmux 환경 함정 — NTP 헬퍼와 동일 패턴).
#    LEAD_WORKSPACE=$(cmux identify | jq -r '.caller.workspace_ref // .focused.workspace_ref').
deft-log "$SESSION_DIR" STEP "워커 pane 분할 완료 (빈 pane — CLI 부팅 전)"
```

**(3) 전체 분할 확인 후 비율 재조정 (컬럼 + row 한 번에, 1회)**

```bash
# 모든 워커 pane 분할이 끝난 뒤 1회 — 좌 Lead 60% / 우 워커 컬럼 40% + 우측 row 균등화 동시 정렬
deft-log "$SESSION_DIR" STEP "pane 비율 재조정 (Lead 60% / 워커 컬럼 40%)"
command -v cmux-rebalancing >/dev/null 2>&1 && cmux-rebalancing
cmux focus-pane --pane "$(cmux identify | jq -r .caller.pane_ref)" 2>/dev/null   # Lead focus 복원
```

> **Option 2**: 빈 pane 들을 먼저 다 만든 뒤 한 번에 밸런싱하므로 컬럼·row 가 **동시 정렬**되고, 느린 CLI 부팅 전에 레이아웃이 안정된다. (Agent-tool 기반 multi-check/agent-teams 는 pane·AI 가 원자 결합이라 빈 pane 선분할이 불가 → Option 1(첫 spawn 후 밸런싱 → 나머지 spawn)을 쓴다. multi-round 는 분리 가능해 Option 2 적용.) 재spawn(죽은 워커 교체)으로 pane 이 바뀌면 그 직후 다시 호출.
> ⚠️ 첫 호출 누락 시 Lead 가 2:8 처럼 축소되어 가독성 저하.

**(3.5)~(5) — 각 워커 pane 마다 반복** (pane 분할·밸런싱은 (2)~(3)에서 전체 일괄 완료됨. 이제 각 W*_SURFACE 에 대해 readiness→부팅→등록을 수행)

**(3.5) pane 쉘 readiness 확인 (send 유실 가드 — 필수)**

cmux 는 surface 가 **화면에 실제 렌더될 때 쉘을 기동**한다 (lazy-init). 미기동 상태에 send 하면 입력이 조용히 유실되므로, 마커 파일로 쉘 기동을 확인한 뒤에만 본 명령을 보낸다:

```bash
deft-log "$SESSION_DIR" WAIT "$WORKER_NAME pane 쉘 readiness 대기 (최대 15s)"
cmux send --surface "$W1_SURFACE" "touch $SESSION_DIR/.ready-$WORKER_NAME"
cmux send-key --surface "$W1_SURFACE" Enter
for _ in $(seq 1 15); do [ -f "$SESSION_DIR/.ready-$WORKER_NAME" ] && break; sleep 1; done
if [ -f "$SESSION_DIR/.ready-$WORKER_NAME" ]; then
  deft-log "$SESSION_DIR" DONE "$WORKER_NAME pane 쉘 기동 확인 — 부팅 진행"
else
  deft-log "$SESSION_DIR" BLOCKED "$WORKER_NAME pane 쉘 미기동(lazy-init) — cmux 워크스페이스 화면 전면 활성 필요. 부팅 중단."
  echo "BLOCKED: 워커 pane 쉘 미기동 — cmux 창/워크스페이스를 화면 전면으로 활성화해 주세요. 활성 후 알려주시면 readiness 재확인→부팅을 이어갑니다."
  # ⚠️ fail-fast 게이트 (필수): readiness 미확인 상태로 (4) 부팅을 진행하지 말 것 —
  #   미기동 pane 에 send 하면 입력이 조용히 유실되거나, 더 나쁘게는 사용자가 그새 다른 pane 으로
  #   전환했을 때 잘못된 pane 에 명령이 들어갈 수 있다(실측 위험). 그 워커(필요 시 전체 회의)
  #   부팅을 멈추고 사용자 보고 후 대기한다. 무진행 침묵으로 끌지 않는다.
fi
```

**(4) 워커 TUI 기동 — 버스 MCP 인라인 주입**

claudex/codex 워커:

> ⚠️ **codex 워커 업데이트 프롬프트 (실측 — deft-test L4)**: 진짜 `codex`(claudex 아님)는 첫 기동 시 "Update available" 버전 업데이트 프롬프트를 띄워 회의 시작 전 정지할 수 있다 (claudex 는 자체 최신이라 안 뜸). spawn·readiness 확인 후 해당 프롬프트가 감지되면 `cmux send --surface "$SURF" "3"` + `cmux send-key --surface "$SURF" Enter` (3 = skip until next version) 로 넘긴다. 사전에 `codex update` 로 최신화해 두면 예방된다.

```bash
# ⚠️ -c mcp_servers.* 인라인은 기존 등록 서버에 **병합**된다 (교체 아님 — 실측 확인).
#    격리를 위해 사용자 config 의 기존 서버들을 enabled=false 로 명시 비활성.
ENGINE=$([ "$HAVE_CLAUDEX" -eq 1 ] && echo claudex || echo codex)
DISABLE_ARGS=""
for NAME in $("$ENGINE" mcp list --json 2>/dev/null | jq -r '.[].name' 2>/dev/null); do
  DISABLE_ARGS="$DISABLE_ARGS -c mcp_servers.$NAME.enabled=false"
done

WORKER_NAME="worker1"   # 참가자 이름 (페르소나 역할 반영 권장 — 예: backend-claudex)
# --disable tool_call_mcp_elicitation + --dangerously-bypass-approvals-and-sandbox:
#   claudex/codex 는 MCP 도구 영구 신뢰 설정이 없어 (config 후보 키 전수 무효 — 실측) 호출마다 승인 다이얼로그가 뜸.
#   bypass 가 유일한 0회 승인 경로 (인스턴스 한정 — 사용자 config 무변경). 트레이드오프: 해당 워커의 명령 실행 승인·sandbox 도 해제되므로
#   회의 워커(발언 전용) 용도에 한정할 것. 승인 최소화로 충분하면 bypass 를 빼고 첫 호출 시 "Allow for this session" 을 도구당 1회 선택 (회의당 2회).
WORKER_CMD="$ENGINE -m gpt-5.5 --disable tool_call_mcp_elicitation --dangerously-bypass-approvals-and-sandbox $DISABLE_ARGS -c 'mcp_servers.bus={command=\"$BUS_BIN\",args=[\"mcp\"],env={MULTI_ROUND_SESSION_DIR=\"$SESSION_DIR\",BUS_PARTICIPANT=\"$WORKER_NAME\"}}'"
cmux send --surface "$W1_SURFACE" "$WORKER_CMD"
cmux send-key --surface "$W1_SURFACE" Enter
```

claude CLI 워커 (config 파일 방식 — `--strict-mcp-config` 가 기존 MCP 완전 격리):
```bash
cat > "$SESSION_DIR/mcp-$WORKER_NAME.json" <<EOF
{"mcpServers":{"bus":{"type":"stdio","command":"$BUS_BIN","args":["mcp"],"env":{"MULTI_ROUND_SESSION_DIR":"$SESSION_DIR","BUS_PARTICIPANT":"$WORKER_NAME"}}}}
EOF
# --allowedTools: 버스 도구 사전 허용 — 누락 시 don't ask 등 제한 모드에서 post 가 자동 거부되어
#                "수신만 되고 발신 불가" 반쪽 참가자가 됨 (실측 — 회의 데드락의 직접 원인)
# --dangerously-skip-permissions: 승인 프롬프트 0회 (claudex 의 bypass 에 대응 — 회의 워커 한정).
#   --allowedTools 는 skip 미적용 환경 폴백 겸 이중 안전으로 유지.
WORKER_CMD="claude --model "$(deft-model claude 2>/dev/null||echo opus)" --dangerously-skip-permissions --strict-mcp-config --mcp-config $SESSION_DIR/mcp-$WORKER_NAME.json --allowedTools mcp__bus__check_messages,mcp__bus__post_message,mcp__bus__list_participants"
cmux send --surface "$W1_SURFACE" "$WORKER_CMD"
cmux send-key --surface "$W1_SURFACE" Enter
```

- `BUS_PARTICIPANT` 가 워커 MCP 인스턴스에 본인 이름을 고정 — 워커는 도구 호출 시 `from`/`as` 를 생략해도 된다.
- 사용자 환경 파일은 건드리지 않는다 — 모든 오버라이드는 spawn 명령 인라인/세션 파일 주입뿐 (해당 워커 인스턴스에서만 유효).
- E2E 검증: claudex 0.138 기준 버스 MCP handshake(initialize/tools-list)·check_messages·post_message·Lead 노크 수신 전체 사이클 실측 확인.

**(5) 워커 등록 + 페르소나 주입**

```bash
"$BUS_BIN" register --session "$SESSION_DIR" --name "$WORKER_NAME" --surface "$W1_SURFACE"

sleep 3  # TUI readiness
# 페르소나 prompt — 짧게 유지 (상세는 버스 보드의 첫 메시지로 전달하므로)
PERSONA_BOOT="당신은 multi-round 회의 참가자 '$WORKER_NAME' 입니다. 버스 MCP 도구(check_messages/post_message)가 연결되어 있습니다. 지금 check_messages 를 호출해 첫 안내를 읽고 지침을 따르세요. 이후 '[bus] 메시지 확인' 입력을 받으면 항상 check_messages 부터 호출하세요."
cmux send --surface "$W1_SURFACE" "$PERSONA_BOOT"
cmux send-key --surface "$W1_SURFACE" Enter
deft-log "$SESSION_DIR" STEP "$WORKER_NAME 부팅+등록+페르소나 주입 완료"
```

부트 prompt 는 한 줄로 끝낸다 — **상세 페르소나·회의 모드·신호 프로토콜·라운드 1 의제는 Lead 가 버스에 첫 메시지로 게시** (`agents/codex-participant.md` 또는 `agents/claude-participant.md` 본문 + 의제). 줄바꿈 sanitize 걱정 없이 본문 전부 전달된다.

```bash
# 첫 메시지: 페르소나 + 의제 (수신자 = 해당 워커)
"$BUS_BIN" post --session "$SESSION_DIR" --from lead --to "$WORKER_NAME" --type request --inject \
  --content "$(cat <<'EOF'
<agents/ 페르소나 본문>

## 회의 정보
- 모드: dialogue / max-round: 5
- 참가자: lead(Claude), worker1(Claudex), ...

## 라운드 1 의제
<의제 본문>
EOF
)"
```

#### 3-B. send/capture 폴백 (`HAVE_CMUX=1 && HAVE_BUS=0`)

버스 불가 시 구형 경로 — pane TUI 에 직접 prompt 주입 + 화면 캡처로 응답 수집.

- TUI 기동: `claudex -m gpt-5.5 -c mcp_servers={}` (claudex 없으면 codex, 그것도 없으면 `claude --model "$(deft-model claude 2>/dev/null||echo opus)"`)
- prompt 주입 시 **줄바꿈 sanitize 필수**: `PROMPT_SAFE=$(tr '\n' ' ' < file)` 후 `cmux send` + `cmux send-key Enter` (`\n` 은 Enter 로 해석되어 조기 제출됨)
- 긴 prompt 는 `$SESSION_DIR/round<N>-<worker>.md` 저장 후 "Read <경로>" 한 줄만 send
- 응답 감지 2단: ① `capture-pane --scrollback` 에서 `DONE:` 센티넬 grep ② idle-stable 폴링 (20줄 캡처 동일 반복 시 완료 간주, 8초 간격 최대 30회)

#### 3-C. cmux 외부 환경 — claudex MCP conversation

pane 시각화 불가 환경의 지속 대화 경로 (claudex 가 Claude Code 에 MCP 로 등록되어 있을 때):

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

- **폴링 불필요**: 워커 응답 post 가 Lead 를 노크로 깨운다.
- **데드락 워치독 (필수)**: Lead 는 응답을 기다리는 post 직후 워치독을 백그라운드로 심는다 — Lead 는 노크로만 깨어나므로, 워커가 막히면(권한 거부·crash·무한 대기) 아무도 post 하지 않아 회의가 조용히 정지하는 구조적 공백을 메운다:

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

- 첫 claude 워커 `Agent` tool spawn(팀 생성 겸 참가) → claudex 워커 `deft-claudex-native-spawn`(헬퍼 down). **§NTP 불변 하네스 H1~H4 그대로**(anchor/placeholder 금지).
- ⚠️ 회의와 유일한 차이: 헬퍼에 **`DEFT_BUS_DIR` 를 설정하지 않는다**(board 버스 미주입 = 순수 NTP). claude 워커는 Agent tool 이라 어차피 버스 없음.
- spawn 시작 시 `cmux-rebalance-guard` 발사(§Phase 3-A 와 동일 — 레이아웃 자동 교정).

**(T-2) 작업 분배 — Lead↔mate 1:N**

- Lead 가 각 mate 에게 `SendMessage(to:"<mate>", message:"<작업 지시 + 산출 형식 + 보고 규칙>")` 로 **개별 작업 지시**. board 가 없으므로 각자 자기 작업만 본다(회의처럼 전원 공개 아님).
- 작업 지시에 포함: 담당 범위 / 산출물 형식 / **결과는 반드시 `send_message` 로 Lead 에 보고**(출력 ≠ 전달 — §보고 채널 원칙) / mate 간 협의가 필요하면 상대 mate 이름으로 직접 `send_message`.

**(T-3) mate↔mate N:N 직접 협의**

- mate 끼리 의존(예: 한 mate 의 산출이 다른 mate 입력)이 있으면 **서로 직접 `send_message(to:"<상대 mate>")`** — Lead 경유 불요. 헬퍼가 config members 에 등록해 두므로(claudex·claude 모두) 라우팅 성립(미등록이면 조용히 드롭 — 실측).
- Lead 는 mesh 통신에 끼지 않아도 되지만, 진행 상황은 work.md 취합(T-4)으로 추적.

**(T-4) audit — agent-teams `work.md` 재사용 (같은 work-id)**

- 작업 모드 산출은 **agent-teams 와 같은 `work.md`** 에 Lead 단독 취합한다(회의의 `summary.md`/board 대신):
  - 경로: `~/.claude/plugin-data/deft/agent-teams/<work-id>/work.md` (work-id 규약은 deft 공통 config.json — §작업 디렉토리 표준).
  - 있으면 이어쓰기, 없으면 생성(agent-teams SKILL §6-1 템플릿). mate 보고를 Lead 가 `## FRONTEND/BACKEND/...` 또는 작업 항목별로 취합.
- 이로써 작업 모드 회의 결과가 agent-teams 작업노트와 **같은 키로 연속** — 이후 agent-teams 가 같은 work-id 로 이어받을 수 있다.

**(T-5) 진행·종료**

- 라운드 정책: 회의(Phase 4-C)와 동일하게 자동 진행 — mate 보고를 받아 다음 작업 지시 또는 종료 판단. **자동주입 누락 대비 §폴백 워치독**(team-lead.json 직접 폴링) 적용.
- 종료: **§종료 규칙 그대로** — claude 워커는 `shutdown_request`→approved 대기(kill 금지), claudex 는 shutdown 후 pkill 폴백. work.md 최종 취합 후 정리.

### Phase 5: 종합 + 정리

#### 5-A. 결과 종합 (Lead 단독)

회의록 원본은 `board.jsonl` 전체. 종합은 `$SESSION_DIR/summary.md` 로 저장 + 사용자 보고:

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

**소유권 (필수)**: cmux 는 **다중 워크스페이스·다중 세션** 환경이다. **본 회의가 (2)에서 분할해 추적한 `W*_SURFACE`(워커 pane)만** 닫는다. 다른 워크스페이스/세션의 pane·`surface:N` 을 추측으로 닫지 말 것 — **전체 surface 순회·와일드카드 close 금지**.

- 정리 시작: `deft-log "$SESSION_DIR" STEP "회의 종료 — 워커 pane 정리 시작"`.
- 종료 알림 게시: `"$BUS_BIN" post --session "$SESSION_DIR" --from lead --to all --type signal --content "VERDICT: 회의 종료. 참여 감사합니다."` (워커들이 마지막 노크로 종료 인지)
- **본 회의 워커 pane(추적한 `W*_SURFACE`)만 닫는다**: `cmux close-surface --surface "$W1_SURFACE"` … (워커 수만큼). 회의록은 board.jsonl·transcript.md 로 보존되므로 관찰 손실 없음.
- `close-surface` 가 못 닫는 orphan(세션 종료됐는데 pane 잔존)이면 **그 워커 pane 의 tmux id 로만** 직접 닫는다: `tmux kill-pane -t <해당 pane id>` (전체 tmux 순회·다른 세션 pane 절대 금지).
- 닫은 뒤 `cmux-rebalancing` 1회로 레이아웃 복원 + `cmux focus-pane --pane "$(cmux identify | jq -r .caller.pane_ref)"` 로 Lead focus 복원. 완료 후 `deft-log "$SESSION_DIR" DONE "회의 종료·정리 완료"`.
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

## Error Handling

| 시나리오 | 동작 |
|---|---|
| `claudex` 미설치 + `codex` 있음 | real codex로 graceful fallback + WARN 로그 |
| `claudex` + `codex` 미설치 + `claude`만 있음 | `claude-only` 모드 — 팀메이트 기능 1순위, 불가 시 버스 (claude CLI 워커) |
| `claude` 미설치 + `claudex` 또는 `codex` 있음 | 그 쪽만으로 진행 + WARN |
| 셋 다 미설치 | abort + "참가자 CLI 1개 이상 설치 필요" 보고 |
| node 미설치 또는 버스 헬퍼 없음 (`HAVE_BUS=0`) | Phase 3-B (send/capture) 폴백 + 사유 1줄 보고 |
| `HAVE_CMUX=0` | Phase 3-C (claudex MCP conversation). 불가 시 multi-check 안내 후 중단 |
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
- 통신: 버스 MCP 도구만 사용. '[bus] 메시지 확인' 입력 수신 시 즉시 check_messages → 수신자 본인이면 작업 후 post_message 응답 / 아니면 검토만 (자발 발언은 기여할 내용 있을 때 1회)
- **발언 time-box (속도 — 실측 검증)**: 핵심 권장 + 근거 1~3줄로 **간결히**. 회의는 의견·설계 토론이므로 **과도한 web search(수십 회)·장문 분석 금지** — 아는 지식으로 신속히 응답해 라운드 지연을 막는다. (multi-check 의 time-box 와 동일 사상 — claudex/codex 워커가 web search 로 수 분 늘어지면 라운드가 정체됨. 심층 사실확인이 핵심이면 multi-check/deep-research 가 적합)
- 응답 마지막 줄에 'DONE:' 센티넬 (버스 메시지 본문 안에)
- 회의 모드: {consult|dialogue|collaborate|debate}
- 신호 프로토콜 사용 (ACK/STATUS/BLOCKED/DONE + 모드별 확장)
```

## 참가자 페르소나

상세 페르소나는 `agents/` 하위 파일 참조:
- `agents/codex-participant.md` — claudex/codex 워커용
- `agents/claude-participant.md` — claude CLI 워커용 (선택)
