# deft eval 스위트

`claude plugin eval` 하네스로 deft 스킬의 **트리거 정확도**와 **오발동 방지**를 회귀 검증한다.
`deft-test` 스킬(정적·단위·E2E)과 상호 보완 — 이쪽은 **스킬 description 이 의도대로 발동하는가**를 본다.

## 실행

```bash
cd <repo>   # 워크트리 루트
claude plugin eval plugins/deft \
  --runs 3 \
  --judge-model sonnet \
  --max-cost-usd 5 \
  --no-publish \
  --trust-plugin
```

| 옵션 | 이유 |
|---|---|
| `--no-publish` | 🚨 **필수** — 기본이 claude.ai 발행이라 사내 컨텍스트가 외부로 나간다 |
| `--judge-model sonnet` | 하네스 권고. 기본 haiku 는 rubric 뉘앙스를 놓친다 |
| `--max-cost-usd 5` | 하드 상한(초과 시 exit 2). 24런 기준 실측 약 $2~3 |
| `--trust-plugin` | 첫 실행 신뢰 프롬프트 skip. **`--scaffold`·`--allow-tools`·`--mocks off` 를 의미하지 않는다** |

**쓰지 않는 옵션**: `--scaffold` / `--allow-tools` / `--mocks off` / `--allow-real-servers`.
특히 `--allow-tools` 를 주지 않아 **Bash 가 gated** 되는 것이 의도된 안전장치다 —
스킬이 발동해도 실제 리뷰어 CLI(claudex/gemini)·워커 spawn 이 일어나지 않아
**비용이 예측 가능**하고 측정 대상이 "발동과 산출물 형태"로 좁혀진다.

## 케이스

| 케이스 | 프롬프트 요지 | 기대 |
|---|---|---|
| `trigger-multi-check` | "교차 검증해줘" + 설계 질문 | multi-check 발동, 합의/상이점/결론 구조 |
| `trigger-multi-round` | "이 주제로 회의 열어줘" | multi-round **회의 모드**(라운드 토론·수렴). 작업 모드면 실패 |
| `trigger-agent-teams` | "IT-14610 코딩 작업 시작" | 역할 분담 + **승인 게이트** 준수 |
| `no-fire-meeting-notes` | "회의록 정리해줘" | 🚨 **어떤 멀티에이전트 스킬도 발동 안 함** |

`no-fire-meeting-notes` 는 하네스 불변식(≥1 should-NOT-fire)을 충족하며,
"회의" 라는 단어가 multi-round 강한 트리거와 표면이 겹치는데도 끌려가지 않는지를 본다.

## 채점 원칙 (하네스 내장 지침 준수)

- **outcome 을 채점하고 trajectory 를 채점하지 않는다** — "어떤 도구가 불렸나"가 아니라
  "스킬이 만들어내야 할 답이 나왔나". `tool_used: Skill` 은 ablation 에서 **점수 제외**
  (with-only 지표)이므로 **단독 grader 로 쓰지 않는다**.
- grader 계층: ① verifiable(regex/file_exists) ② binary ③ n-ary ④ llm rubric.
  `no-fire-meeting-notes` 의 사실 보존은 regex(①)로, 오발동 판단은 llm(④)으로 나눴다.
  ⚠️ **regex grader 는 긍정 매칭만 지원**한다(`negate`/`absent`/`invert` 전부 무효 — 실측).
  "없어야 한다"는 검사는 llm 에 맡겨야 한다.
- 모든 케이스에 outcome grader ≥1, `runs: 3` 최소, `--ablation with-without` 유지.

## Δ(델타) 읽는 법

**케이스 종류에 따라 정답이 반대다.**

| 케이스 | 기대 Δ | 의미 |
|---|---|---|
| `trigger-*` | **양수(크게)** | 플러그인이 있을 때 답이 실질적으로 좋아져야 스킬이 값을 한다 |
| `no-fire-*` | **0** | 플러그인이 있든 없든 같은 답이어야 한다(오발동 없음) |

`trigger-*` 의 Δ 가 0 이면 "스킬이 발동해도 결과가 달라지지 않는다"는 뜻이라,
트리거가 맞았어도 **스킬의 기여가 없다**는 신호로 읽어야 한다.

## 결과 위치

`plugins/deft/evals/results/<timestamp>/` (git ignore 대상 — 커밋하지 않는다).
