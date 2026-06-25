# deft — 진행 중·보류 항목 (PENDING)

> 진행 중이거나 미뤄둔 작업·이슈를 추적한다. 완료되면 CHANGELOG 로 옮기고 여기서 제거.
> 설계 근거는 `RATIONALE.md`, 버전 이력은 `CHANGELOG.md`.

상태 플래그: `[ ]` 미착수 · `[>]` 진행중 · `[!]` 보류(사유) · `[x]` 완료(→ CHANGELOG 이관)

---

## 진행 중

- [>] **SKILL.md 정리 — 테스트성·로그성·일지형 주석 걷어내기** (2026-06-25 착수)
  - 목표: 산재한 deft-log 호출 간소화(출력 레지스터 정책은 유지), 일지형 실측 주석을 RATIONALE.md 로 이관 후 SKILL.md 는 간결한 지침+`(근거: R-N)` 참조만, deft-test 연계·임시 잔재 제거.
  - **multi-round 1차 완료**: `RATIONALE.md` 신설(R-1~R-14) + 핵심 일지형 6건 RATIONALE 참조 축약 + deft-test L4 연계 제거. 실측 언급 39→32.
  - **남은 작업**:
    - [ ] multi-round 산재 deft-log 호출 17개 → 핵심 마일스톤만 간소화(§출력 레지스터 정책은 유지)
    - [ ] multi-round 짧은 인라인 실측 언급(32건) 중 불필요한 것 추가 정리
    - [ ] agent-teams SKILL.md 정리(deft-log 10·실측주석 13) — RATIONALE 에 항목 추가하며
    - [ ] multi-check SKILL.md 정리(실측주석 13)

## 보류 / 대기

- [>] **🔴 Phase 3-A 재작성 — 회의 워커를 헬퍼 기반 2채널 공존으로 복원** (2026-06-25, 설계 확정·구현 대기)
  - **문제**: 2.40.0 에서 회의 워커를 "빈 pane + CLI 직접부팅"으로 띄우며 `--claude-team-agent` binding 누락 → pane 이름표(`@name`) 사라짐 + NTP 노크 대신 cmuxKnock 폴백. (근거·절차: RATIONALE R-16)
  - **해법 (사용자 실측 확정 절차)**: Phase 3-A (2)~(5) 를 헬퍼 기반으로 교체.
    1. 첫 워커 = claude `Agent` tool(team 생성, team-id 획득). board 는 Lead 가 `SendMessage` 중계.
    2. 첫 워커 pane:ref 를 `~/.claude/teams/<TID>/.last-worker-pane` 기록.
    3. 나머지 워커 = 헬퍼(전부 `DEFT_BUS_DIR` 주입 → 이름표+board 공존):
       - claudex: `DEFT_BASE_WORKSPACE=<ws> DEFT_BUS_DIR=<SD> deft-claudex-native-spawn <TID> <name>`
       - claude CLI: `DEFT_LEAD_SESSION=$CLAUDE_CODE_SESSION_ID DEFT_BASE_WORKSPACE=<ws> DEFT_BUS_DIR=<SD> deft-claude-native-spawn <TID> <name> "" opus`
    4. board register + 의제 게시(post --inject) → 전원 노크·토론.
    5. 응답 회수 2경로: board 워커 `multi-round-bus check --as lead`, Agent 워커 `team-lead.json` 직접 회수.
  - **제약**: ① 화면 pane 구성은 현 개발 버전(빈 pane 선분할 레이아웃) 유지 — 헬퍼의 `.last-worker-pane` 스택이 이를 만족 ② 세션 고유값 하드코딩 금지(런타임 발견) ③ 활성 team 디렉토리 rm 금지.
  - **인프라 준비 완료**: `deft-claude-native-spawn`·`deft-claudex-native-spawn` 둘 다 repo·설치 존재, `DEFT_BUS_DIR`·`DEFT_LEAD_SESSION` 처리 내장 확인.
  - **검증**: 수정 후 R-8 교훈대로 — 사용자가 다른 워크스페이스에서 스킬 날것 실행으로 확인(bash 직접 실측 금지).
  - ⚠️ 약 120줄 교체라 컨텍스트 깨끗할 때 정밀 실행. §용례1(헬퍼 절차)과 중복 정리 동반.


- [x] **테스트 세션 워커 부팅 실패** (2026-06-25 해결 → claude-2.42.0) — zsh 환경 cmux send 3대 함정(입력창 잔여·긴 명령 유실·colon 파싱). 사용자 세션 자체 보정 패턴을 일반화(C-u 클리어·source 파일화·명시적 나열). 근거 RATIONALE R-15.
