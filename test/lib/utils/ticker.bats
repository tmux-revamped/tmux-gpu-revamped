#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../helpers.bash"

TICKER_LIB="${BATS_TEST_DIRNAME}/../../../src/lib/utils/ticker.sh"

setup() {
  setup_test_environment
  unset _TMUX_PLUGIN_TICKER_LOADED
  source "${TICKER_LIB}"
  TICK_LOG="${TEST_TMPDIR}/ticks"
  export TICK_LOG
  _ticker_sleep() { printf 'sleep %s\n' "${1}" >> "${TICK_LOG}"; }
}

teardown() {
  cleanup_test_environment
}

count_ticks() {
  if [[ -f "${TICK_LOG}" ]]; then
    grep -c '^tick$' "${TICK_LOG}"
  else
    printf '0'
  fi
}

record_tick() {
  printf 'tick\n' >> "${TICK_LOG}"
}

hand_over_after_two() {
  record_tick
  if [[ "$(count_ticks)" -ge 2 ]]; then
    tmux set-option -gq "@demo_ticker_pid" "other"
  fi
}

stub_status_interval() {
  export STUB_INTERVAL="${1}"
  _ticker_tmux() {
    if [[ "$*" == *"status-interval"* ]]; then
      printf '%s' "${STUB_INTERVAL}"
      return 0
    fi
    tmux "$@"
  }
}

wait_for_file() {
  local attempt
  for attempt in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    [[ -f "${1}" ]] && return 0
    sleep 0.1
  done
  return 1
}

@test "ticker - run claims ownership for its pid" {
  TICKER_MAX_TICKS=1

  ticker_run demo record_tick 4242

  [[ "$(tmux show-option -gqv @demo_ticker_pid)" == "4242" ]]
}

@test "ticker - run stops at the tick limit and reports it still owns the ticker" {
  TICKER_MAX_TICKS=3

  run ticker_run demo record_tick 4242

  [ "${status}" -eq 0 ]
  [[ "$(count_ticks)" == "3" ]]
}

@test "ticker - run stops when another ticker takes over" {
  TICKER_MAX_TICKS=10

  run ticker_run demo hand_over_after_two 4242

  [ "${status}" -eq 1 ]
  [[ "$(count_ticks)" == "2" ]]
}

@test "ticker - run stops when the server is gone" {
  TICKER_MAX_TICKS=10
  _ticker_tmux() { return 1; }

  run ticker_run demo record_tick 4242

  [ "${status}" -eq 1 ]
  [[ "$(count_ticks)" == "0" ]]
}

@test "ticker - the interval follows status-interval" {
  stub_status_interval 7

  run ticker_interval

  [[ "${output}" == "7" ]]
}

@test "ticker - a missing interval falls back to the default" {
  run ticker_interval

  [[ "${output}" == "${TICKER_DEFAULT_INTERVAL}" ]]
}

@test "ticker - a zero interval falls back to the default" {
  stub_status_interval 0

  run ticker_interval

  [[ "${output}" == "${TICKER_DEFAULT_INTERVAL}" ]]
}

@test "ticker - each tick sleeps for the interval" {
  TICKER_MAX_TICKS=2
  stub_status_interval 3

  ticker_run demo record_tick 4242

  [[ "$(grep -c '^sleep 3$' "${TICK_LOG}")" == "2" ]]
}

@test "ticker - start spawns the daemon subcommand" {
  _ticker_spawn() { printf 'spawn %s\n' "${1}" >> "${TICK_LOG}"; }

  ticker_start "/plugin/src/demo.sh"

  [[ "$(cat "${TICK_LOG}")" == "spawn /plugin/src/demo.sh" ]]
}

@test "ticker - spawn runs the script with the daemon argument in the background" {
  local script="${TEST_TMPDIR}/demo.sh"
  printf '#!/usr/bin/env bash\nprintf "%%s" "$1" > "%s/spawned"\n' "${TEST_TMPDIR}" > "${script}"
  chmod +x "${script}"

  _ticker_spawn "${script}"

  wait_for_file "${TEST_TMPDIR}/spawned"
  [[ "$(cat "${TEST_TMPDIR}/spawned")" == "daemon" ]]
}

@test "ticker - the sleep seam is callable" {
  unset _TMUX_PLUGIN_TICKER_LOADED
  source "${TICKER_LIB}"

  run _ticker_sleep 0

  [ "${status}" -eq 0 ]
}
