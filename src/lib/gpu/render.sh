#!/usr/bin/env bash
#
# render.sh: map cached GPU values to icons, colors, and formatted text.
#
# The metric_* helpers are generic over an option prefix and default thresholds,
# so the three GPU metrics (load, temperature, memory) share one implementation.

[[ -n "${_GPU_REVAMPED_RENDER_LOADED:-}" ]] && return 0
_GPU_REVAMPED_RENDER_LOADED=1

_GPU_RENDER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${_GPU_RENDER_DIR}/../tmux/tmux-ops.sh"

# _gpu_level VALUE MEDIUM HIGH -> low|medium|high by integer thresholds.
_gpu_level() {
  local v="${1%%.*}" med="${2}" high="${3}"
  [[ "${v}" =~ ^-?[0-9]+$ ]] || v=0
  if (( v >= high )); then
    echo "high"
  elif (( v >= med )); then
    echo "medium"
  else
    echo "low"
  fi
}

_gpu_c_to_f() {
  [[ "${1}" =~ ^-?[0-9]+$ ]] || { echo ""; return 0; }
  LC_ALL=C awk -v c="${1}" 'BEGIN { printf "%.0f", (c * 9 / 5) + 32 }'
}

# metric_value RAW FMT_OPTION DEFAULT_FMT
metric_value() {
  local raw="${1}"
  [[ -z "${raw}" ]] && { echo ""; return 0; }
  local fmt
  fmt=$(get_tmux_option "${2}" "${3}")
  # shellcheck disable=SC2059
  printf "${fmt}" "${raw}"
}

# metric_level RAW PREFIX DEF_MEDIUM DEF_HIGH
metric_level() {
  _gpu_level "${1:-0}" \
    "$(get_tmux_option "@${2}_medium_thresh" "${3}")" \
    "$(get_tmux_option "@${2}_high_thresh" "${4}")"
}

# metric_icon RAW PREFIX DEF_MEDIUM DEF_HIGH DEF_LOW_ICON DEF_MED_ICON DEF_HIGH_ICON
metric_icon() {
  [[ -z "${1}" ]] && { echo ""; return 0; }
  case "$(metric_level "${1}" "${2}" "${3}" "${4}")" in
    high)   get_tmux_option "@${2}_high_icon" "${7}" ;;
    medium) get_tmux_option "@${2}_medium_icon" "${6}" ;;
    *)      get_tmux_option "@${2}_low_icon" "${5}" ;;
  esac
}

# metric_color RAW PREFIX DEF_MEDIUM DEF_HIGH KIND
metric_color() {
  [[ -z "${1}" ]] && { echo ""; return 0; }
  get_tmux_option "@${2}_$(metric_level "${1}" "${2}" "${3}" "${4}")_${5}_color" ""
}

# gpu_render_freq RAW_MHZ -> formatted frequency, empty when zero or unset.
gpu_render_freq() {
  local raw="${1}"
  [[ -z "${raw}" || "${raw}" == "0" ]] && { echo ""; return 0; }
  local fmt
  fmt=$(get_tmux_option "@gpu_revamped_freq_format" "%sMHz")
  # shellcheck disable=SC2059
  printf "${fmt}" "${raw}"
}

# gpu_temp_value RAW_CELSIUS -> formatted temperature honoring the unit option.
gpu_temp_value() {
  local raw="${1}"
  [[ -z "${raw}" ]] && { echo ""; return 0; }
  local unit value
  unit=$(get_tmux_option "@gpu_revamped_temp_unit" "C")
  if [[ "${unit}" == "F" ]]; then
    value=$(_gpu_c_to_f "${raw}")
  else
    value="${raw}"
  fi
  local fmt
  fmt=$(get_tmux_option "@gpu_revamped_temp_format" "%s°${unit}")
  # shellcheck disable=SC2059
  printf "${fmt}" "${value}"
}

# _mib_to_human MIB -> a GiB string like "8.0G" or "24G", empty for junk.
_mib_to_human() {
  [[ "${1}" =~ ^[0-9]+$ ]] || { echo ""; return 0; }
  LC_ALL=C awk -v m="${1}" 'BEGIN { g = m / 1024; if (g >= 10) printf "%.0fG", g; else printf "%.1fG", g }'
}

# gram_abs_value USED_MIB TOTAL_MIB -> "18G / 24G", empty when either is unset.
gram_abs_value() {
  local used="${1}" total="${2}"
  [[ "${used}" =~ ^[0-9]+$ && "${total}" =~ ^[0-9]+$ && "${total}" -gt 0 ]] || { echo ""; return 0; }
  local fmt
  fmt=$(get_tmux_option "@gpu_revamped_gram_abs_format" "%s / %s")
  # shellcheck disable=SC2059
  printf "${fmt}" "$(_mib_to_human "${used}")" "$(_mib_to_human "${total}")"
}

export -f _gpu_level
export -f _gpu_c_to_f
export -f metric_value
export -f metric_level
export -f metric_icon
export -f metric_color
export -f gpu_render_freq
export -f gpu_temp_value
export -f _mib_to_human
export -f gram_abs_value
