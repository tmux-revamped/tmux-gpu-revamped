#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../helpers.bash"

PUBLISH_LIB="${BATS_TEST_DIRNAME}/../../../src/lib/utils/publish.sh"

setup() {
  setup_test_environment
  unset _TMUX_PLUGIN_PUBLISH_LOADED
  source "${PUBLISH_LIB}"
  PUBLISH_LOG="${TEST_TMPDIR}/publish.log"
  export PUBLISH_LOG
  _publish_tmux() {
    if [[ "${1}" == "list-clients" ]]; then
      printf '%s\n' "${PUBLISH_CLIENTS:-}"
      return 0
    fi
    printf '%s\n' "$@" > "${PUBLISH_LOG}"
  }
}

teardown() {
  cleanup_test_environment
}

logged_words() {
  paste -sd'|' "${PUBLISH_LOG}"
}

@test "publish - pad left-pads a value to the width" {
  run publish_pad "9%" 4

  [[ "${output}" == "  9%" ]]
}

@test "publish - pad counts a multibyte character once" {
  run publish_pad "45°C" 5

  [[ "${output}" == " 45°C" ]]
}

@test "publish - pad with zero width returns the value unchanged" {
  run publish_pad "9%" 0

  [[ "${output}" == "9%" ]]
}

@test "publish - chars counts characters, not bytes" {
  run publish_chars "°C"

  [[ "${output}" == "2" ]]
}

@test "publish - pad never cuts a wider value" {
  run publish_pad "100%" 2

  [[ "${output}" == "100%" ]]
}

@test "publish - pad treats a non-numeric width as zero" {
  run publish_pad "9%" "wide"

  [[ "${output}" == "9%" ]]
}

@test "publish - width is zero by default" {
  run publish_width cpu_revamped percentage 4

  [[ "${output}" == "0" ]]
}

@test "publish - fixed width uses the natural maximum" {
  set_tmux_option "@cpu_revamped_fixed_width" "on"

  run publish_width cpu_revamped percentage 4

  [[ "${output}" == "4" ]]
}

@test "publish - a metric width overrides fixed width" {
  set_tmux_option "@cpu_revamped_fixed_width" "on"
  set_tmux_option "@cpu_revamped_percentage_width" "3"

  run publish_width cpu_revamped percentage 4

  [[ "${output}" == "3" ]]
}

@test "publish - a non-numeric metric width falls back to fixed width" {
  set_tmux_option "@cpu_revamped_fixed_width" "on"
  set_tmux_option "@cpu_revamped_percentage_width" "wide"

  run publish_width cpu_revamped percentage 4

  [[ "${output}" == "4" ]]
}

@test "publish - a trailing semicolon is escaped" {
  run publish_escape "x;"

  [[ "${output}" == 'x\;' ]]
}

@test "publish - a value without a trailing semicolon is unchanged" {
  run publish_escape "a;b"

  [[ "${output}" == "a;b" ]]
}

@test "publish - commit sends every option in one call" {
  publish_add "@a" "1"
  publish_add "@b" "2"

  publish_commit

  [[ "$(logged_words)" == "set-option|-gq|@a|1|;|set-option|-gq|@b|2" ]]
}

@test "publish - a pane value targets that pane" {
  publish_add "@a" "1" "%3"

  publish_commit

  [[ "$(logged_words)" == "set-option|-pq|-t|%3|@a|1" ]]
}

@test "publish - commit refreshes every attached client" {
  export PUBLISH_CLIENTS=$'/dev/ttys001\n/dev/ttys002'
  publish_add "@a" "1"

  publish_commit

  [[ "$(logged_words)" == "set-option|-gq|@a|1|;|refresh-client|-S|-t|/dev/ttys001|;|refresh-client|-S|-t|/dev/ttys002" ]]
}

@test "publish - commit with nothing pending sends nothing" {
  run publish_commit

  [ "${status}" -eq 0 ]
  [ ! -f "${PUBLISH_LOG}" ]
}

@test "publish - commit empties the batch" {
  publish_add "@a" "1"

  publish_commit

  [ "${PUBLISH_PENDING}" -eq 0 ]
}

@test "publish - the tmux seam calls tmux" {
  unset -f _publish_tmux
  unset _TMUX_PLUGIN_PUBLISH_LOADED
  source "${PUBLISH_LIB}"

  run _publish_tmux show-option -gqv "@missing"

  [ "${status}" -eq 0 ]
}
