#!/usr/bin/env bash

[[ -n "${_GPU_REVAMPED_TEMPERATURE_LOADED:-}" ]] && return 0
_GPU_REVAMPED_TEMPERATURE_LOADED=1

gpu_round_celsius() {
  local pattern='^[^0-9]*([0-9]+)(\.([0-9]))?' whole tenth
  [[ "${1}" =~ ${pattern} ]] || return 0
  whole=$((10#${BASH_REMATCH[1]}))
  tenth="${BASH_REMATCH[3]:-0}"
  ((whole > 0 || tenth > 0)) || return 0
  ((tenth >= 5)) && whole=$((whole + 1))
  printf '%s\n' "${whole}"
}

gpu_temp_from_macmon() {
  local pattern='"gpu_temp_avg":([0-9.]+)'
  [[ "${1}" =~ ${pattern} ]] || return 0
  gpu_round_celsius "${BASH_REMATCH[1]}"
}

export -f gpu_round_celsius gpu_temp_from_macmon
