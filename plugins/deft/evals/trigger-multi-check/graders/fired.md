---
type: tool_used
tool: Skill
weight: 1
---

deft 스킬이 발동했는지 확인한다.

⚠️ ablation(with-without) 에서 이 grader 는 **with-only 지표로 분류돼 점수에서 제외**된다
(Δ 를 움직이지 않음). 즉 weight 값과 무관하게 "플러그인이 발동했는가" 표시용이며,
케이스의 실제 점수는 outcome grader 가 결정한다. `arm` 은 지정하지 않는다(러너가 처리).
