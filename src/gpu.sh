#!/usr/bin/env bash
#
# gpu.sh: command dispatcher for tmux-gpu-revamped.
#
# Usage:
#   gpu.sh gpu_percentage | gpu_icon | gpu_fg_color | gpu_bg_color
#   gpu.sh gpu_temp | gpu_temp_icon | gpu_temp_fg_color | gpu_temp_bg_color
#   gpu.sh gpu_freq | gpu_graph
#   gpu.sh gram_percentage | gram_icon | gram_fg_color | gram_bg_color | gram_used
#   gpu.sh gpu_power | gpu_power_pct | gpu_fan
#   gpu.sh gpu_enc | gpu_dec | gpu_throttle | gpu_pstate | gpu_top_process
#   gpu.sh refresh | popup | doctor

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export CACHE_PREFIX="gpu_revamped"
export PLUGIN_LOG_NS="gpu-revamped"

# shellcheck source=/dev/null
source "${PLUGIN_DIR}/src/lib/utils/has-command.sh"
# shellcheck source=/dev/null
source "${PLUGIN_DIR}/src/lib/tmux/tmux-ops.sh"
# shellcheck source=/dev/null
source "${PLUGIN_DIR}/src/lib/utils/cache.sh"
# shellcheck source=/dev/null
source "${PLUGIN_DIR}/src/lib/gpu/gpu.sh"
# shellcheck source=/dev/null
source "${PLUGIN_DIR}/src/lib/gpu/render.sh"
# shellcheck source=/dev/null
source "${PLUGIN_DIR}/src/lib/gpu/history.sh"
# shellcheck source=/dev/null
source "${PLUGIN_DIR}/src/lib/gpu/popup.sh"

gpu_max_age() {
  get_tmux_option "@gpu_revamped_interval" "5"
}

gpu_history_size() {
  get_tmux_option "@gpu_revamped_history_size" "20"
}

# gpu_history_push VALUE -> append VALUE to the bounded util history option.
gpu_history_push() {
  local value="${1}"
  [[ "${value}" =~ ^[0-9]+$ ]] || return 0
  local current
  current=$(get_tmux_option "@gpu_revamped_util_history" "")
  set_tmux_option "@gpu_revamped_util_history" \
    "$(history_push "${current}" "${value}" "$(gpu_history_size)")"
}

# gpu_graph -> render the load history as a sparkline.
gpu_graph() {
  render_sparkline "$(get_tmux_option "@gpu_revamped_util_history" "")"
}

gpu_refresh() {
  local vram util
  vram="$(read_vram)"
  util="$(read_gpu_usage)"
  cache_set util "${util}"
  cache_set temp "$(read_gpu_temp)"
  cache_set freq "$(read_gpu_freq)"
  cache_set gram "$(gram_pct_from_pair "${vram}")"
  cache_set gram_used "$(vram_used "${vram}")"
  cache_set gram_total "$(vram_total "${vram}")"
  cache_set power "$(read_power)"
  cache_set power_pct "$(read_power_pct)"
  cache_set fan "$(read_fan)"
  cache_set enc "$(read_gpu_enc)"
  cache_set dec "$(read_gpu_dec)"
  cache_set throttle "$(read_gpu_throttle)"
  cache_set pstate "$(read_gpu_pstate)"
  cache_set top_process "$(read_gpu_top_process)"
  gpu_history_push "${util}"
}

gpu_tick() {
  cache_refresh_if_stale util "$(gpu_max_age)" gpu_refresh
}

gpu_render_metric() {
  local cmd="${1}"
  case "${cmd}" in
    gpu_percentage)    metric_value "$(cache_get util)" "@gpu_revamped_percentage_format" "%s%%" ;;
    gpu_icon)          metric_icon "$(cache_get util)" "gpu_revamped" 30 80 "▰▱▱" "▰▰▱" "▰▰▰" ;;
    gpu_fg_color)      metric_color "$(cache_get util)" "gpu_revamped" 30 80 fg ;;
    gpu_bg_color)      metric_color "$(cache_get util)" "gpu_revamped" 30 80 bg ;;
    gpu_graph)         gpu_graph ;;
    gpu_temp)          gpu_temp_value "$(cache_get temp)" ;;
    gpu_temp_icon)     metric_icon "$(cache_get temp)" "gpu_revamped_temp" 65 80 "" "" "" ;;
    gpu_temp_fg_color) metric_color "$(cache_get temp)" "gpu_revamped_temp" 65 80 fg ;;
    gpu_temp_bg_color) metric_color "$(cache_get temp)" "gpu_revamped_temp" 65 80 bg ;;
    gpu_freq)          gpu_render_freq "$(cache_get freq)" ;;
    gpu_power)         metric_value "$(cache_get power)" "@gpu_revamped_power_format" "%sW" ;;
    gpu_power_pct)     metric_value "$(cache_get power_pct)" "@gpu_revamped_power_pct_format" "%s%%" ;;
    gpu_fan)           metric_value "$(cache_get fan)" "@gpu_revamped_fan_format" "%s%%" ;;
    gpu_enc)           metric_value "$(cache_get enc)" "@gpu_revamped_enc_format" "%s%%" ;;
    gpu_dec)           metric_value "$(cache_get dec)" "@gpu_revamped_dec_format" "%s%%" ;;
    gpu_throttle)      metric_value "$(cache_get throttle)" "@gpu_revamped_throttle_format" "%s" ;;
    gpu_pstate)        metric_value "$(cache_get pstate)" "@gpu_revamped_pstate_format" "%s" ;;
    gpu_top_process)   metric_value "$(cache_get top_process)" "@gpu_revamped_top_process_format" "%s" ;;
    gram_percentage)   metric_value "$(cache_get gram)" "@gpu_revamped_gram_format" "%s%%" ;;
    gram_icon)         metric_icon "$(cache_get gram)" "gpu_revamped_gram" 50 85 "▰▱▱" "▰▰▱" "▰▰▰" ;;
    gram_fg_color)     metric_color "$(cache_get gram)" "gpu_revamped_gram" 50 85 fg ;;
    gram_bg_color)     metric_color "$(cache_get gram)" "gpu_revamped_gram" 50 85 bg ;;
    gram_used)         gram_abs_value "$(cache_get gram_used)" "$(cache_get gram_total)" ;;
    *)                 return 0 ;;
  esac
}

gpu_is_labelled() {
  case "${1}" in
    gpu_percentage | gpu_temp | gpu_freq | gpu_graph | gpu_power | gpu_power_pct | gpu_fan | gpu_enc | gpu_dec | gpu_throttle | gpu_pstate | gpu_top_process | gram_percentage | gram_used) return 0 ;;
    *) return 1 ;;
  esac
}

gpu_nerd_label() {
  case "${1}" in
    gpu_percentage) printf '\xf3\xb0\xa2\xae' ;;
    gpu_temp) printf '\xf3\xb0\x94\x8f' ;;
    gpu_freq) printf '\xf3\xb0\x93\x85' ;;
    gpu_graph) printf '\xf3\xb0\x9e\xb1' ;;
    gpu_power) printf '\xf3\xb0\x89\x81' ;;
    gpu_power_pct) printf '\xf3\xb0\x89\x81' ;;
    gpu_fan) printf '\xf3\xb0\x88\x90' ;;
    gpu_enc) printf '\xf3\xb0\x95\xa7' ;;
    gpu_dec) printf '\xf3\xb0\x95\xa7' ;;
    gpu_throttle) printf '\xf3\xb0\x80\xa9' ;;
    gpu_pstate) printf '\xf3\xb0\x98\xae' ;;
    gpu_top_process) printf '\xf3\xb0\xa3\x86' ;;
    gram_percentage) printf '\xf3\xb0\x8d\x9b' ;;
    gram_used) printf '\xf3\xb0\x8d\x9b' ;;
    *) printf '' ;;
  esac
}

gpu_option_exists() {
  [[ -n "$(tmux show-option -gq "${1}" 2>/dev/null)" ]]
}

gpu_label() {
  local option="@gpu_revamped_${1#gpu_}_label"
  if gpu_option_exists "${option}"; then
    tmux show-option -gqv "${option}" 2>/dev/null
  elif [[ "$(get_tmux_option "@gpu_revamped_icons" "ascii")" == "nerd" ]]; then
    gpu_nerd_label "${1}"
  fi
}

gpu_labelled() {
  local metric="${1}" value="${2}" label
  [[ -n "${value}" ]] || return 0
  label="$(gpu_label "${metric}")"
  if [[ -n "${label}" ]]; then
    printf '%s %s\n' "${label}" "${value}"
  else
    printf '%s\n' "${value}"
  fi
}

main() {
  local cmd="${1:-}"

  case "${cmd}" in
    refresh) gpu_refresh; return 0 ;;
    popup)   gpu_popup; return 0 ;;
    doctor)  gpu_doctor; return 0 ;;
  esac

  gpu_tick

  local out
  out="$(gpu_render_metric "${cmd}")"
  if gpu_is_labelled "${cmd}"; then
    gpu_labelled "${cmd}" "${out}"
  elif [[ -n "${out}" ]]; then
    printf '%s\n' "${out}"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
