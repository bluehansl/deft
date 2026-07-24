# Agent Teams — 운영 가이드 (GUIDE)

SKILL.md의 규약을 **실전 시나리오**로 풀어쓴 보조 문서. 처음 운영 시 이 흐름을 따라가면 된다.

---

## Before You Start (시작 전 점검)

팀을 띄우기 전에 다음을 확인한다 (상세 §0):

- [ ] `cmux claude-teams` **또는 `orca claude-teams`** 환경에서 실행 중인가? (아니면 §0-2 — 단일 Claude degrade 또는 재시작 권장) ⚠️ 환경 판정은 ORCA_* 변수 우선(§0-1 — orca 안에서도 cmux CLI 가 별도 cmux 앱에 연결되어 성공하므로 오판·오발사 주의)
- [ ] `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` 활성 + Claude Code **v2.1.32 이상**인가?
- [ ] `Agent`/`SendMessage`/`Task*` 도구를 쓸 수 있는가? (팀은 첫 `Agent` spawn 시 암묵적 자동 생성 — 별도 `TeamCreate` 불요/폐지)
- [ ] work-id 저장 경로 `~/.claude/plugin-data/deft/agent-teams/<work-id>/` 에 접근 가능한가?
- [ ] (cmux/orca claude-teams 일 때) 팀원 pane 자동 분할이 동작하는가? (orca 는 tmux shim 으로 자동 — §2-2)
- [ ] `cmux-rebalancing` 헬퍼가 PATH 에 있는가? 없으면 skill 첫 실행 시 plugin 동봉본이 `~/.local/bin/` 으로 자동 설치됨. 팀원 spawn 후 Lead/팀원 pane 비율 재조정에 사용 (**cmux 환경 한정** — orca 는 resize CLI 미지원이라 미사용, pane 비율은 UI 드래그)

---

## A. 빠른 시작 — 표준 3인 팀 end-to-end

> 시나리오: "결제 모듈에 환불 기능 추가. 팀으로 진행해."

### A-1. work-id 규약 (최초 실행 1회 — deft 플러그인 공통)

`~/.claude/plugin-data/deft/config.json` (플러그인 공통 — multi-round 와 공유) 이 없으면 메뉴 출력:

```
이 환경의 work-id(작업 영속 키) 규약을 정해주세요:
  1. 외부 이슈/티켓 번호 (예: IT-14610, JIRA-123, #456)
  2. git 브랜치명
  3. 날짜-작업명 (예: 20260608-refactor-auth)
  4. 자유 작업명
  5. 매번 직접 입력
```

사용자가 `1` 선택 → 저장:
```jsonc
// config.json
{ "workIdConvention": "issue-ticket", "example": "IT-14610", "decidedAt": "2026-06-08" }
```
```markdown
<!-- CONVENTION.md -->
# work-id 규약 (현재)
- 규약: 외부 이슈/티켓 번호
- 예시: IT-14610
- 변경하려면: 스킬에 "work-id 규약 바꿔" 요청  또는  이 파일 + config.json 직접 수정
```

→ 이후 실행부터는 재질문 없이 이 규약으로 work-id를 받는다. **multi-round 도 같은 config 를 읽으므로 거기서도 재질문 없음** — 어느 skill 이 먼저 정하든 공유된다.

### A-2. work-id 확정 + 작업노트 로드

규약이 "이슈/티켓 번호"이므로 사용자에게 work-id를 묻거나(예: `PAY-321`) 컨텍스트에서 추출.
```
~/.claude/plugin-data/deft/agent-teams/PAY-321/work.md 존재?
  ├─ 있음 → 로드, "## 완료 항목" 이후 미완료부터 이어서 (세션 재시작)
  └─ 없음 → SKILL.md §6-1 템플릿으로 신규 생성
```

### A-3. 단계 게이트 (사용자 컨펌)

```
1. 요건 분석  → work.md ## 요건 분석 작성
2. 영향도     → work.md ## 영향도 확인 (레이어별)
   ★ 사용자 컨펌
3. Plan       → work.md ## 작업 계획 체크리스트
   ★ 사용자 승인
```

### A-4. 팀원 spawn (팀은 암묵적 자동 생성)

```
# TeamCreate 불요(폐지) — 첫 Agent spawn 시 ~/.claude/teams/session-<id>/ 가 자동 생성됨
# config.json 의 name(session-<id>) 을 확인해 work.md ## META "현재 team-name" 에 기록

Agent(name="backendDev", subagent_type="claude", model="fable",
      prompt=<§4-3 템플릿 + agents/backendDev.md 경로 + work-id=PAY-321>)
Agent(name="frontendDev", subagent_type="claude", model="fable", ...)
Agent(name="qa", subagent_type="claude", model="fable", ...)
# team_name 인자는 넣지 않는다(deprecated/무시). model:"fable" 명시 — 팀원은 Lead 모델 미상속.
```
> `cmux claude-teams`/`orca claude-teams` 환경이라 pane 분할은 자동(§2-2). Lead는 pane 명령 호출 불필요. cmux 모드는 첫 팀원 분할 직후 `cmux-rebalancing` 1회(§2-3) — orca 모드는 rebalance skip(resize CLI 미지원).

### A-5. 구현 사이클

```
backendDev → Plan 보고 (SendMessage to Lead)
Lead → 승인
backendDev → 구현 → backendDev.md 갱신 → "DONE: 환불 Service/Mapper 완료" (SendMessage)
Lead → git diff 검증 → 일치 → work.md 해당 체크리스트 [O]
      ★ 사용자 컨펌 후 다음 단계
```
frontendDev·qa도 동일. FE-BE 인터페이스 협의가 필요하면 §C-2.

### A-6. 종료

검증·리뷰 완료 → Lead가 결과 보고 → **팀원 idle 유지(자동 종료 X)**. 사용자가 "팀 종료" 시에만 shutdown.

---

## B. 세션 재시작 연속성 (핵심 가치)

세션이 끊긴 뒤 다시 "PAY-321 이어서 작업해":

```
1. work-id = PAY-321 (규약대로 확정)
2. ~/.claude/plugin-data/deft/agent-teams/PAY-321/work.md 로드
   → ## 완료 항목: [1. 환불 Service] 까지 끝남
   → ## 작업 계획: [2. 환불 화면], [3. 검증] 이 미완료([ ])
3. 미완료 2번부터 재개. 팀원도 본인 role.md 미완료부터.
```

> **team-name이 새로 바뀌어도** work-id가 같으면 같은 work.md를 물어 연속된다. 이것이 work-id를 내장 team-name과 분리한 이유(SKILL.md §3-2).
> 새 team-name으로 팀을 다시 띄우면 work.md `## META 현재 team-name`만 갱신.

---

## C. 페어 / Trio 패턴 예시

### C-1. PM 페어 (dialogue) — 양면 의사결정

> "이 기능 본사 전용 vs 고객사도 조회 가능 — 두 관점으로 정해줘."

```
Lead = pm-eng 관점 진행
Agent(name="pm-user", prompt=<agents/pm.md pm-user 변형>)
라운드1: Lead(pm-eng) 입장 → pm-user 답변
  pm-user: DISSENT: 고객사 조회 막으면 CS 문의 폭증 우려
라운드2: Lead 보강 → ...
  → CONSENSUS: 고객사=조회만, 본사=전체 → 종료
work.md ## 협의사항:
  @pm-eng: 권한 분기 비용 낮음, 조회 허용 가능 (...)
  @pm-user: 고객사 조회 필수 (...)
  @Lead: 채택 — 고객사 조회 전용
```

### C-2. FE-BE 페어 (dialogue) — 인터페이스 협의

```
frontendDev + backendDev spawn
각자 인터페이스안 작성 (요청/응답 스키마·error code) → SendMessage로 상대에 공유
이견/동의 → 즉시 Lead 보고
Lead → work.md ## 설계 결정 에 확정 인터페이스 반영
```

### C-3. 3인 Trio (cascade) — 복잡 작업

```
architect spawn → 영향도+설계만 → DONE → ★사용자 컨펌
backendDev spawn → Plan→승인→구현 → 각 단계 ★컨펌
qa spawn → 검증 시나리오+테스트 → qa.md
Lead → work.md 종합 + REVIEW → 최종 보고
```

### C-4. 동일역할 협업 (collaborate) — 분담+상호리뷰

```
backendDev-a + backendDev-b spawn
(1) 분배:  a→ DISTRIBUTE: 본인=Mapper/SQL, 상대=Service/Controller
           b→ AGREED
(2) 구현:  각자 병렬 → 각자 DONE
(3) 상호리뷰: a→ b의 Service 리뷰 → REVIEW_PASS
              b→ a의 Mapper 리뷰 → REVIEW_FAIL: 인덱스 미적용
           a→ 수정 → DONE → b→ REVIEW_PASS
→ 양쪽 PASS → Lead가 work.md [O]
```
> 자기 분담은 본인이 점검 안 하고 **상대가 리뷰**(편향 회피).

### C-5. 이중 리뷰 (signoff)

```
Lead + reviewer(독립 시각) spawn
각자 독립 VERDICT 산출
  둘 다 COMPREHENSIVELY_SATISFIED → 사인오프 → work.md ## REVIEW에 양쪽 verdict
  한쪽 NOT_SATISFIED → 수정 → 재리뷰 루프
```

---

## D. 트러블슈팅 / FAQ

| 증상 | 원인 / 처리 |
|---|---|
| 팀원이 답이 없다 | idle은 정상. `SendMessage` 보내면 깨어남. 폴링 불필요(§2-1). 성급히 재촉 X |
| 작업노트가 사라졌다(plugin update 후) | 작업 데이터를 cache에 뒀을 가능성. 반드시 `~/.claude/plugin-data/deft/agent-teams/`에 (§3-1) |
| 같은 작업인데 연속이 안 됨 | work-id를 다르게 줬을 가능성. 규약(CONVENTION.md)대로 동일 work-id 사용 |
| 팀원이 work.md를 직접 고침 | 금지. work.md는 Lead 단독. 팀원은 본인 role.md만 (§6) |
| AI mix(Claudex 등) 토론이 필요 | 본 skill 아님 → `deft:multi-round` 사용 |
| 1발 비교만 필요 | `deft:multi-check` |
| cmux/orca 외부에서 팀이 안 뜸 | 정상 — §0-2. 단일 Claude degrade 또는 `cmux claude-teams`(Orca 면 `orca claude-teams`) 재시작 |
| orca 모드에서 rebalance/워처가 "orca 모드 감지 — 차단" 출력 | 정상 가드 — Orca 는 resize CLI 미지원. pane 비율은 UI 드래그로 조정 (§2-3 🟠) |

---

## E. 운영 체크리스트

- [ ] work-id 규약이 결정·저장되어 있는가 (config.json/CONVENTION.md)
- [ ] work-id로 work.md를 로드(있으면 이어서)했는가
- [ ] 요건분석·영향도 후 ★사용자 컨펌을 받았는가
- [ ] Plan·체크리스트 후 ★사용자 승인을 받았는가
- [ ] 팀원 spawn 시 agents/<role>.md 페르소나 + §4-3 게이트를 inject했는가
- [ ] 팀원이 구현 전 Plan 보고 → Lead 승인했는가
- [ ] 완료 시 Lead가 git diff로 검증하고 work.md [O] 갱신했는가
- [ ] 각 체크리스트 단계 ★사용자 컨펌 후 진행했는가
- [ ] 작업 데이터를 plugin-data(영속)에만 뒀는가 (cache X)
- [ ] 종료 시 팀원을 자동 종료하지 않았는가 (사용자 명시 시에만)
