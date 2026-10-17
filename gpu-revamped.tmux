#!/usr/bin/env bash
#
# gpu-revamped.tmux: TPM entry point.
#
# Replaces the #{gpu_*} and #{gram_*} placeholders in status-left and
# status-right with calls to the dispatcher, which reads cached values, and binds
# the detail-popup key when the user opts in.

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GPU_CMD="${PLUGIN_DIR}/src/gpu.sh"
HASH="#"
GPU_CMD_QUOTED="$(printf '%q' "${GPU_CMD}")"
GPU_CMD_QUOTED="${GPU_CMD_QUOTED//"${HASH}"/${HASH}${HASH}}"

placeholders=(
  "\#{gpu_percentage}"
  "\#{gpu_icon}"
  "\#{gpu_fg_color}"
  "\#{gpu_bg_color}"
  "\#{gpu_graph}"
  "\#{gpu_temp}"
  "\#{gpu_temp_icon}"
  "\#{gpu_temp_fg_color}"
  "\#{gpu_temp_bg_color}"
  "\#{gpu_freq}"
  "\#{gpu_power}"
  "\#{gpu_power_pct}"
  "\#{gpu_fan}"
  "\#{gpu_enc}"
  "\#{gpu_dec}"
  "\#{gpu_throttle}"
  "\#{gpu_pstate}"
  "\#{gpu_top_process}"
  "\#{gram_percentage}"
  "\#{gram_icon}"
  "\#{gram_fg_color}"
  "\#{gram_bg_color}"
  "\#{gram_used}"
)

commands=(
  "#(${GPU_CMD_QUOTED} gpu_percentage)"
  "#(${GPU_CMD_QUOTED} gpu_icon)"
  "#(${GPU_CMD_QUOTED} gpu_fg_color)"
  "#(${GPU_CMD_QUOTED} gpu_bg_color)"
  "#(${GPU_CMD_QUOTED} gpu_graph)"
  "#(${GPU_CMD_QUOTED} gpu_temp)"
  "#(${GPU_CMD_QUOTED} gpu_temp_icon)"
  "#(${GPU_CMD_QUOTED} gpu_temp_fg_color)"
  "#(${GPU_CMD_QUOTED} gpu_temp_bg_color)"
  "#(${GPU_CMD_QUOTED} gpu_freq)"
  "#(${GPU_CMD_QUOTED} gpu_power)"
  "#(${GPU_CMD_QUOTED} gpu_power_pct)"
  "#(${GPU_CMD_QUOTED} gpu_fan)"
  "#(${GPU_CMD_QUOTED} gpu_enc)"
  "#(${GPU_CMD_QUOTED} gpu_dec)"
  "#(${GPU_CMD_QUOTED} gpu_throttle)"
  "#(${GPU_CMD_QUOTED} gpu_pstate)"
  "#(${GPU_CMD_QUOTED} gpu_top_process)"
  "#(${GPU_CMD_QUOTED} gram_percentage)"
  "#(${GPU_CMD_QUOTED} gram_icon)"
  "#(${GPU_CMD_QUOTED} gram_fg_color)"
  "#(${GPU_CMD_QUOTED} gram_bg_color)"
  "#(${GPU_CMD_QUOTED} gram_used)"
)

render_mode="$(tmux show-option -gqv "@gpu_revamped_render")"

target_for() {
  local command="${1}" metric
  metric="${command##* }"
  metric="${metric%)}"
  if [[ "${render_mode}" == "options" ]]; then
    printf '#{E:@gpu_revamped_out_%s}' "${metric}"
  else
    printf '%s' "${command}"
  fi
}

interpolate() {
  local value="${1}" i placeholder out rest
  for (( i = 0; i < ${#placeholders[@]}; i++ )); do
    placeholder="${placeholders[i]#\\}"
    out=""
    rest="${value}"
    while [[ "${rest}" == *"${placeholder}"* ]]; do
      out="${out}${rest%%"${placeholder}"*}$(target_for "${commands[i]}")"
      rest="${rest#*"${placeholder}"}"
    done
    value="${out}${rest}"
  done
  echo "${value}"
}

used_metrics() {
  local text="${1}" used="" i metric
  for (( i = 0; i < ${#placeholders[@]}; i++ )); do
    metric="${commands[i]##* }"
    metric="${metric%)}"
    if [[ "${text}" == *${placeholders[i]}* || "${text}" == *"@gpu_revamped_out_${metric}}"* ]]; then
      used="${used:+${used} }${metric}"
    fi
  done
  echo "${used}"
}

update_option() {
  local option="${1}"
  local current
  current=$(tmux show-option -gqv "${option}")
  tmux set-option -gq "${option}" "$(interpolate "${current}")"
}

bind_popup_key() {
  local key
  key=$(tmux show-option -gqv "@gpu_revamped_popup_key")
  [[ -z "${key}" ]] && return 0
  tmux bind-key "${key}" run-shell "${GPU_CMD_QUOTED} popup"
}

chmod +x "${GPU_CMD}" 2>/dev/null || true

status_text="$(tmux show-option -gqv status-left) $(tmux show-option -gqv status-right)"
tmux set-option -gq "@gpu_revamped_published" "$(used_metrics "${status_text}")"

update_option "status-left"
update_option "status-right"

if [[ "${render_mode}" == "options" ]]; then
  "${GPU_CMD}" start 2>/dev/null || true
else
  tmux set-option -gqu "@gpu_revamped_ticker_pid"
fi
bind_popup_key
