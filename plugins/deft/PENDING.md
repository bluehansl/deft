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

- [x] **🔴 Phase 3-A 재작성 — 회의 워커 헬퍼 기반 2채널 공존 복원** (2026-06-25 해결 → claude-2.43.0) — 2.40.0 회귀(빈 pane + CLI 직접부팅으로 `--claude-team-agent` binding 누락 → 이름표 사라짐 + cmuxKnock 폴백)를 R-16 절차(첫 워커 Agent tool + 나머지 헬퍼 `DEFT_BUS_DIR` 주입)로 교체. NTP binding(이름표·ntpPush) + 버스 board 2채널 공존 복원. `--inbox` register 가 ntpPush 스위치. 용례 1 단일 소스 통합·dangling 참조 정정 동반. 근거 RATIONALE R-16. **검증 대기**: 사용자가 다른 워크스페이스 날것 실행으로 확인(bash 직접 실측 금지 — R-8 맹점).

- [x] **테스트 세션 워커 부팅 실패** (2026-06-25 해결 → claude-2.42.0) — zsh 환경 cmux send 3대 함정(입력창 잔여·긴 명령 유실·colon 파싱). 사용자 세션 자체 보정 패턴을 일반화(C-u 클리어·source 파일화·명시적 나열). 근거 RATIONALE R-15.
