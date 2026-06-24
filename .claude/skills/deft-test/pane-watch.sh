#!/usr/bin/env bash
# pane-watch — workspace pane 구성·사이즈를 0.1초 단위로 폴링, 변화 시에만 한 줄 emit.
# 용도: multi-round 워커 spawn 중 pane 분할 방향·컬럼 증식·크기 변동을 프레임 단위 관찰.
# 사용: pane-watch.sh <workspace-ref> [max-iter] [interval-sec]
#   예: pane-watch.sh workspace:5 600 0.1   (0.1초 × 600 = 60초)
# 출력(변화 시만): <ts> panes=N | <ref>:x,y,wxh | ...   (x오름차순 → 좌→우 컬럼 순)
set -u
WS="${1:?usage: pane-watch.sh <workspace-ref> [max-iter] [interval]}"
MAX="${2:-600}"
INT="${3:-0.1}"
PREV=""
for i in $(seq 1 "$MAX"); do
  # list-panes --json → 각 pane 을 x오름차순으로 "ref:x,y,WxH" 직렬화. container 폭도 포함.
  CUR=$(cmux list-panes --workspace "$WS" --json 2>/dev/null | jq -r '
    (.container_frame|"cont=\(.width)x\(.height)") as $c
    | [$c] + ([.panes[]? | {r:.ref, x:.pixel_frame.x, y:.pixel_frame.y, w:.pixel_frame.width, h:.pixel_frame.height}]
              | sort_by(.x, .y) | map("\(.r):\(.x),\(.y),\(.w)x\(.h)"))
    | join(" | ")' 2>/dev/null)
  [ -z "$CUR" ] && CUR="(빈 결과/명령 실패)"
  if [ "$CUR" != "$PREV" ]; then
    # 변화 발생 → emit (밀리초 타임스탬프)
    TS=$(date '+%H:%M:%S').$(printf '%03d' $(( $(date '+%N' 2>/dev/null | sed 's/^0*//' | cut -c1-3 2>/dev/null || echo 0) )) 2>/dev/null)
    N=$(printf '%s' "$CUR" | grep -oE 'pane:[0-9]+' | wc -l | tr -d ' ')
    echo "$TS panes=$N | $CUR"
    PREV="$CUR"
  fi
  sleep "$INT"
done
echo "$(date '+%H:%M:%S') pane-watch 종료 (max-iter 도달)"
