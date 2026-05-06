#!/usr/bin/env bash

input=$(cat)

# --- ANSI helpers ---
ESC=$'\033'
DARKGRAY="${ESC}[38;5;249m"
BRIGHT_WHITE="${ESC}[97m"
RESET="${ESC}[0m"

# --- Parse fields ---
cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')
effort=$(echo "$input" | jq -r '.effort.level // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# --- Icons (bash 3.2 compatible via printf \x bytes) ---
ICON_FOLDER=$(printf '\xf0\x9f\x93\x81')
ICON_BRANCH="${BRIGHT_WHITE}$(printf '\xee\x9c\xa5')${RESET}"
_ROBOT_B64_FILE="$HOME/.claude/icons/robot.b64"
if [ -r "$_ROBOT_B64_FILE" ]; then
  ICON_MODEL=$(printf '\033]1337;File=name=cm9ib3QucG5n;inline=1;height=1;preserveAspectRatio=1:%s\a' "$(cat "$_ROBOT_B64_FILE")")
else
  ICON_MODEL=$(printf '\xf0\x9f\xa4\x96')
fi
ICON_CTX="${ESC}[38;2;0;210;106m$(printf '\xe2\x97\x8f')${RESET}"

# --- Folder & Git branch ---
folder=$(basename "$cwd")
branch=""
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
fi

# --- Progress bar (10 chars wide) ---
BAR_FILL_COLOR="${ESC}[38;2;175;215;255m"
BAR_EMPTY_COLOR="${ESC}[38;2;73;87;103m"
ctx_text=""
if [ -n "$used_pct" ]; then
  filled=$(echo "$used_pct" | awk '{n = int(($1 / 100) * 10 + 0.5); if(n>10) n=10; printf "%d", n}')
  empty=$((10 - filled))
  bar_filled=""
  bar_empty=""
  for i in $(seq 1 "$filled"); do bar_filled="${bar_filled}█"; done
  for i in $(seq 1 "$empty");  do bar_empty="${bar_empty}█"; done
  bar_inner="${BAR_FILL_COLOR}${bar_filled}${RESET}${BAR_EMPTY_COLOR}${bar_empty}${RESET}"
  pct_label=$(echo "$used_pct" | awk '{printf "%.0f", $1}')
  ctx_text="${ICON_CTX} ${DARKGRAY}ctx │${bar_inner}${DARKGRAY}│ ${pct_label}%${RESET}"
fi

# --- Model + effort ---
model_text=""
if [ -n "$model" ]; then
  if [ -n "$effort" ]; then
    model_text="${ICON_MODEL} ${DARKGRAY}${model} : ${effort}${RESET}"
  else
    model_text="${ICON_MODEL} ${DARKGRAY}${model}${RESET}"
  fi
fi

# --- Assemble segments ---
segments=()
[ -n "$folder" ]     && segments+=("${ICON_FOLDER} ${DARKGRAY}$(echo "$folder" | tr '[:lower:]' '[:upper:]')${RESET}")
[ -n "$branch" ]     && segments+=("${ICON_BRANCH} ${DARKGRAY}${branch}${RESET}")
[ -n "$model_text" ] && segments+=("$model_text")
[ -n "$ctx_text" ]   && segments+=("$ctx_text")

# --- Visible length ---
visible_len() {
  local s="$1"
  local plain
  plain=$(printf '%s' "$s" \
    | sed 's/\x1b\][^\x07]*\x07//g' \
    | sed 's/\x1b\[[0-9;]*m//g;s/\x1b\[[0-9;]*[a-zA-Z]//g')
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "
import unicodedata, sys
s = sys.argv[1]
w = 0
for c in s:
    cp = ord(c)
    if 0xFE00 <= cp <= 0xFE0F or 0xE0100 <= cp <= 0xE01EF or cp in (0x200C, 0x200D):
        continue
    w += 2 if unicodedata.east_asian_width(c) in ('W', 'F') else 1
print(w)
" "$plain"
  else
    echo ${#plain}
  fi
}

# --- Terminal width ---
term_width="${COLUMNS:-}"
if [ -z "$term_width" ] || [ "$term_width" -lt 20 ] 2>/dev/null; then
  term_width=$(tput cols 2>/dev/null)
fi
if [ -z "$term_width" ] || [ "$term_width" -lt 20 ] 2>/dev/null; then
  term_width=120
fi

# --- Justify ---
n=${#segments[@]}
[ "$n" -eq 0 ] && exit 0

total_seg_len=0
for seg in "${segments[@]}"; do
  total_seg_len=$((total_seg_len + $(visible_len "$seg")))
done

gaps=$((n - 1))
if [ "$gaps" -eq 0 ]; then
  printf '%s' "${segments[0]}"
  exit 0
fi

min_gap=3
min_total=$(( total_seg_len + gaps * min_gap ))
if [ "$term_width" -lt "$min_total" ]; then
  out="${segments[0]}"
  for i in $(seq 1 $((n - 1))); do out="${out} | ${segments[$i]}"; done
  printf '%s' "$out"
  exit 0
fi

avail=$((term_width - total_seg_len))
inflated_avail=$(echo "$avail $gaps" | awk '{printf "%d", int($1 * 1.2)}')
base_gap=$(( inflated_avail / gaps ))
leftover=$(( inflated_avail - base_gap * gaps ))

if [ "$base_gap" -lt 1 ]; then
  out="${segments[0]}"
  for i in $(seq 1 $((n - 1))); do out="${out} | ${segments[$i]}"; done
  printf '%s' "$out"
  exit 0
fi

out="${segments[0]}"
for i in $(seq 1 $((n - 1))); do
  extra=0
  [ "$i" -le "$leftover" ] && extra=1
  gap_size=$((base_gap + extra))
  padding=$(printf '%*s' "$gap_size" '')
  out="${out}${padding}${segments[$i]}"
done

printf '%s' "$out"
