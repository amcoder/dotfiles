#!/bin/bash
# Claude Code status line: dir | git branch (dirty/clean) | model | context used | rate limit | +/- lines
set -o pipefail

input=$(cat)

# Single jq call to pull everything we need (fast: one process spawn).
# Unit-separator delimiter: tabs are IFS whitespace, so read would collapse empty fields
IFS=$'\x1f' read -r cwd model remaining rl_used lines_added lines_removed <<<"$(jq -r '
  [
    (.workspace.current_dir // .cwd // ""),
    (.model.display_name // ""),
    (.context_window.remaining_percentage // ""),
    (.rate_limits.five_hour.used_percentage // ""),
    (.cost.total_lines_added // ""),
    (.cost.total_lines_removed // "")
  ] | map(tostring) | join("\u001f")
' <<<"$input")"

# --- directory (shortened, ~ for home, ~/projects stripped) ---
dir="${cwd/#$HOME/\~}"
dir="${dir#\~/projects/}"
[ -z "$dir" ] && dir="?"

# --- git branch + dirty/clean indicator (skips optional locks, no network) ---
git_part=""
if [ -n "$cwd" ] && git -C "$cwd" --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
  [ -z "$branch" ] && branch=$(git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
  if [ -n "$branch" ]; then
    if git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null | grep -q .; then
      git_part=$(printf '\033[33m\ue0a0 %s \uf040\033[0m' "$branch")
    else
      git_part=$(printf '\033[32m\ue0a0 %s\033[0m' "$branch")
    fi
  fi
fi

# --- shared usage meter: $1 = percent used -> METER_BAR, METER_USED, METER_COLOR ---
bar_width=10
usage_meter() {
  read -r METER_USED filled <<<"$(awk -v u="$1" -v w="$bar_width" 'BEGIN{
    if (u < 0) u = 0
    if (u > 100) u = 100
    f = int(u * w / 100 + 0.5)
    printf "%.0f %d", u, f
  }')"
  # tr is byte-oriented and corrupts multibyte block chars; build the bar in awk instead
  METER_BAR=$(awk -v f="$filled" -v w="$bar_width" 'BEGIN{for(i=0;i<w;i++) printf (i<f ? "█" : "░")}')
  METER_COLOR='\033[34m'
  if [ "$METER_USED" -gt 80 ]; then
    METER_COLOR='\033[31m'
  elif [ "$METER_USED" -gt 50 ]; then
    METER_COLOR='\033[33m'
  fi
}

# --- context used before compaction (icon + bar + %) ---
ctx_part=""
if [ -n "$remaining" ]; then
  usage_meter "$(awk -v r="$remaining" 'BEGIN{printf "%.2f", 100 - r}')"
  METER_ICON=''
  ctx_part=$(printf "${METER_COLOR}${METER_ICON} %s %s%%\033[0m" "$METER_BAR" "$METER_USED")
fi

# --- 5-hour rate limit used (icon + bar + %) ---
rate_part=""
if [ -n "$rl_used" ]; then
  usage_meter "$rl_used"
  METER_ICON=''
  rate_part=$(printf "${METER_COLOR}${METER_ICON} %s %s%%\033[0m" "$METER_BAR" "$METER_USED")
fi

# --- lines added/removed this session ---
lines_part=""
la="${lines_added:-0}"
lr="${lines_removed:-0}"
if [ "$la" != "0" ] || [ "$lr" != "0" ]; then
  lines_part=$(printf '\033[32m+%s\033[0m \033[31m-%s\033[0m' "$la" "$lr")
fi

dir_part=$(printf '\033[36m\uf07b %s\033[0m' "$dir")
model_part=""
[ -n "$model" ] && model_part=$(printf '\033[35m\U000F06A9 %s\033[0m' "$model")

sep=$(printf '\033[2m\ue0b1\033[0m')

out="$dir_part"
for part in "$git_part" "$model_part" "$ctx_part" "$rate_part" "$lines_part"; do
  [ -n "$part" ] && out="$out $sep $part"
done

printf '%s\n' "$out"
