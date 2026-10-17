#!/usr/bin/env bash

[[ -n "${_GPU_REVAMPED_HISTORY_LOADED:-}" ]] && return 0
_GPU_REVAMPED_HISTORY_LOADED=1

history_push() {
  local list="${1}" value="${2}" max="${3:-20}"
  [[ "${value}" =~ ^[0-9]+$ ]] || { echo "${list}"; return 0; }
  [[ "${max}" =~ ^[0-9]+$ && "${max}" -gt 0 ]] || max=20
  local -a items
  read -ra items <<< "${list} ${value}"
  local count="${#items[@]}"
  local start=0
  (( count > max )) && start=$(( count - max ))
  local out="" i
  for (( i = start; i < count; i++ )); do
    out="${out}${out:+ }${items[i]}"
  done
  echo "${out}"
}

sparkline_char() {
  local v="${1}"
  [[ "${v}" =~ ^[0-9]+$ ]] || v=0
  (( v > 100 )) && v=100
  local ramp=(▁ ▂ ▃ ▄ ▅ ▆ ▇ █)
  local idx=$(( v * 7 / 100 ))
  printf '%s' "${ramp[idx]}"
}

render_sparkline() {
  local list="${1}" out="" token
  [[ -z "${list// /}" ]] && { echo ""; return 0; }
  local -a items
  read -ra items <<< "${list}"
  for token in "${items[@]}"; do
    [[ "${token}" =~ ^[0-9]+$ ]] || continue
    out="${out}$(sparkline_char "${token}")"
  done
  echo "${out}"
}

export -f history_push
export -f sparkline_char
export -f render_sparkline
