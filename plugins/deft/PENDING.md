# deft — 진행 중·보류 항목 (PENDING)

> 진행 중이거나 미뤄둔 작업·이슈를 추적한다. 완료되면 CHANGELOG 로 옮기고 여기서 제거.
> 설계 근거는 `RATIONALE.md`, 버전 이력은 `CHANGELOG.md`.

상태 플래그: `[ ]` 미착수 · `[>]` 진행중 · `[!]` 보류(사유) · `[x]` 완료(→ CHANGELOG 이관)

---

## 진행 중

(없음 — 진행 중 항목은 완료 시 CHANGELOG 로 이관)
## 보류 / 대기

- [ ] **multi-check Phase 5 ② 잔존 판정이 orca in-process 리뷰어에서 무의미** (2026-09-15 등재 · 우선순위 낮음)
  - **관측(E2E 검증)**: Phase 5 ② 의 `pgrep -f -- "--agent-id $R@$TEAM_NAME"` 는 orca `backendType=in-process` 리뷰어에서 **항상 0** 이다 — 별도 프로세스가 아니기 때문. "정상 종료"와 "판정 불가"를 구분하지 못한다.
  - **현재 대응**: `shutdown_approved` 수신으로 종료를 확인하면 충분하다(E2E 에서 그렇게 확인). 즉 실害는 없고, 가드가 조용히 무효인 상태다.
  - **검토할 것**: in-process 모드에서의 잔존 판정 기준(예: `shutdown_approved` 미수신 + 일정 시간 경과로만 판정). cmux(별도 pane) 모드에서는 현행 pgrep 가 유효하므로 **모드 분기**가 필요하다.


- [ ] **multi-check 리뷰어 CLI detach — 리뷰어 종료와 CLI 수명 분리** (2026-09-07 등재 · P2)
  - **배경**: 2026-09-07 사고(RATIONALE R-18)에서 리뷰어 Agent 종료가 background 로 밀린 CLI 까지 함께 죽였다. `claude-2.51.0` 은 **센티널 분기로 "죽이지 않게"** 해결했지만(Lead 가 shutdown 을 보류), CLI 수명이 여전히 리뷰어 프로세스에 묶여 있다는 구조는 그대로다.
  - **제안**: `deft-review` 가 CLI 를 `setsid` 등으로 부모와 분리해 띄우고 출력을 파일로 tee → 리뷰어가 언제 종료돼도 결과 파일이 완성된다. Codex 포트가 이미 이 성질을 갖고 있다(pane 독립 프로세스 + tee) — 사고가 Claude 측에서만 난 이유.
  - **미착수 사유**: ① 2.51.0 의 센티널 분기로 실사용 재발은 막혔다(우선순위 하락) ② detach 는 페르소나에 raw bash 를 노출하거나 `deft-review` 에 출력파일 규약을 새로 만들어야 해 **표면 변경 범위가 P0 대비 크다** ③ 고아 프로세스 정리 책임이 새로 생긴다(현재는 리뷰어와 함께 정리됨).
  - **착수 판단 기준**: 20분 상한(리뷰어 이어받기)을 넘기는 검토가 실제로 반복되면 착수.
  - **전제 확보 (2026-09-15 · claude-2.53.0 / R-19)**: job dir(`pid`/`pgid`/`exit_code`) + `deft-review status`/`cancel` 이 도입돼 **P2 의 전제(job registry·완료 marker·취소 API)가 이미 갖춰졌다.** 남은 작업은 `set -m` 을 `setsid` 로 바꿔 자식을 부모와 완전 분리하는 것 정도로 줄었다. 단 착수 판단 기준은 불변 — 분리하면 "리뷰어 종료 시 CLI 도 종료" semantics 가 깨져 고아 정리 책임이 새로 생긴다.
  - **근거 보강 (2026-09-07 L4 검증 중 리뷰어 지적)**: "timeout 을 진행 중으로 재정의하는 설계는 **작업이 실제로 계속 살아 있다는 런타임 보장이 있을 때만** 성립한다. parent timeout 이 child 종료로 이어지는 환경에서는 위험한 재정의다." — 우리 환경은 child 생존을 실측했지만(R-18), 그 보장이 **런타임 우연에 기대고 있다**는 점은 정확하다. detach 는 이 전제를 우연이 아니라 설계로 만든다. 다만 리뷰어도 detach 의 새 책임(job registry·완료 marker·취소 API·리소스 상한)을 함께 지적했으므로 P2 유지 판단은 그대로.


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

- [ ] **모델 지정 전면 변수화 — `deft-model` SSOT 단일화 (멀티체크 haiku 제외)** (2026-07-02 가능여부 판단 완료 · 구현 대기)
  - **판단**: 가능. 모델 지정이 2종 — ① **CLI 실행**(`claude --model`)은 이미 `deft-model` 참조(일부 리터럴만 잔존) → `$(deft-model claude)` 로 완전 자동화 가능 / ② **Agent tool `model:`**(팀원·첫워커, alias `fable` ~10곳)은 도구 호출이라 `$()` 런타임 치환 불가 → "SSOT 참조" 관례로만 단일화.
  - **제약**: Agent enum 은 alias(`fable`)만, CLI 는 풀 ID(`claude-fable-5`)도 수용 — 두 표기 공존이라 deft-model 이 둘 다 내보내야 함.
  - **설계 (승인 시)**:
    - [ ] `deft-model` 에 alias 차원 추가: `deft-model claude`→`claude-fable-5`(CLI), `deft-model claude alias`→`fable`(Agent enum). 양 포트. (모델 교체 시 여기 2값만)
    - [ ] CLI 리터럴 → `$(deft-model claude)`: `bin/deft-claude-native-spawn` 기본(`${4:-fable}`), multi-round 헬퍼 호출 인자. 완전 자동 전파.
    - [ ] Agent tool 문서 ~10곳 축약: 단일 선언 1곳 + 나머지(agent-teams SKILL/GUIDE·`agents/*.md` 8종·multi-round 첫워커)는 그 선언 참조. SKILL 이 "Lead 는 spawn 시 `deft-model claude alias` 로 모델 결정" 명시.
  - **범위 제외**: multi-check `model:"haiku"`(의도된 경량 래퍼) — 변수화 대상 아님.
  - **트레이드오프**: 장점 = 모델 교체가 진짜 1곳(deft-model). 단점 = Agent tool 문서 자기완결성↓(reader 가 deft-model 조회 필요) + Lead 가 spawn 때 SSOT 조회하도록 SKILL 강제 필요. 작업량 ≈ claude-2.45.0 Fable 변경과 유사(양 포트).
  - **동기**: claude-2.45.0 Fable 복원 때 opus→fable 를 양 포트 ~20곳 sed 로 교체했음 — 이 변수화로 차기 모델 교체는 deft-model 1곳으로 축소.
