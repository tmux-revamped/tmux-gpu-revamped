#!/usr/bin/env bash

[[ -n "${_GPU_REVAMPED_POPUP_LOADED:-}" ]] && return 0
_GPU_REVAMPED_POPUP_LOADED=1

_GPU_POPUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${_GPU_POPUP_DIR}/../utils/has-command.sh"
# shellcheck source=/dev/null
source "${_GPU_POPUP_DIR}/../utils/platform.sh"
# shellcheck source=/dev/null
source "${_GPU_POPUP_DIR}/../tmux/tmux-ops.sh"

_tmux() { tmux "$@"; }

_drm_present() {
  local f
  for f in /sys/class/drm/card[0-9]*; do
    [[ -e "${f}" ]] && return 0
  done
  return 1
}

gpu_popup_command() {
  local override
  override=$(get_tmux_option "@gpu_revamped_popup_command" "")
  if [[ -n "${override}" ]]; then
    echo "${override}"
    return 0
  fi
  if has_command nvtop; then
    echo "nvtop"
  elif has_command rocm-smi; then
    echo "watch -n 1 rocm-smi"
  elif has_command nvidia-smi; then
    echo "watch -n 1 nvidia-smi"
  elif has_command btop; then
    echo "btop"
  else
    echo "top"
  fi
}

gpu_popup() {
  local cmd width height
  cmd=$(gpu_popup_command)
  width=$(get_tmux_option "@gpu_revamped_popup_width" "80%")
  height=$(get_tmux_option "@gpu_revamped_popup_height" "80%")
  _tmux display-popup -w "${width}" -h "${height}" -E "${cmd}"
}

_doctor_tool() {
  if has_command "${2}"; then
    printf '%s: detected (%s)\n' "${1}" "${2}"
  else
    printf '%s: missing (%s)\n' "${1}" "${2}"
  fi
}

gpu_doctor() {
  echo "tmux-gpu-revamped doctor"
  printf 'OS: %s (%s)\n' "$(platform_os)" "$(platform_arch)"
  _doctor_tool "NVIDIA probe" nvidia-smi
  _doctor_tool "AMD probe" rocm-smi
  if _drm_present; then
    echo "Linux sysfs (/sys/class/drm): present"
  else
    echo "Linux sysfs (/sys/class/drm): absent"
  fi
  _doctor_tool "Apple ioreg" ioreg
  _doctor_tool "Apple Silicon temperature" macmon
  _doctor_tool "macOS temperature" istats
  _doctor_tool "popup monitor" nvtop
  if is_macos && is_apple_silicon && ! has_command macmon; then
    echo "note: Apple Silicon GPU temperature needs macmon, so #{gpu_temp} is empty"
  fi
  echo "note: power/fan come from NVIDIA and AMD; encoder, decoder, throttle,"
  echo "      performance state, and top process are NVIDIA-only and render empty elsewhere"
}

export -f _tmux
export -f _drm_present
export -f gpu_popup_command
export -f gpu_popup
export -f _doctor_tool
export -f gpu_doctor
