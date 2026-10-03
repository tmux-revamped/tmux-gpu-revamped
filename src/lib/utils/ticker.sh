#!/usr/bin/env bash

[[ -n "${_TMUX_PLUGIN_TICKER_LOADED:-}" ]] && return 0
_TMUX_PLUGIN_TICKER_LOADED=1

TICKER_MAX_TICKS="${TICKER_MAX_TICKS:-100000}"
TICKER_DEFAULT_INTERVAL=5

_ticker_tmux() { tmux "$@"; }
_ticker_sleep() { sleep "${1}"; }
_ticker_spawn() {
  nohup "${1}" daemon >/dev/null 2>&1 &
  disown 2>/dev/null || true
}

ticker_owner() {
  _ticker_tmux show-option -gqv "@${1}_ticker_pid" 2>/dev/null
}

ticker_claim() {
  _ticker_tmux set-option -gq "@${1}_ticker_pid" "${2}" 2>/dev/null
}

ticker_owns() {
  [[ "$(ticker_owner "${1}")" == "${2}" ]]
}

ticker_interval() {
  local interval
  interval="$(_ticker_tmux show-option -gqv status-interval 2>/dev/null)"
  if [[ ! "${interval}" =~ ^[0-9]+$ ]] || ((interval < 1)); then
    interval="${TICKER_DEFAULT_INTERVAL}"
  fi
  printf '%s' "${interval}"
}

ticker_start() {
  _ticker_spawn "${1}"
}

ticker_run() {
  local prefix="${1}" tick="${2}" pid="${3}" count=0
  ticker_claim "${prefix}" "${pid}"
  while ((count < TICKER_MAX_TICKS)) && ticker_owns "${prefix}" "${pid}"; do
    "${tick}"
    _ticker_sleep "$(ticker_interval)"
    count=$((count + 1))
  done
  ((count >= TICKER_MAX_TICKS)) && ticker_owns "${prefix}" "${pid}"
}
