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

## 환경 준비 — `deft-bin-sync` 로 헬퍼 일원 동기

reviewer spawn 후 pane 비율을 재조정하는 `cmux-rebalancing` 등 deft 헬퍼를 **deft-bin-sync 단일 도구로 갱신형 동기**한다(codex-1.18.0~). 종전 개별 `if ! command -v`(없으면 설치)는 `~/.local/bin` 구버전 잔재를 plugin update 후에도 갱신 못 하던 결함이 있어 제거했다. deft-bin-sync 는 캐시 `sort -V tail` 최신본과 `cmp` 해 다르면 cp → 항상 최신.

```bash
DEFT_SYNC_SRC=$(ls -1 ~/.codex/plugins/cache/bluehansl-codex/deft/*/bin/deft-bin-sync 2>/dev/null | sort -V | tail -1)
[ -z "$DEFT_SYNC_SRC" ] && DEFT_SYNC_SRC=$(ls -1 ~/.claude/plugins/cache/bluehansl/deft/*/bin/deft-bin-sync 2>/dev/null | sort -V | tail -1)
if [ -n "$DEFT_SYNC_SRC" ]; then
  mkdir -p ~/.local/bin && cp "$DEFT_SYNC_SRC" ~/.local/bin/deft-bin-sync && chmod +x ~/.local/bin/deft-bin-sync
  deft-bin-sync   # cmux-rebalancing·deft-model 등 전체 헬퍼 갱신형 동기
  # cmux gap-fill 보강 — orca 모드(ORCA_* 존재)는 불요(cmux CLI 자체를 안 씀. shim 도 orca 가드 내장)
  [ -n "${ORCA_WORKTREE_ID:-}${ORCA_TERMINAL_HANDLE:-}" ] || command -v cmux >/dev/null 2>&1 || deft-bin-sync cmux 2>/dev/null
else
  echo "WARN: deft-bin-sync 미발견(구버전 캐시) — 헬퍼 자동 동기 비활성"
fi
```

## 병렬 실행 전략 — 환경 판정으로 분기 (orca/cmux/none)

```bash
# cmux gap-fill(deft-cmux-shim→~/.local/bin/cmux)은 위 환경 준비의 deft-bin-sync 가 처리 — 여기선 판정만.
# ⚠️ 판정 순서 필수 — ORCA 먼저. Orca 터미널 안에서도 cmux CLI 가 소켓으로 **별도 실행 중인 cmux 앱**에
#    연결되어 정상 응답하므로(실측 — 조용한 오발사), cmux identify 성공을 먼저 보면 orca 에서 오판된다.
if [ -n "${ORCA_WORKTREE_ID:-}" ] || [ -n "${ORCA_TERMINAL_HANDLE:-}" ]; then
  DEFT_ENV=orca
elif which cmux >/dev/null 2>&1 && cmux identify >/dev/null 2>&1; then
  DEFT_ENV=cmux
else
  DEFT_ENV=none
fi
echo "deft 환경: $DEFT_ENV"
```

| 환경 | 실행 전략 | 시각화 |
|---|---|---|
| `DEFT_ENV=cmux` | **cmux pane 병렬 (기본)** — reviewer 명령을 pane 쉘에서 실행, 출력을 파일로 tee | 사용자가 reviewer 진행을 pane 으로 관찰 |
| `DEFT_ENV=orca` | **orca pane 병렬** — `orca terminal split --command` 원샷으로 reviewer 실행(아래 🟠). cmux CLI 호출 전면 금지(오발사) | pane 관찰 동일 (비율 조정만 불가 — resize CLI 미지원, UI 드래그) |
| `DEFT_ENV=none` | Codex sub-agent 병렬 | 호스트 TUI 내 표시만 |

> multi-agent spawn 은 pane 환경(cmux/orca)에서 pane 시각화가 기본이다. headless 백그라운드 전용 실행은 pane 환경 외부에서만.

### cmux 환경 기본: pane 병렬 실행

reviewer 마다 pane 을 분할하고, 그 pane 쉘에서 headless CLI 명령을 실행해 **출력이 pane 에 보이면서 파일로도 수집**되게 한다 (1-shot 이므로 버스·양방향 통신은 불필요).

> 🟠 **orca 모드**: 아래 (1)~(3)을 reviewer 별 **원샷 하나로 대체** — 분할·readiness·send 부팅이 전부 불요(`--command` 가 분할과 실행을 원자적으로 수행, 실측):
>
> ```bash
> # runner script 패턴(quoting 안전 권장)과 결합 — reviewer 명령을 스크립트로 저장 후 원샷 실행
> # direction 은 분할선 방향(실화면 실측 — 가이드 문구와 반대): vertical=Lead 우측(좌우), horizontal=직전 pane 아래(상하)
> OUT=$(orca terminal split --terminal "${PREV_HANDLE:-$ORCA_TERMINAL_HANDLE}" \
>       --direction $([ -n "${PREV_HANDLE:-}" ] && echo horizontal || echo vertical) \
>       --command "sh $OUT_DIR/run-gemini.sh" --json)
> R1_HANDLE=$(printf '%s' "$OUT" | jq -r '.result.split.handle // empty'); PREV_HANDLE="$R1_HANDLE"
> ```
>
> (4) 수집(`deft-review status` 폴링)은 파일 기반이라 동일. rebalancing·focus 복원은 skip(resize CLI 미지원 — 비율은 UI 드래그 안내). 정리는 추적한 handle 로만 `orca terminal close --terminal "$R1_HANDLE"`.

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

# (3) reviewer 명령 실행 — **deft-review 단일 헬퍼** (Claude 측과 같은 완료 판정 규약 — 근거 R-19)
#     ⚠️ raw CLI 를 직접 send 하지 말 것. 종전 `CMD | tee out; touch done` 은 ① `;` 라 CLI 실패와 무관하게
#     .done 이 생기고 ② 파이프 exit code 가 tee 것이라(PIPESTATUS 미사용) **실패를 완료로 오판**했다.
#     deft-review 는 job dir 에 exit_code 를 남기므로 성공·실패가 확정 구분된다.
PROMPT_FILE="$OUT_DIR/prompt.txt"   # 검토 prompt 는 파일로 저장 (줄바꿈 안전)
JOB_G="$OUT_DIR/job-gemini"         # job dir 을 미리 지정 → 폴링 대상이 확정적
cmux send --surface "$R1" "deft-review --job-dir $JOB_G gemini < $PROMPT_FILE > $OUT_DIR/gemini.out 2>&1"
cmux send-key --surface "$R1" Enter

# (4) 수집 — 전 reviewer job 의 `deft-review status` 폴링 (reviewer 당 timeout 600s)
#     ⚠️ 120s 로 두지 말 것 — gpt-5.5 xhigh 로 수 KB 프롬프트를 검토하면 3~10분이 정상이라
#     짧은 질문에서만 동작하고 스킬 본래 용도(설계·코드 교차검증)에서는 항상 미완료가 된다 (근거: R-18).
#     ⚠️ 출력 파일 크기·mtime 으로 완료를 판정하지 말 것 — 긴 추론 침묵과 구분되지 않는다 (근거: R-19).
for _ in $(seq 1 300); do
  DONE=0
  for J in "$OUT_DIR"/job-*; do
    [ -d "$J" ] || continue
    case "$(deft-review status "$J" 2>/dev/null)" in
      EXIT\ *|CANCELLED|DIED) DONE=$((DONE+1)) ;;
    esac
  done
  [ "$DONE" -ge "$REVIEWER_COUNT" ] && break
  sleep 2
done
# 엔진별 성패 판정: `EXIT 0` 만 결과로 취급. 그 외(`EXIT n≠0` / `CANCELLED` / `DIED`)는 실패로 skip 하고 사유를 기록한다.
#   ⚠️ 취소된 job 은 CLI 가 SIGTERM 을 graceful 처리해 내부 rc=0 이어도 `CANCELLED` 로 확정된다(실측 2026-09-15).
#   출력 파일을 취합할 때 `DEFT_REVIEW_JOB=`·`__DEFT_REVIEW_EXIT__` 줄은 제어 신호이니 본문에서 제외한다.
for J in "$OUT_DIR"/job-*; do
  [ -d "$J" ] && echo "$(cat "$J/engine" 2>/dev/null): $(deft-review status "$J")"
done
```

- Codex·Claude reviewer 도 **동일 패턴** — `deft-review --job-dir $OUT_DIR/job-<engine> <engine> < $PROMPT_FILE > $OUT_DIR/<engine>.out 2>&1` 한 줄. CLI 선택(claudex 우선)·플래그·모델·`--skip-git-repo-check`·`--skip-trust` 는 헬퍼가 소유하므로 pane 에 구현코드를 노출하지 않는다.
- **완료 판정은 `deft-review status` 또는 출력 파일 마지막 줄의 `__DEFT_REVIEW_EXIT__:<rc>:<nonce>`** 로만 한다. `.done` 마커 방식은 제거됐다(위 사유).
- **폴링 예산(600s) 초과 시**: reviewer 는 **독립 pane 프로세스**라 폴링을 멈춰도 계속 실행되고 출력 파일은 나중에 완성된다. pane 을 닫지 말고 `partial` 로 취합한 뒤 "해당 엔진은 아직 실행 중 — `$OUT_DIR/<engine>.out`, job `$OUT_DIR/job-<engine>`" 을 명시한다. (Claude 측의 `TIMEOUT_PARTIAL` 조기 종료 사고는 이 구조 덕에 포트에서는 발생하지 않는다 — 근거: R-18)
- **정리가 필요하면 `deft-review cancel $OUT_DIR/job-<engine>`** — 프로세스 그룹째 SIGTERM→SIGKILL 로 고아 없이 정리한다. raw `kill` 을 쓰지 않는다 (근거: R-19).
- **quoting 안전 (권장)**: 긴 one-line 명령의 escaping 오류를 피하려면 reviewer 별 runner script 를 생성하고 pane 에는 `sh $OUT_DIR/run-<reviewer>.sh` 한 줄만 send 한다.
- **마무리 정렬 + focus 복원 (전 reviewer 분할 완료 후 1회)** — 순차 down 분할은 row 높이가 1/2·1/4·1/4 로 남고(실측), `--focus false` 에도 focus 가 마지막 pane 으로 이동할 수 있다:

```bash
command -v cmux-rebalancing >/dev/null 2>&1 && cmux-rebalancing   # row 균등화
LEAD_PANE=$(cmux identify 2>/dev/null | jq -r '.caller.pane_ref')
cmux focus-pane --pane "$LEAD_PANE" 2>/dev/null || true   # Lead focus 복원 (focus-surface 명령은 없음 — focus-pane 이 정답)
```
- **결과 수집·취합 완료 후 reviewer pane 을 닫는다 — 소유권 안전 (파괴 행위)**: 본 실행이 분할해 추적한 reviewer surface(`$R1`/`$R2`/…)**만** 닫는다(`cmux close-surface --surface "$R1"` …). cmux 는 다중 워크스페이스·세션 환경 — 다른 세션/워크스페이스 pane·`surface:N` 을 추측으로 닫지 말 것(**전체 surface 순회·와일드카드 close 금지**). 출력은 tee 파일로 보존되므로 관찰 손실 없음. close-surface 가 못 닫는 orphan 이면 그 reviewer pane 의 tmux id 로만 `tmux kill-pane -t <id>` (전체 tmux 순회·다른 세션 절대 금지). 닫은 뒤 `cmux-rebalancing` 1회로 복원.

### pane 환경 외부(`DEFT_ENV=none`): Codex sub-agent 병렬 실행

pane 환경(cmux/orca) 외부에서는 sub-agent 로 reviewer 별 one-shot 작업을 병렬 실행한다.

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

> **호출 규칙**: spawn(또는 재spawn)으로 pane 구성이 바뀔 때마다 그 spawn 묶음 직후 1회 호출 — 첫 spawn 만이 아니다. cmux 모드가 아니면(orca/none) 자동 skip — orca 는 resize CLI 미지원이라 호출돼도 bin 가드가 no-op(비율은 UI 드래그 안내).

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
deft-review --job-dir "$OUT_DIR/job-codex" codex < "$PROMPT_FILE"
```

- 명령 자체는 검증된 형식이며, claudex는 codex와 옵션·플래그가 완전 호환된다.
- 둘 다 설치되어 있지 않으면 Codex reviewer를 skip한다.
- 내부 sandbox에서 `Operation not permitted` 또는 app-server 초기화 오류가 발생하면 동일 명령을 권한 상승으로 1회 재시도한다.
- 권한 상승이 거부되거나 재시도도 실패하면 Codex reviewer를 skip한다.

### Gemini reviewer

기본 명령:

```bash
deft-review --job-dir "$OUT_DIR/job-gemini" gemini < "$PROMPT_FILE"
```

- 사용자 터미널에서 정상 응답이 확인된 명령이다.
- stderr 는 억제하지 않는다 — timeout·빈 응답·인증 프롬프트·`FatalCancellationError` 의 원인이 그대로 보인다. 종전 `2>/dev/null` 은 잡음과 함께 실패 원인까지 삼켰다(사고 2026-09-07, 근거: R-18).
- 인증이 필요한 상태면 브라우저 인증을 진행하지 않고 Gemini reviewer를 skip한다.

### Claude reviewer

기본 명령:

```bash
deft-review --job-dir "$OUT_DIR/job-claude" claude < "$PROMPT_FILE"
```

- Claude reviewer는 optional이다.
- 토큰 사용 제한, 인증 실패, CLI 미설치, timeout이 있으면 skip한다.
- 현재 환경에서 Claude 사용이 막힌 경우 검증을 시도하지 않는다.

## timeout 및 실패 처리

| 상황 | 처리 |
|---|---|
| CLI 미설치 | 해당 reviewer skip |
| 인증 필요 | 인증을 진행하지 않고 skip |
| timeout | **pane 프로세스는 계속 살아 있다** — pane 을 닫지 말고 partial output 을 보존한 뒤 skip 사유와 출력 파일 경로를 기록한다. 나중에 `tee` 파일이 완성된다 (근거: R-18) |
| API/model 오류 | 오류 메시지를 요약해 skip 사유 기록 |
| Codex sandbox 오류 | 권한 상승 재시도 후 실패 시 skip |
| 모든 reviewer 실패 | Lead 단독 분석 + 실패 사유 보고 |

권장 timeout은 reviewer당 **600초**다 — `gpt-5.5` xhigh 로 수 KB 프롬프트를 검토하면 3~10분이 정상이라 120초로 두면 스킬의 본래 용도(설계·코드 교차검증)에서 항상 미완료가 된다(근거: R-18). 더 큰 요청은 Lead 판단으로 늘릴 수 있다.

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
