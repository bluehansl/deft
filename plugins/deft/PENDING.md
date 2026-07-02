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

- [!] **harness 방법론 부분 차용(C) — deft 문서/페르소나 흡수** (2026-06-30 회의 합의 · 구현 보류 — 사용자 승인 대기)
  - **근거**: `HANDOFF-harness-analysis.md` 의뢰 → multi-round 회의(dialogue, 3관점 mix: 하네스 아키텍트·deft 메인테이너·실무 사용자 대리) **3인 CONSENSUS**. 회의록 `~/.claude/plugin-data/deft/multi-round/sessions/standalone/20260630-171108-harness-deft/`(summary.md·transcript.md·board.jsonl).
  - **결론**: harness를 새 스킬 신설(A 내재화)·상시 병용(B) 하지 않고, **알짜만 기존 문서/페르소나에 명문화 흡수**. 코드 0줄·새 스킬 0개·PATCH급.
  - **흡수 작업 (승인 후 착수)**:
    - [ ] `skills/multi-round/SKILL.md` — 회의 모드 참가자 구성(Phase 1-4 페르소나 결정 절차)에 harness **B 에이전트 분리 4축**(전문성/병렬성/컨텍스트/재사용성 — 2축↑ 강하면 분리) 짧은 체크리스트/reference 로 흡수.
    - [ ] `skills/multi-round/SKILL.md` — **작업 모드(Phase 4-T)**에 harness **A 6대 토폴로지 미니 매트릭스**(pipeline/fan-out/expert-pool/producer-reviewer/supervisor/hierarchical) 각주. **회의 모드엔 미적용**(회의=팬인 수렴 단일 패턴이라 6대 토폴로지는 잡음).
    - [ ] `skills/agent-teams/SKILL.md` — 고정 8역할 **유지**, 토폴로지는 참고 각주만.
    - [ ] 릴리즈 체크리스트(또는 RATIONALE/GUIDE) — skill description 변경 시 harness **C 트리거 검증**(should-trigger 8~10 + near-miss 8~10) 편입.
  - **하지 않는 것(기각)**: (A) 페르소나 생성 보조 스킬 신설 — 단일 플러그인 유지비 영구반복 + no-overlink 위반 + "언제 뭘 쓸지" 4번째 결정축 혼란. (B) harness 상시 병용 — 빌드타임 메타툴 vs 런타임 일회성 시점 부정합 → 예외/고급 흐름 문서화만.
  - **불변식**: deft 정체성 3축(이종 AI 연계·work-id 영속·본업 컨벤션 강제) **무손상** — 흡수는 "기존 Lead 판단을 어휘로 보강"까지만. 균형추 memory `feedback_no_overlink_deft`.
  - **1차 분석 수정 반영**: A(6대 패턴) [상]→**[중]**(설계 렌즈로만, 런타임 엔진 아님). 실효 우선순위 **B ≳ C > A**.
