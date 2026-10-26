# ticket-analysis

이슈 티켓 작업의 **선언부터 결과 보고까지** — 운영 절차와 분석 방법론을 하나의 스킬로 제공한다.

## 구성 (6문서)

| 문서 | 역할 |
|---|---|
| `SKILL.md` | 트리거·소유권·라우팅·공통 원칙 |
| `references/ticket-workflow.md` | 티켓 선언·기준 티켓, 컨텍스트 로드(이슈 트래커 본문·댓글·연결 이슈 분석, 레코드 `<ID>.md`), 도구 선택, 단계별 승인 절차(7단계), 체크리스트 문법 |
| `references/artifact-routing.md` | 산출물 저장 경로 라우팅(audience 기준), 브라우저 리뷰 문서·Export 규칙, 제출 감시 |
| `references/vault-layout.md` | 기록 계층 — 레코드·결정·지식·세션 원문·워크로그 자리, 세션↔프로젝트 묶기, work-id↔ID 변환 |
| `references/ticket-md-schema.md` | 프로젝트 레코드 `<ID>.md` 표준 스키마 |
| `references/requirement-refinement.md` | 요건 정제 — 조사 먼저·질문은 한 번에 하나·접근안 2~3개 비교·self-review 4종 |
| `references/plan-writing.md` | Plan 작성 — zero-context 독자 가정·No-Placeholder·태스크 간 Interfaces 계약 |
| `references/defect-analysis.md` | 버그 원인 진단 — 근본 원인 규명 전 수정 금지(Iron Law)·3-Phase 진단 |

## 설계 원칙

- **스킬 = 티켓 프로세스의 단일 소스.** 호스트 지침(CLAUDE.md/AGENTS.md)에는 본 스킬을 호출하는 트리거 문구만 남긴다 — 내용 중복 없음.
- 호스트 지침의 우선순위 원칙(사용자 명시 지시 > 보안 > 그 외)이 최상위다.
- 분석 방법론은 [obra/superpowers](https://github.com/obra/superpowers)(MIT License)의 brainstorming / writing-plans / systematic-debugging 스킬을 선별 이식·한국어 재구성한 것이다. 원본의 실행 국면(TDD 체인, HARD-GATE, 워크트리·서브에이전트 오케스트레이션)은 범위 밖으로 제외했다.

## 벤치마크 (2026-07-31, iteration-1)

가상 티켓 3종(기능/버그/Plan) × with/without 비교: **pass rate 100% vs 80%** (변별 지점: 단일 질문 규칙, Interfaces 계약, 수정 위치 앵커). 오버헤드 +46s/+7.1k tokens.
