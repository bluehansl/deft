---
name: multi-check
description: Codex 환경에서 Codex, Gemini, Claude 등 여러 AI reviewer에게 단발성 병렬 교차 검증을 요청하고 Lead가 결과를 취합한다. 트리거 예시 "multi check", "cross verify", "cross check", "ask other AIs too", "multi AI comparison", "교차 검증", "다른 AI한테도 물어봐", "멀티 체크".
---

# multi-check

여러 AI의 관점으로 사실, 기획안, 개발 계획, 코드 변경, 장애 원인 분석 등을 빠르게 교차 검증한다. 이 스킬은 장기 협업용 team workflow가 아니라, **one-shot 병렬 reviewer 실행 + Lead 취합**을 위한 스킬이다.

## 실행 원칙

- `/multi-check`, `교차 검증`, `다른 AI한테도 물어봐`, `멀티 체크` 요청은 여러 reviewer에게 병렬 검토를 위임하라는 명시적 요청으로 간주한다.
- Lead는 현재 Codex 세션이다.
- reviewer는 독립된 단발성 검토자다.
- reviewer 간 직접 통신은 사용하지 않는다. 모든 요청과 취합은 Lead가 담당한다.
- reviewer는 결과를 Lead에게 반환한 뒤 세션이나 프로세스를 유지하지 않는다.
- 추가 확인이 필요한 경우에도 reviewer는 추가 질문을 기다리지 않는다. 필요한 정보, 전제, 리스크를 결과에 적고 종료한다.
- Lead가 추가 검토가 필요하다고 판단하면 새 요청으로 reviewer를 다시 실행한다.
- Claude Code 전용 agent/team 호출 문법은 Codex 포팅본에서 사용하지 않는다.

## Lead 역할

1. 사용자 요청에서 검증 대상과 기대 산출물을 추출한다.
2. 코드/프로젝트 관련 요청이면 필요한 컨텍스트를 수집한다.
3. reviewer별로 동일한 검토 프롬프트를 만든다.
4. 가능한 reviewer를 병렬로 실행한다.
5. 실패하거나 응답하지 않는 reviewer는 사유를 기록하고 skip한다.
6. 자신의 분석과 reviewer 응답을 비교해 최종 결론을 작성한다.
7. 모든 reviewer 세션/프로세스가 종료되었는지 확인한다.

## 컨텍스트 수집 기준

| 요청 유형 | 포함할 컨텍스트 |
|---|---|
| 코드 리뷰 | `git diff`, 관련 파일 내용, 테스트/빌드 명령, 영향 파일 |
| 개발 계획 검토 | 요구사항, 현재 계획, 제약사항, 관련 코드 구조 |
| 장애/버그 분석 | 에러 로그, 재현 조건, 관련 코드, 최근 변경 |
| 기획/정책 검토 | 최종 정리안, 의사결정 배경, 미확정 사항 |
| 일반 기술 질문 | 사용자 질문 본문 |

컨텍스트는 과도하게 넓히지 않는다. reviewer가 판단할 수 있을 만큼만 제공하고, 민감 정보는 포함하지 않는다.

## reviewer 구성

| reviewer | 실행 방식 | 필수 여부 | 역할 |
|---|---|---|---|
| Lead Codex | 현재 세션 | 필수 | 자체 분석과 최종 취합 |
| Codex reviewer | 별도 Codex reviewer 또는 Codex CLI | 선택 | 현재 Lead와 독립된 Codex 관점 검토 |
| Gemini reviewer | Gemini CLI headless 실행 | 선택 | Gemini 관점 검토 |
| Claude reviewer | Claude CLI headless 실행 | 선택 | Claude 관점 검토. 토큰/인증 문제 시 skip |

최소 1개 외부 reviewer가 있으면 교차 검증으로 진행한다. 외부 reviewer가 모두 실패하면 Lead 단독 분석으로 전환하고 실패 사유를 명시한다.

## 병렬 실행 전략

### 기본: Codex sub-agent 병렬 실행

Codex에서 sub-agent를 사용할 수 있으면 reviewer별 one-shot 작업으로 병렬 실행한다. 이 방식이 Codex 포팅본의 기본 실행 전략이다.

- `codex-reviewer`: Codex CLI를 실행하거나 독립 Codex 관점으로 분석한다.
- `gemini-reviewer`: Bash로 Gemini CLI를 실행하고 결과를 반환한다.
- `claude-reviewer`: Claude CLI가 사용 가능할 때만 Bash로 실행하고 결과를 반환한다.

각 reviewer에게 전달할 지시:

```text
아래 요청과 컨텍스트를 독립적으로 검토하세요.
응답은 사용자 언어로 작성하세요.
수정은 수행하지 말고 분석 결과만 반환하세요.
추가 확인이 필요한 사항은 "추가 확인 필요" 섹션에 적으세요.
결과를 반환한 뒤 세션을 종료하세요.
```

Lead는 reviewer 결과를 받은 뒤 완료된 agent를 종료한다. 완료, 실패, timeout 모두 더 이상 유지하지 않는다.

### fallback: Bash CLI 직접 실행

sub-agent 실행이 불가능하면 Lead가 Bash로 각 CLI를 직접 실행한다. fallback은 기본 실행 전략이 아니라, sub-agent를 사용할 수 없는 환경에서만 사용한다. 가능한 경우 병렬로 실행하되, 출력 수집과 timeout 처리를 명확히 한다.

```bash
which codex 2>/dev/null && echo "CODEX_OK" || echo "CODEX_NOT_FOUND"
which gemini 2>/dev/null && echo "GEMINI_OK" || echo "GEMINI_NOT_FOUND"
which claude 2>/dev/null && echo "CLAUDE_OK" || echo "CLAUDE_NOT_FOUND"
```

## 사전 점검

reviewer 실행 전에 가능한 범위에서 아래 항목을 확인한다. 사전 점검 실패는 전체 중단 사유가 아니라 reviewer별 skip 판단 근거로 사용한다.

| 항목 | 확인 기준 | 실패 시 처리 |
|---|---|---|
| Codex CLI | `which codex` | Codex reviewer skip |
| Gemini CLI | `which gemini` | Gemini reviewer skip |
| Claude CLI | `which claude` | Claude reviewer skip |
| Gemini 인증 | headless 실행 중 인증 프롬프트가 없어야 함 | 로그인 진행 없이 Gemini reviewer skip |
| Claude 토큰/인증 | 토큰 제한이나 인증 실패가 없어야 함 | Claude reviewer skip |
| 실행 권한 | Codex sandbox 오류가 없어야 함 | 권한 상승 1회 재시도 후 실패 시 skip |

## reviewer 실행 규칙

### Codex reviewer

기본 명령:

```bash
codex -a never exec --sandbox read-only -m gpt-5.4 -c 'model_reasoning_effort="xhigh"' "<prompt>"
```

- 명령 자체는 검증된 형식이다.
- Codex 내부 sandbox에서 `Operation not permitted` 또는 app-server 초기화 오류가 발생하면 동일 명령을 권한 상승으로 1회 재시도한다.
- 권한 상승이 거부되거나 재시도도 실패하면 Codex reviewer를 skip한다.

### Gemini reviewer

기본 명령:

```bash
GEMINI_POLICY_ALLOW_READONLY=true gemini -p "<prompt>" -m gemini-3-flash-preview --approval-mode plan -o text 2>/dev/null
```

- 사용자 터미널에서 정상 응답이 확인된 명령이다.
- timeout, 빈 응답, 인증 프롬프트, `FatalCancellationError`가 발생하면 `2>/dev/null`을 제거해 원인을 확인할 수 있다.
- 인증이 필요한 상태면 브라우저 인증을 진행하지 않고 Gemini reviewer를 skip한다.

### Claude reviewer

기본 명령:

```bash
claude -p "<prompt>" --model claude-opus-4-6 --permission-mode dontAsk --output-format text
```

- Claude reviewer는 optional이다.
- 토큰 사용 제한, 인증 실패, CLI 미설치, timeout이 있으면 skip한다.
- 현재 환경에서 Claude 사용이 막힌 경우 검증을 시도하지 않는다.

## timeout 및 실패 처리

| 상황 | 처리 |
|---|---|
| CLI 미설치 | 해당 reviewer skip |
| 인증 필요 | 인증을 진행하지 않고 skip |
| timeout | partial output이 있으면 보존하고 skip 사유 기록 |
| API/model 오류 | 오류 메시지를 요약해 skip 사유 기록 |
| Codex sandbox 오류 | 권한 상승 재시도 후 실패 시 skip |
| 모든 reviewer 실패 | Lead 단독 분석 + 실패 사유 보고 |

권장 timeout은 reviewer당 120초다. 긴 코드 리뷰처럼 요청이 큰 경우 Lead 판단으로 늘릴 수 있다.

## 합성 형식

최종 응답은 아래 구조를 기본으로 한다.

```markdown
## Multi-Check 결과

### 요약 결론
- Lead가 취합한 최종 판단

### AI별 검토 결과
| AI | 상태 | 핵심 판단 | 근거 | 리스크/추가 확인 |
|---|---|---|---|---|
| Lead Codex | 완료 |  |  |  |
| Codex reviewer | 완료/skip |  |  |  |
| Gemini | 완료/skip |  |  |  |
| Claude | 완료/skip |  |  |  |

### 공통 의견
- 여러 reviewer가 동의한 내용

### 충돌/불일치
- reviewer 간 판단 차이
- Lead의 최종 판단 근거

### 보완된 최종안
- 사용자 요청에 대한 개선된 답변, 계획, 체크리스트, 결론

### 추가 확인 필요
- reviewer 또는 Lead가 추가 확인이 필요하다고 본 항목
```

## 종료 정책

- reviewer는 결과 반환 후 즉시 종료한다.
- 추가 확인이 필요해도 대기하지 않는다.
- 추가 확인이 필요한 reviewer는 필요한 정보, 전제, 질문을 결과에 적고 종료한다.
- Lead는 완료된 sub-agent를 닫고, 남은 CLI 프로세스가 없도록 확인한다.
- 후속 질문이나 재검토가 필요하면 Lead가 새 reviewer 요청을 만든다.

## 금지 사항

- 장기 협업용 FE/BE/PO team workflow로 확장하지 않는다.
- reviewer 간 직접 대화를 시도하지 않는다.
- 사용자의 승인 없이 파일 수정, 커밋, 외부 변경을 수행하지 않는다.
- 인증 브라우저를 자동으로 열거나 로그인 절차를 진행하지 않는다.
- 실패한 reviewer 때문에 전체 응답을 중단하지 않는다.
