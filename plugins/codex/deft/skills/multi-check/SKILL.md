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

## 환경 준비 — `cmux-rebalancing` 헬퍼 설치 확인

reviewer spawn 후 pane 비율을 재조정하는 `cmux-rebalancing` 헬퍼가 PATH 에 없으면 plugin 동봉본으로 자동 설치한다.

```bash
if ! command -v cmux-rebalancing >/dev/null 2>&1; then
  SRC=$(ls -1 ~/.codex/plugins/cache/bluehansl-codex/deft/*/bin/cmux-rebalancing 2>/dev/null | sort -V | tail -1)
  [ -z "$SRC" ] && SRC=$(ls -1 ~/.claude/plugins/cache/bluehansl/deft/*/bin/cmux-rebalancing 2>/dev/null | sort -V | tail -1)
  if [ -n "$SRC" ]; then
    mkdir -p ~/.local/bin && cp "$SRC" ~/.local/bin/cmux-rebalancing && chmod +x ~/.local/bin/cmux-rebalancing
    echo "INFO: cmux-rebalancing 자동 설치 완료 (~/.local/bin/)"
  fi
fi
```

## 병렬 실행 전략 — cmux 환경 여부로 분기

```bash
HAVE_CMUX=0
which cmux >/dev/null 2>&1 && cmux identify >/dev/null 2>&1 && HAVE_CMUX=1
```

| 환경 | 실행 전략 | 시각화 |
|---|---|---|
| `HAVE_CMUX=1` | **cmux pane 병렬 (기본)** — reviewer 명령을 pane 쉘에서 실행, 출력을 파일로 tee | 사용자가 reviewer 진행을 pane 으로 관찰 |
| `HAVE_CMUX=0` | Codex sub-agent 병렬 | 호스트 TUI 내 표시만 |

> multi-agent spawn 은 cmux 환경에서 pane 시각화가 기본이다. headless 백그라운드 전용 실행은 cmux 외부에서만.

### cmux 환경 기본: pane 병렬 실행

reviewer 마다 pane 을 분할하고, 그 pane 쉘에서 headless CLI 명령을 실행해 **출력이 pane 에 보이면서 파일로도 수집**되게 한다 (1-shot 이므로 버스·양방향 통신은 불필요).

```bash
OUT_DIR=$(mktemp -d /tmp/multi-check.XXXXXX)

# (1) 첫 reviewer: 우측 분할 → 직후 rebalancing 1회. 이후 reviewer: 직전 pane 아래 분할
SPLIT=$(cmux new-split right --focus false 2>&1)
R1=$(printf '%s' "$SPLIT" | grep -oE 'surface:[0-9]+' | head -1)
command -v cmux-rebalancing >/dev/null 2>&1 && cmux-rebalancing
# 두 번째부터: cmux new-split down --surface "$R1" --focus false ...

# (2) pane 쉘 readiness 가드 — cmux 는 화면 렌더 시 쉘을 기동(lazy-init). 미기동 pane 에 send 하면 유실
cmux send --surface "$R1" "touch $OUT_DIR/.ready-r1" && cmux send-key --surface "$R1" Enter
for _ in $(seq 1 15); do [ -f "$OUT_DIR/.ready-r1" ] && break; sleep 1; done

# (3) reviewer 명령 실행 — 출력 tee + 완료 마커 (명령은 한 줄로 — pane 쉘에서 \n 은 즉시 실행)
PROMPT_FILE="$OUT_DIR/prompt.txt"   # 검토 prompt 는 파일로 저장 (줄바꿈 안전)
cmux send --surface "$R1" "GEMINI_POLICY_ALLOW_READONLY=true gemini -p \"\$(cat $PROMPT_FILE)\" -m gemini-3-flash-preview --approval-mode plan -o text 2>&1 | tee $OUT_DIR/gemini.out; touch $OUT_DIR/gemini.done"
cmux send-key --surface "$R1" Enter

# (4) 수집 — 전 reviewer 의 .done 마커 폴링 (reviewer 당 timeout 120s, 미완료는 partial 보존 + skip)
for _ in $(seq 1 60); do
  ls "$OUT_DIR"/*.done >/dev/null 2>&1 && [ "$(ls $OUT_DIR/*.done | wc -l)" -ge "$REVIEWER_COUNT" ] && break
  sleep 2
done
```

- Codex reviewer 는 pane 에서 `"$CODEX_CLI" -a never exec --sandbox read-only -m gpt-5.5 ... | tee $OUT_DIR/codex.out; touch $OUT_DIR/codex.done` 로 동일 패턴.
- Claude reviewer 도 동일 (`claude -p ... | tee ...`).
- **quoting 안전 (권장)**: 긴 one-line 명령의 escaping 오류를 피하려면 reviewer 별 runner script 를 생성하고 pane 에는 `sh $OUT_DIR/run-<reviewer>.sh` 한 줄만 send 한다.
- **마무리 정렬 + focus 복원 (전 reviewer 분할 완료 후 1회)** — 순차 down 분할은 row 높이가 1/2·1/4·1/4 로 남고(실측), `--focus false` 에도 focus 가 마지막 pane 으로 이동할 수 있다:

```bash
command -v cmux-rebalancing >/dev/null 2>&1 && cmux-rebalancing   # row 균등화
LEAD_PANE=$(cmux identify 2>/dev/null | jq -r '.caller.pane_ref')
cmux focus-pane --pane "$LEAD_PANE" 2>/dev/null || true   # Lead focus 복원 (focus-surface 명령은 없음 — focus-pane 이 정답)
```
- **결과 수집·취합 완료 후 reviewer pane 을 닫는다 — 소유권 안전 (파괴 행위)**: 본 실행이 분할해 추적한 reviewer surface(`$R1`/`$R2`/…)**만** 닫는다(`cmux close-surface --surface "$R1"` …). cmux 는 다중 워크스페이스·세션 환경 — 다른 세션/워크스페이스 pane·`surface:N` 을 추측으로 닫지 말 것(**전체 surface 순회·와일드카드 close 금지**). 출력은 tee 파일로 보존되므로 관찰 손실 없음. close-surface 가 못 닫는 orphan 이면 그 reviewer pane 의 tmux id 로만 `tmux kill-pane -t <id>` (전체 tmux 순회·다른 세션 절대 금지). 닫은 뒤 `cmux-rebalancing` 1회로 복원.

### cmux 외부: Codex sub-agent 병렬 실행

cmux 외부에서는 sub-agent 로 reviewer 별 one-shot 작업을 병렬 실행한다.

- `codex-reviewer`: Codex CLI를 실행하거나 독립 Codex 관점으로 분석한다.
- `gemini-reviewer`: Bash로 Gemini CLI를 실행하고 결과를 반환한다.
- `claude-reviewer`: Claude CLI가 사용 가능할 때만 Bash로 실행하고 결과를 반환한다.

각 reviewer에게 전달할 지시 (pane/sub-agent 공통):

```text
아래 요청과 컨텍스트를 독립적으로 검토하세요.
응답은 사용자 언어로 작성하세요.
수정은 수행하지 말고 분석 결과만 반환하세요.
추가 확인이 필요한 사항은 "추가 확인 필요" 섹션에 적으세요.
결과를 반환한 뒤 세션을 종료하세요.
```

Lead는 reviewer 결과를 받은 뒤 완료된 agent를 종료한다. 완료, 실패, timeout 모두 더 이상 유지하지 않는다.

### 첫 pane 분할 직후 비율 재조정 (Lead 직접 호출, 1회)

**첫 reviewer pane 분할이 끝난 직후, Lead 가 직접 `cmux-rebalancing` 을 한 번 호출**해 좌 Lead / 우 reviewer 컬럼 비율을 정책대로 잡는다. 마지막 reviewer 까지 기다리지 않는다.

```bash
# Lead pane 에서 직접 실행 — 좌→우: 2컬럼=60:40 / 3컬럼=40:30:30 / 4컬럼=25:25:25:25 / 5+=균등
command -v cmux-rebalancing >/dev/null 2>&1 && cmux-rebalancing
# 사용자 명시 비율 (예시): cmux-rebalancing 7:3
```

> **호출 규칙**: spawn(또는 재spawn)으로 pane 구성이 바뀔 때마다 그 spawn 묶음 직후 1회 호출 — 첫 spawn 만이 아니다. cmux 외부 실행 시 자동 skip.

### fallback: Bash CLI 직접 실행

pane(cmux)·sub-agent 둘 다 사용할 수 없으면 Lead가 Bash로 각 CLI를 직접 실행한다. fallback은 기본 실행 전략이 아니다. 가능한 경우 병렬로 실행하되, 출력 수집과 timeout 처리를 명확히 한다.

```bash
# Codex reviewer는 claudex(우선) 또는 codex 중 하나라도 있으면 OK
(which claudex 2>/dev/null || which codex 2>/dev/null) >/dev/null \
  && echo "CODEX_OK" || echo "CODEX_NOT_FOUND"
which gemini 2>/dev/null && echo "GEMINI_OK" || echo "GEMINI_NOT_FOUND"
which claude 2>/dev/null && echo "CLAUDE_OK" || echo "CLAUDE_NOT_FOUND"
```

참고: Codex reviewer는 `claudex`가 설치돼 있으면 `claudex`를 우선 사용하고, 없으면 `codex`로 fallback한다. 옵션·플래그·모델·reasoning 설정은 동일하며 진입점 이름만 다르다.

## 사전 점검

reviewer 실행 전에 가능한 범위에서 아래 항목을 확인한다. 사전 점검 실패는 전체 중단 사유가 아니라 reviewer별 skip 판단 근거로 사용한다.

| 항목 | 확인 기준 | 실패 시 처리 |
|---|---|---|
| Codex CLI | `which claudex \|\| which codex` (claudex 우선) | 둘 다 없으면 Codex reviewer skip |
| Gemini CLI | `which gemini` | Gemini reviewer skip |
| Claude CLI | `which claude` | Claude reviewer skip |
| Gemini 인증 | headless 실행 중 인증 프롬프트가 없어야 함 | 로그인 진행 없이 Gemini reviewer skip |
| Claude 토큰/인증 | 토큰 제한이나 인증 실패가 없어야 함 | Claude reviewer skip |
| 실행 권한 | Codex sandbox 오류가 없어야 함 | 권한 상승 1회 재시도 후 실패 시 skip |

## reviewer 실행 규칙

### Codex reviewer

CLI 선택 (claudex 우선, 없으면 codex):

```bash
if command -v claudex >/dev/null 2>&1; then CODEX_CLI=claudex
elif command -v codex >/dev/null 2>&1; then CODEX_CLI=codex
else CODEX_CLI=""; fi
```

기본 명령 (`$CODEX_CLI`는 `claudex` 또는 `codex`):

```bash
"$CODEX_CLI" -a never exec --sandbox read-only -m gpt-5.5 -c 'model_reasoning_effort="xhigh"' "<prompt>"
```

- 명령 자체는 검증된 형식이며, claudex는 codex와 옵션·플래그가 완전 호환된다.
- 둘 다 설치되어 있지 않으면 Codex reviewer를 skip한다.
- 내부 sandbox에서 `Operation not permitted` 또는 app-server 초기화 오류가 발생하면 동일 명령을 권한 상승으로 1회 재시도한다.
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
claude -p "<prompt>" --model "$(deft-model claude 2>/dev/null||echo opus)" --permission-mode dontAsk --output-format text
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
