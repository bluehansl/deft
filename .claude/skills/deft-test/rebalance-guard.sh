#!/usr/bin/env bash
# rebalance-guard — 워커 spawn 과정 동안 Lead pane 비율이 틀어지는 순간을 감지해 즉시 rebalancing.
# 배경: claude Agent tool 워커는 spawn ~1.4초 후 cmux 가 레이아웃을 재계산하며 Lead 를 깎는다(실측).
#   cmux 재계산 자체는 외부에서 못 막으므로, "틀어짐 감지 → 즉시 교정" 워치독으로 사용자 체감 깜빡임 최소화.
#   cmux-rebalancing 자체가 ~3.6초(resize settle) 걸려 깜빡임의 주원인 → 폴링을 빠르게(0.1초) 해
#   틀어진 직후 교정 시작 + 마지막 spawn 후 grace-sec(기본 5초) 추가 감시로 마지막 재계산까지 잡는다.
# 사용: rebalance-guard.sh <workspace-ref> [max-sec] [poll-sec] [lead-min-pct] [grace-sec]
#   <workspace-ref>  대상 워크스페이스 (예: workspace:5)
#   [max-sec]        총 가동 시간(기본 90초 — spawn 과정 커버 후 자동 종료)
#   [poll-sec]       폴링 간격(기본 0.1 — 틀어진 직후 즉시 감지)
#   [lead-min-pct]   Lead 폭이 이 % 미만이면 틀어짐 판정(기본 50 — 2컬럼 목표 60%, 여유 둠)
#   [grace-sec]      "마지막 안정 이후 추가 감시" 윈도(기본 5초). 마지막 교정 후 grace-sec 동안 틀어짐이
#                    없으면 안정으로 보고 종료(= spawn 후 5초 추가 모니터링 보장). max-sec 는 상한.
# 출력: 감지·교정 이벤트만 한 줄씩(조용한 동안은 무출력)
set -u
WS="${1:?usage: rebalance-guard.sh <workspace-ref> [max-sec] [poll-sec] [lead-min-pct] [grace-sec]}"
MAXSEC="${2:-90}"
POLL="${3:-0.1}"
MINPCT="${4:-50}"
GRACE="${5:-5}"
ITERS=$(awk "BEGIN{print int($MAXSEC/$POLL)}")
GRACE_ITERS=$(awk "BEGIN{print int($GRACE/$POLL)}")
DEBOUNCE=0   # rebalancing 후 잠깐 감지 멈춤(settle + 깜빡임 방지)
STABLE=0     # 마지막 교정/안정 이후 무틀어짐 연속 폴 수 — GRACE_ITERS 도달 시 조기 종료
for i in $(seq 1 "$ITERS"); do
  if [ "$DEBOUNCE" -gt 0 ]; then DEBOUNCE=$((DEBOUNCE-1)); sleep "$POLL"; continue; fi
  # Lead(첫 컬럼, 최소 x) 폭 / 컨테이너 폭 비율
  J=$(cmux list-panes --workspace "$WS" --json 2>/dev/null)
  [ -z "$J" ] && { sleep "$POLL"; continue; }
  PCT=$(printf '%s' "$J" | jq -r '
    (.container_frame.width) as $cw
    | ([.panes[]|{x:.pixel_frame.x,w:.pixel_frame.width}]|sort_by(.x)|first) as $lead
    | if $cw>0 and $lead then (($lead.w/$cw)*100|floor) else -1 end' 2>/dev/null)
  NP=$(printf '%s' "$J" | jq -r '.panes|length' 2>/dev/null)
  # 워커가 2개 이상(Lead+워커1+)일 때만 교정 의미 — 단독이면 STABLE 카운트(워커 0이면 grace 종료 안 함)
  if [ "${NP:-1}" -lt 2 ]; then STABLE=0; sleep "$POLL"; continue; fi
  if [ "${PCT:-100}" -ge 0 ] && [ "${PCT:-100}" -lt "$MINPCT" ] 2>/dev/null; then
    TS=$(date '+%H:%M:%S')
    echo "$TS GUARD: Lead ${PCT}% (<${MINPCT}%) — 틀어짐 감지 → rebalancing"
    cmux-rebalancing >/dev/null 2>&1   # 동기 호출(~3.6s) — 반환 시 이미 settle
    LP=$(printf '%s' "$J" | jq -r '[.panes[]|{x:.pixel_frame.x,r:.ref}]|sort_by(.x)|first.r')
    cmux focus-pane --pane "$LP" --workspace "$WS" >/dev/null 2>&1
    STABLE=0          # 틀어짐 발생 → 안정 카운트 리셋
    DEBOUNCE=$(awk "BEGIN{print int(0.5/$POLL)}")   # rebalancing 직후 0.5초만 디바운스(이미 settle됨)
  else
    STABLE=$((STABLE+1))
    # 마지막 안정 이후 grace-sec 동안 무틀어짐 → spawn 완료로 보고 조기 종료(= spawn 후 5초 추가 감시 보장)
    if [ "$STABLE" -ge "$GRACE_ITERS" ]; then
      echo "$(date '+%H:%M:%S') rebalance-guard 안정 종료 (마지막 안정 후 ${GRACE}s 무틀어짐 — Lead ${PCT}%)"
      exit 0
    fi
  fi
  sleep "$POLL"
done
echo "$(date '+%H:%M:%S') rebalance-guard 종료 (max-sec 도달)"
