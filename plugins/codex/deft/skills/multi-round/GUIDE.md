# multi-round — 사람용 가이드 (Codex)

> 여러 AI(Codex / Claudex / Claude)가 한 주제에 대해 **N라운드에 걸쳐 양방향으로 의견을 주고받으며 합의에 도달**하는 멀티턴 회의 도구 — Codex 포팅본. cmux 환경에서는 pane 시각화를 우선 사용하고, cmux 외부에서는 claudex MCP 또는 codex 내부 병렬 처리로 동작.

> 본 가이드는 **Codex 측**입니다. Claude Code용은 `plugins/deft/skills/multi-round/GUIDE.md` 를 참고하세요. 워크플로는 동일하지만 경로·MCP 등록 위치·cmux 외부 fallback에 차이가 있습니다.

## 한 줄 컨셉

**AI 회의실** — 여러 AI를 한 회의실에 모아놓고, 모두가 합의할 때까지 의견을 주고받게 한다. 사용자(=회의 의장)는 주제를 던지고, 마지막에 정리된 결론을 받는다.

---

## 목차

1. [Before You Start — 6개 체크박스](#1-before-you-start)
2. [Quick Start — 5분 안에 첫 회의](#2-quick-start)
3. [회의 모드 4종 — 언제 무엇을 쓰나](#3-회의-모드-4종)
4. [도구 선택 기준 — 이 말 하면 이 도구](#4-도구-선택-기준)
5. [동작 원리 — 환경별 양방향 통신](#5-동작-원리)
6. [보안 가드 상세](#6-보안-가드-상세)
7. [트러블슈팅 — 실패 모드 표](#7-트러블슈팅)
8. [FAQ](#8-faq)
9. [Examples — 시나리오별 prompt와 흐름](#9-examples)

---

## 1. Before You Start

회의 시작 전 다음 6개만 확인합니다 (각 1줄):

- [ ] **참가자 CLI 1개 이상 설치** — `claude` 또는 `claudex` 또는 `codex` 중 최소 하나 (`which claude && which claudex && which codex`)
- [ ] **mix 가능 여부 확인** — claude + claudex(또는 codex) 양쪽이면 mix가 default. 한쪽만이면 그 쪽만으로 진행
- [ ] **cmux 환경 여부 확인** — cmux 안이면 pane 경로(Phase 3-B)가 우선. cmux 외부에서만 claudex MCP(Phase 3-A) 또는 codex 내부 fallback(Phase 3-C) 사용
- [ ] **claudex MCP 등록** (cmux 외부 + Lead가 Codex일 때) — `~/.codex/config.toml`의 `[mcp_servers.claudex]` 등록 확인. claudex 미설치/미등록이면 codex 내부 fallback(Phase 3-C)로 자동 전환
- [ ] **회의 모드 결정 의도 정리** — 4지선다 메뉴 보고 고를지, 명시적으로 "토론해줘"·"분담해서" 등 키워드로 줄지
- [ ] **종료 조건 결정** — 기본 "모든 AI 합의"로 자동 진행. 다른 조건 원하면 "max-round=10" / "한쪽 항복까지" 등 명시
- [ ] **work-id 연계 확인** — 회의는 기본적으로 작업(work-id)에 연계됨. 입력에 티켓 번호 등이 있으면 자동 감지, 없으면 1회 질문. **독립 토론을 원하면 "독립 토론"이라고 명시**. work-id 규약 미설정이면 최초 1회 메뉴로 결정 (Claude 측 agent-teams 와 공유 — Claude 측에서 이미 결정했으면 그 규약 재사용)
- [ ] **`cmux-rebalancing` 헬퍼** — PATH 에 있는지 확인. 없으면 skill 첫 실행 시 plugin 동봉본이 `~/.local/bin/` 으로 자동 설치됨. 워커 spawn 후 Lead/워커 pane 비율 재조정에 사용 (cmux 환경 한정)

### 작업 디렉토리

skill 실행 시 사용하는 세션·메타·hooks는 모두 **`~/.codex/plugin-data/deft/multi-round/` 하위**에 저장됩니다.

회의는 **기본적으로 작업(work-id)에 연계**됩니다 — 같은 키로 Claude 측 agent-teams 작업노트와 회의록을 상호 참조합니다. 독립 토론은 사용자가 명시할 때만.

```
~/.codex/plugin-data/deft/
├── config.json                              # work-id 규약 (deft 공통)
└── multi-round/
    ├── sessions/<work-id>/<YYYYMMDD-HHMM-tag>/    # 연계 회의 (기본)
    ├── sessions/standalone/<YYYYMMDD-HHMM-tag>/   # 독립 토론 (명시 시만)
    ├── state/                                     # 영구 메타
    └── hooks/                                     # 동작 훅 (필요 시)
```

---

## 2. Quick Start

### 2-1. 가장 짧은 시작 — 1줄

```
멀티 라운드로 결제 트랜잭션 격리 수준 어떻게 할지 토론해줘
```

→ Lead가 자동으로:
1. preflight 확인
2. 회의 모드 추출 ("토론" → dialogue)
3. 참가자 결정 (claude + claudex mix가 default)
4. 라운드 1 시작 → 합의 도달까지 자동 진행
5. 합의된 결론 Lead가 종합해서 보고

### 2-2. 5단계 흐름

| 단계 | 사용자 동작 | Lead 동작 |
|---|---|---|
| 1 | "X 주제 멀티 라운드로 논의해줘" 입력 | preflight 자동 검사. 환경 OK면 진행 |
| 2 | (필요 시) 회의 모드 메뉴에서 1~4 선택 | 4지선다 출력 — 1.consult 2.dialogue 3.collaborate 4.debate |
| 3 | (자동 진행 — 사용자 개입 X) | 양쪽 mix 워커 spawn → 라운드 1 prompt 전달 |
| 4 | (회의 진행 중) 원하면 의견 추가 메시지 가능 | 라운드별 응답 수렴 → CONSENSUS 도달까지 자동 반복 |
| 5 | 결론 받음 | Phase 5 종합 — 합의된 결정 / 미합의 항목 / Lead 권장안 보고 |

### 2-3. 사용자가 회의 중 끼어들 수 있는가

**예** — Lead는 회의 수행 중에도 사용자 입력을 받습니다. 다음과 같이 개입 가능:

- "지금 종료해줘" → 즉시 Phase 5 종합
- "max-round 10으로 늘려" → 라운드 한도 변경
- "한쪽이 항복할 때까지" → 모드를 debate로 변경
- "GPT 입장에 무게를 더 둬" → 다음 라운드 prompt에 반영
- "사용자 의견 추가: X도 고려해" → 다음 라운드 양 워커에 inject

별도 명시 없으면 **기본 정책 (모든 AI 합의까지 자동 진행)** 유지.

---

## 3. 회의 모드 4종

회의 모드가 사용자 입력에서 명확하지 않으면 다음 메뉴가 그대로 출력됩니다:

```
회의 형태를 골라 주세요:
  1. consult     — 단발 자문. 한 번 답변 받고 종료. 빠른 사실 확인용
  2. dialogue    — 양방향 토론. 의견 좁혀 합의 도달까지 N라운드 주고받기 (기본 추천)
  3. collaborate — 분담 협업. 작업을 둘로 나눠 각자 진행하고 상호 리뷰
  4. debate      — 반박 토론. 강한 검증, 한쪽이 항복할 때까지

번호 입력 (기본 2):
```

각 모드 상세:

### 3-1. `consult` — 단발 자문 (1라운드)

- **종료 조건**: 첫 응답 1회 + `DONE:` 센티넬
- **언제**: 빠른 사실 확인. 단일 답변이 필요한 경우 (예: "이 API의 권장 timeout 값?")
- **multi-check와 차이**: consult는 1명 또는 mix 1명씩 — 답을 좁히는 게 아니라 단발 자문

### 3-2. `dialogue` — 양방향 토론 (기본 추천)

- **종료 조건**: `CONSENSUS` 양쪽 일치 또는 max-round (기본 5) 도달
- **언제**: 의견 갈리는 결정. 합의 형성이 목적 (예: "트랜잭션 격리 수준 어떻게?")
- **신호**: `ACK / STATUS / DONE / AGREED / DISSENT / CONSENSUS`
- **흐름**: 라운드 1 입장 → 라운드 2 서로 검토·조정 → ... → CONSENSUS 일치 → 종료

### 3-3. `collaborate` — 분담 협업

- **종료 조건**: 양쪽 `REVIEW_PASS` 교차
- **언제**: 작업을 둘로 나눠서 각자 진행 후 상호 리뷰가 필요한 경우
- **신호**: `DISTRIBUTE → STATUS → DONE → REVIEW_PASS / REVIEW_FAIL`
- **흐름**: (1) DISTRIBUTE 분배 합의 → (2) 각자 분담 작업 → (3) 상대 결과 리뷰 → 양쪽 REVIEW_PASS → 종료

### 3-4. `debate` — 반박 토론

- **종료 조건**: 한쪽 `CONCEDE` 또는 max-round 도달
- **언제**: 강한 검증·반박. 한쪽 입장이 결국 맞다는 결론이 필요 (예: "PostgreSQL vs MongoDB — 우리 케이스에 진짜 뭐?")
- **신호**: `ACK / STATUS / DONE / DISSENT / CONCEDE`
- **흐름**: 라운드 1 양쪽 입장 → 라운드 2~N 강하게 반박 → 한쪽 CONCEDE → 종료

---

## 4. 도구 선택 기준

같은 deft 플러그인의 3개 도구 (multi-check / multi-round / Agent Teams)를 헷갈리지 않게 구분.

### 4-1. 비교 매트릭스

| 항목 | `multi-check` | **`multi-round`** | Agent Teams (Claude 내장) |
|---|---|---|---|
| 통신 방식 | **1회성** fan-out (응답 비교) | **지속 N라운드** 양방향 | 지속 multi-turn |
| AI 조합 | Codex / Claude / Gemini 동시 | **Claude + Claudex mix** (또는 Codex/Claude) | **Claude끼리만** |
| 의존성·기반 | CLI 직접 호출 (MCP 무관) | cmux pane 또는 MCP/codex 내부 병렬 | Claude 팀 기능 베이스, MCP 불필요 |
| 종료 | 1라운드 답변 비교 | 합의 또는 사용자 개입 | 작업 완료 |
| 결과물 | 답변 비교 표 | 합의된 결정 | 코드·파일·PR |
| 무거움 | 가벼움 | 중간 | 무거움 |

### 4-2. 사용자 입력 → 발동 도구 (예시 매핑)

| 사용자가 이렇게 말하면 | 발동 도구 | 이유 |
|---|---|---|
| "GPT랑 Claude 답 비교해" | `multi-check` | 1회성 비교 의도 |
| "한 번 물어보고 답 모아" | `multi-check` | 동일 |
| "**멀티 라운드로** 백엔드 로직 어떻게 짤지 논의해줘" | `multi-round` | 명시적 트리거 |
| "결제 트랜잭션 격리 수준 두 AI랑 토론해서 정해" | `multi-round` | 합의 도달 의도 |
| "REST vs GraphQL — Claude랑 Codex 의견 좁혀줘" | `multi-round` | 양방향 좁히기 |
| "AI끼리 합의될 때까지 주고받아" | `multi-round` | 합의 종료 조건 명시 |
| "두 명한테 분담시켜서 한쪽 결과 다른 쪽이 리뷰" | `multi-round` (collaborate) | 분담·상호 리뷰 |
| "한쪽 의견이 맞다고 결론날 때까지 반박" | `multi-round` (debate) | 반박 토론 |
| "기능 X 만들어 — backend / frontend / qa 셋 만들어 분담" | Agent Teams | 코드 분담·파일 작업 |
| "이 PR 두 명 시각으로 사인오프받아" | Agent Teams (`review-fix-signoff-loop`) | 사인오프 루프 |

### 4-3. 판단 키워드 한 줄

- **답이 하나면** → `multi-check`
- **답을 좁혀가야 하면** → `multi-round`
- **코드를 만져야 하면** → Agent Teams

---

## 5. 동작 원리

### 5-1. 통신 구조 (핵심)

```
[Lead (Claude 또는 Claudex)]
            │
            ▼
   ┌──────────────────┐
   │   claudex가 띄운  │
   │   mcp-server      │  ← 3-A 경로에서 사용
   │   (stdio)         │
   └──────────────────┘
        │         │
        ▼         ▼
   [Worker A] [Worker B]
   (Claude 또는 Claudex/Codex 인스턴스 — mix가 default)
```

- 3-A 경로는 `claudex mcp-server` 등록이 있을 때만 사용한다.
- `claudex` 미설치(codex-only) 환경에서는 3-A를 쓰지 않고 3-B 또는 3-C로 진행한다.
- cmux 환경에서는 MCP 등록 여부와 무관하게 pane 시각화(3-B)가 기본이다.

### 5-2. 라운드 진행 자동화

```
[라운드 1]
   Lead → 양 워커에 동시 prompt
   각 워커: 본인 입장 응답 → DONE 센티넬

[라운드 2]
   Lead가 라운드 1 결과 분석
      ↓
   CONSENSUS 일치? → 종료 (Phase 5 종합)
      ↓ 아니면
   서로의 입장을 다른 쪽에 전달하는 prompt 자동 작성 → 양 워커
      ↓ 응답 → DONE

[라운드 N]
   같은 과정 반복

[종료]
   합의 도달 / max-round 도달 / 사용자 종료 요청
```

**Lead는 사용자에게 라운드별로 묻지 않습니다** — 합의 도달까지 자동 진행. 사용자가 자발적으로 메시지를 보내면 즉시 그 시점부터 반영.

### 5-3. 세 가지 통신 경로 (환경별)

| 경로 | 동작 | 적용 조건 | 장단점 |
|---|---|---|---|
| **Phase 3-A. MCP 경유** | Lead가 `claudex.codex` / `codex-reply` 도구로 워커 호출. session ID로 워커별 conversation 분리 | **cmux 외부** + claudex MCP 등록 | stateful. 단 pane 시각화 없음 |
| **Phase 3-B. cmux pane + claudex/codex TUI** | cmux로 우측·아래 pane 분할 → 각 pane에 `claudex`(우선) 또는 `codex` TUI 기동 → cmux send/capture로 양방향 | **cmux 환경 내부 기본값** | 사용자가 pane으로 진행 관찰 가능 + 직접 개입 가능 |
| **Phase 3-C. codex 내부 병렬 처리** | codex가 background process로 worker(`claudex`/`codex`) 동시 spawn → 응답 파일 캡처 → history 누적으로 양방향 모사 | **cmux 외부** + claudex MCP 미등록/미설치 | cmux 없어도 동작. stateless라 매 라운드 history 누적 → context 부담. max-round 5 권장 |

자동 분기: cmux 환경 → 3-B 우선. cmux 외부 + claudex MCP 등록 → 3-A. cmux 외부 + claudex MCP 미등록/미설치 → 3-C.

cmux 환경에서 3-A를 쓰는 것은 사용자가 명시적으로 "시각화 생략"을 요청한 경우에만 허용.

---

## 6. 보안 가드 상세

multi-round skill 내부에 다음 가드가 강제됩니다. 사용자가 직접 신경 쓸 항목 위주.

| # | 가드 | 사용자 영향 |
|---|---|---|
| 1 | `claudex mcp-server` 기동 시 `-c mcp_servers={}` 강제 — worker MCP 컨텍스트 격리 | config.toml 스니펫 그대로 사용 (자동 등록 X) |
| 2 | `~/.codex/config.toml` 자동 write 금지 — 수동 등록 가이드만 출력 | 본인이 직접 등록 필요 (한 번만) |
| 3 | cmux send 줄바꿈 sanitize — multi-line prompt 조기 제출 방지 | 자동 처리 (의식 불필요) |
| 4 | claudex/codex/claude 모두 없으면 명시 에러 — silent 실패 방지 | 환경 진단 명확 |
| 5 | `cmux identify .caller.surface_ref` 사용 — 이전 `cmux current --json` 부재 명령 정정 | 자동 처리 |
| 6 | cmux 환경에서는 3-B pane 경로 우선 | worker 진행 상태를 pane으로 관찰 가능 |

`-c mcp_servers={}` 인자는 가장 중요합니다. 누락 시 워커 컨텍스트에 불필요한 MCP 서버가 같이 로드되어 회의 재현성과 격리가 약해질 수 있습니다.

---

## 7. 트러블슈팅

### 실패 모드 표

| 증상 | 의미 | 즉시 조치 | 재현 / 자세히 |
|---|---|---|---|
| Phase 0에서 "ABORT: 참가자 CLI 1개 이상 설치 필요" | claude / claudex / codex 모두 미설치 | `which claude && which claudex && which codex`로 PATH 확인. 1개 이상 `npm install -g` 또는 `nvm use` 정정 | §1 Before You Start |
| `claudex mcp-server` 등록 미확인 — Phase 3-A 진행 안 됨 | `~/.codex/config.toml`에 `[mcp_servers.claudex]` 없음 또는 claudex 미설치 | cmux 환경이면 자동으로 3-B, cmux 외부면 3-C로 fallback. 3-A가 필요하면 SKILL.md Phase 2 스니펫 등록 + codex 재시작 | §6 가드 #1·#2 |
| Lead surface 캡처 실패 (LEAD_SURFACE 빈값) | `cmux identify`가 caller surface 못 잡음 | 환경 변수 `CMUX_SURFACE_ID` 확인. 없으면 사용자가 직접 surface id 제공 | §6 가드 #5 |
| 워커 응답이 와도 Lead가 다음 라운드로 못 넘어감 | 워커 응답 마지막 줄에 `DONE:` 센티넬 누락 | 다음 라운드 prompt에 "마지막 줄 `DONE:` 강제" 재주입 | §5-2 라운드 자동화 |
| 워커 TUI에 prompt 보냈는데 조기 제출됨 (절반만 들어감) | `cmux send`가 `\n`을 Enter로 해석 | prompt를 파일로 저장 → 워커에게 "Read /tmp/.../prompt.md" 안내 (skill 자동 처리) | §6 가드 #3 |
| 양 워커 한쪽이 계속 같은 의견만 반복 | 페르소나가 너무 약하거나 prompt에 다른 입장 정보 누락 | 다음 라운드 prompt에 상대 입장을 명시적으로 인용 + "본인 입장 변경 가능한지 검토" 추가 | §3-2 dialogue 흐름 |
| max-round 도달했는데 합의 안 됨 | 본질적으로 미합의인 주제 또는 페르소나 갭이 큼 | Lead가 미합의 항목 명시 + Lead 판단으로 권장안 1개 제시 + 사용자 결정 위임 | §5-2 종료 사례 |
| 사용자가 "지금 종료" 메시지 보냈는데 라운드 계속 | Lead 폴링 루프에서 사용자 메시지 인지 누락 | 사용자 메시지 우선 처리 (Lead 응답 시작 시 inbox 확인) | §2-3 사용자 개입 |

---

## 8. FAQ

### Q1. 회의 모드를 매번 골라야 하나?
A. 아니요. 사용자 입력에서 키워드("토론해줘", "분담해서", "한쪽 항복까지" 등) 자동 추출. 명확하지 않을 때만 메뉴가 출력됨. 명시 없으면 **dialogue** 기본.

### Q2. 라운드마다 진행할지 물어보나?
A. 아니요. **기본 정책 = '모든 AI 합의'까지 자동 진행**. 사용자가 자발적으로 메시지를 보낼 때만 그 시점 반영. 묻지 않음.

### Q3. Lead는 누구?
A. **스킬을 시작한 쪽**. 본 포팅본은 Codex 측이므로 Lead=Codex 가 기본. Claudex CLI에서 발동하면 Lead=Claudex. 실행 경로는 cmux 여부와 claudex MCP 등록 상태에 따라 3-A/3-B/3-C로 갈린다.

### Q4. 참가자 CLI가 한 종류만 설치되어 있다면?
A. 설치된 CLI만으로 진행. mix는 아니지만 회의 자체는 가능하다 (시각 다양성 ↓). 단, claudex 미설치 환경에서는 3-A MCP 경로를 사용할 수 없다.

### Q5. Agent Teams와 어떻게 다른가?
A. Agent Teams = **Claude끼리만, Claude 팀 기능 베이스, MCP 불필요**. multi-round = **Codex/Claudex/Claude mix, cmux pane 또는 MCP/codex 내부 병렬 경로**. 결정적 차이는 AI 다양성 (Codex vs Claude 시각 차) + 실행 경로 (cmux pane/MCP/background fallback)입니다.

### Q6. cmux pane이 안 떠도 동작?
A. cmux 환경에서는 pane 경로(Phase 3-B)가 기본입니다. cmux 외부에서는 pane 없이 Phase 3-A(MCP) 또는 Phase 3-C(codex 내부 병렬)로 동작합니다.

### Q7. 회의 결과는 어디 저장?
A. Lead가 Phase 5에서 종합한 결과는 conversation 안에 남음. 별도 파일 저장은 사용자 명시 요청 시에만.

### Q8. multi-check를 multi-round 안에서 호출?
A. 가능. 라운드 중 "이 부분은 1회성으로 확인하자"가 필요하면 Lead가 `multi-check` 호출 → 결과를 다음 라운드 prompt에 inject.

---

## 9. Examples

> 실제 사용 시나리오 4종. prompt 입력 → Lead 자동 진행 → 기대 결론 흐름.

### 9-1. `consult` 예시 — 단발 자문

**사용자 입력**:
```
멀티 라운드 consult로 PostgreSQL 14+에서 권장하는 트랜잭션 격리 수준 디폴트값 알려줘
```

**Lead 동작 (요약)**:
1. preflight 확인 — claude + claudex 양쪽 OK
2. 회의 모드 = consult (사용자 명시)
3. 워커 1명 spawn (mix이지만 1명만 답하면 됨 — claudex)
4. 라운드 1 prompt 전달 → claudex 응답 + `DONE:`
5. Lead 종합: "**PostgreSQL 14+ 기본값은 Read Committed.** 다른 격리 수준은 명시 BEGIN ISOLATION LEVEL ... 로 변경 가능. ..."

**전체 시간**: ~30초

---

### 9-2. `dialogue` 예시 — 양방향 토론 (가장 흔한 케이스)

**사용자 입력**:
```
결제 모듈의 트랜잭션 격리 수준 어떻게 할지 멀티 라운드로 클로드랑 클로덱스 토론해서 정해줘
```

**Lead 동작 (라운드별)**:

| 라운드 | claude (Worker A) | claudex (Worker B) | Lead 분석 |
|---|---|---|---|
| 1 | "Serializable 권장 — 결제는 정합성이 모든 것" | "Read Committed + 명시적 lock 추천 — Serializable은 성능 비용 큼" | 양쪽 입장 대치. 라운드 2로 |
| 2 | "성능 우려 인정 — 다만 결제는 빈도 낮으니 Serializable 전체 적용해도 영향 미미" | "DISSENT: 결제 빈도가 높은 시스템도 있음. SELECT FOR UPDATE로 명시적 락 + Read Committed 조합이 일반적" | DISSENT 존재. 라운드 3 |
| 3 | "AGREED: 'SELECT FOR UPDATE + Read Committed'가 PostgreSQL 모범사례에 가까움. 다만 lock 누락 위험은 review에서 잡아야" | "AGREED: lock 누락 위험은 동의. 정적 분석 또는 트랜잭션 boundary 강제로 보완 가능. CONSENSUS 후보" | 합의 후보 등장. 라운드 4 |
| 4 | "CONSENSUS: Read Committed 기본 + 결제 트랜잭션 안에서 명시적 SELECT FOR UPDATE. lock 누락은 코드 리뷰·정적 분석으로 보완" | "CONSENSUS: 동의. 동일 결론" | 양쪽 CONSENSUS 일치 → 종료 |

**Lead 종합 보고**:
```
## Multi-Round Results
- 모드: dialogue
- 참가자: claude (Worker A), claudex (Worker B)
- 진행 라운드: 4/5
- 종료 사유: CONSENSUS 도달

### 합의
- 기본 격리 수준: Read Committed
- 결제 트랜잭션 안: 명시적 SELECT FOR UPDATE
- 보완: 코드 리뷰·정적 분석으로 lock 누락 검출

### 권장 적용
1. 결제 서비스 DB connection 기본 isolation = READ COMMITTED
2. 결제 트랜잭션 코드에서 처리 대상 row를 SELECT ... FOR UPDATE
3. PR 체크리스트에 "결제 트랜잭션 lock 적용 확인" 항목 추가
```

**전체 시간**: ~2~3분

---

### 9-3. `collaborate` 예시 — 분담 협업

**사용자 입력**:
```
멀티 라운드 collaborate로 결제 API 명세 작성 — 한 명은 요청 스키마, 한 명은 응답·에러 코드. 서로 리뷰까지
```

**Lead 동작 (단계)**:

| 단계 | claude (Worker A) | claudex (Worker B) | Lead 분석 |
|---|---|---|---|
| (1) 분배 | `DISTRIBUTE: 본인=요청 스키마 / 상대=응답·에러 코드` | `AGREED: 분담 채택` | 분배 합의 → 구현 단계로 |
| (2) 구현 | (claude가 요청 스키마 작성) `DONE: 요청 스키마 — POST /api/v1/payments, body: {amount, currency, idempotency_key, ...}` | (claudex가 응답·에러 코드 작성) `DONE: 응답 200 OK + {payment_id, status, ...}. 에러 400/402/409/500 각 case` | 양쪽 분담 완료 |
| (3) 상호 리뷰 | (claude가 claudex 결과 리뷰) `REVIEW_PASS: 에러 코드 분류 적절. 멱등성 키 충돌 409 처리 명확` | (claudex가 claude 결과 리뷰) `REVIEW_FAIL: idempotency_key 형식 미지정. UUID v4 + 24h TTL 권장` | 한쪽 리뷰 fail → claude 재작업 |
| (재작업) | `STATUS: idempotency_key = UUID v4, TTL 24h 명세 추가. DONE` | `REVIEW_PASS: 수정 확인. 양쪽 합격` | 양쪽 REVIEW_PASS → 종료 |

**Lead 종합 보고**: 최종 API 명세 통합본 (요청 + 응답 + 에러)

**전체 시간**: ~4~5분

---

### 9-4. `debate` 예시 — 반박 토론

**사용자 입력**:
```
PostgreSQL vs MongoDB — 우리 결제 시스템에 진짜 뭐가 맞는지 멀티 라운드 debate로 한쪽이 항복할 때까지
```

**Lead 동작 (라운드별)**:

| 라운드 | claude | claudex | Lead 분석 |
|---|---|---|---|
| 1 | "PostgreSQL — 결제는 ACID·정합성이 최우선" | "MongoDB — 스키마 유연성·쓰기 성능·샤딩 자연스러움" | 강한 대치. 라운드 2 |
| 2 | "DISSENT: 결제 도메인에서 ACID 위반 = 회계 사고. MongoDB의 트랜잭션 지원은 PG 대비 미흡" | "DISSENT: MongoDB 4.0+ 다중 문서 트랜잭션 지원. 성능 이점 + 스키마 변경 비용 ↓" | 양쪽 강하게. 라운드 3 |
| 3 | "DISSENT: MongoDB 트랜잭션은 replica set 한정·성능 트레이드오프 큼. 결제 같은 강한 일관성 요구는 PG가 안전" | "DISSENT: 트레이드오프 인정. 단 우리 시스템 미래 스케일·도큐먼트 변화 빈도 고려하면 MongoDB가 장기적으로 우위" | 라운드 4 |
| 4 | "DISSENT: 미래 스케일은 PG도 파티셔닝·논리 복제로 대응 가능. 결제는 회계 audit 필수 — PG의 trigger·rule 시스템이 강력" | "CONCEDE: 결제 도메인 한정 + audit 요구 + 회계 정합성을 종합하면 PG의 안전성이 더 우월. PostgreSQL이 우리 케이스에 맞음" | 한쪽 CONCEDE → 종료 |

**Lead 종합 보고**: "결제 시스템은 PostgreSQL. 근거: ACID·audit·trigger·논리복제·결제 도메인 정합성. MongoDB는 다른 컴포넌트(상품 카탈로그·이벤트 로그 등) 검토 가능."

**전체 시간**: ~3~4분

---

### 9-5. 메타 예시 — 본 매뉴얼이 이렇게 만들어졌습니다

> 본 매뉴얼의 골격(파일 구조·Before You Start 5개 체크박스·실패 모드 표·examples 위치 등)은 **multi-round skill 자체로 결정**됐습니다.
> claude-A (사용성·UX 관점) + claude-B (안정성·보안 관점) 두 워커가 4라운드 dialogue → CONSENSUS 도달.
> 회의 transcript 보관: `~/.codex/plugin-data/deft/multi-round/sessions/standalone/20260605-1735-design/round{1-4}-*.md` (개인 메타).

---

## 더 깊이

- skill 내부 동작 상세: [SKILL.md](SKILL.md)
- 참가자 페르소나: [agents/claude-participant.md](agents/claude-participant.md), [agents/codex-participant.md](agents/codex-participant.md)
- 본업 환경 (정새한슬 개인 정책): `~/AGENTS.md §5-0`, `~/git/AGENTS.teams.md §14`
- 트래킹: `~/relay-setup-customizations.md §24~`
