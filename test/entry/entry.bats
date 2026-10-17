#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../helpers.bash"

ENTRY="${BATS_TEST_DIRNAME}/../../gpu-revamped.tmux"

setup() {
  setup_test_environment
  export SPAWN_LOG="${TEST_TMPDIR}/spawn.log"
  nohup() { printf '%s\n' "$*" >> "${SPAWN_LOG}"; }
  export -f nohup
}

teardown() {
  cleanup_test_environment
}

@test "entry - jobs mode turns a placeholder into a dispatcher call" {
  tmux set-option -gq "status-right" "[#{gpu_percentage}]"

  bash "${ENTRY}"

  [[ "$(cat "$(_mock_opt_file status-right)")" == "[#($(cd "${BATS_TEST_DIRNAME}/../.." && pwd)/src/gpu.sh gpu_percentage)]" ]]
}

@test "entry - options mode turns a placeholder into an option read" {
  tmux set-option -gq "@gpu_revamped_render" "options"
  tmux set-option -gq "status-right" "[#{gpu_percentage}]"

  bash "${ENTRY}"

  [[ "$(cat "$(_mock_opt_file status-right)")" == "[#{E:@gpu_revamped_out_gpu_percentage}]" ]]
}

@test "entry - options mode starts the ticker" {
  tmux set-option -gq "@gpu_revamped_render" "options"
  tmux set-option -gq "status-right" "[#{gpu_percentage}]"

  bash "${ENTRY}"

  [[ "$(cat "${SPAWN_LOG}")" == *"/src/gpu.sh daemon" ]]
}

@test "entry - jobs mode starts no ticker" {
  tmux set-option -gq "status-right" "[#{gpu_percentage}]"

  bash "${ENTRY}"

  [ ! -f "${SPAWN_LOG}" ]
}

@test "entry - only metrics on the status line are published" {
  tmux set-option -gq "status-right" "#{gpu_percentage}"

  bash "${ENTRY}"

  [[ "$(cat "$(_mock_opt_file @gpu_revamped_published)")" == "gpu_percentage" ]]
}

@test "entry - a second run keeps metrics already turned into option reads" {
  tmux set-option -gq "@gpu_revamped_render" "options"
  tmux set-option -gq "status-right" "[#{E:@gpu_revamped_out_gpu_percentage}]"

  bash "${ENTRY}"

  [[ "$(cat "$(_mock_opt_file @gpu_revamped_published)")" == "gpu_percentage" ]]
}

@test "entry - jobs mode releases a ticker left from options mode" {
  # Arrange
  tmux set-option -gq "@gpu_revamped_ticker_pid" "4242"
  tmux set-option -gq "status-right" "[#{gpu_percentage}]"

  # Act
  bash "${ENTRY}"

  # Assert
  [ ! -f "$(_mock_opt_file @gpu_revamped_ticker_pid)" ]
}

@test "entry - the popup key quotes a plugin path with a space and a quote" {
  # Arrange
  local dir="${TEST_TMPDIR}/it's a&b dir"
  mkdir -p "${dir}"
  cp -f "${ENTRY}" "${dir}/gpu-revamped.tmux"
  export BIND_LOG="${TEST_TMPDIR}/bind.log"
  eval "_base_tmux() $(declare -f tmux | tail -n +2)"
  tmux() {
    if [[ "${1}" == "bind-key" ]]; then
      printf '%s\n' "$*" >> "${BIND_LOG}"
      return 0
    fi
    _base_tmux "$@"
  }
  export -f _base_tmux tmux
  tmux set-option -gq "@gpu_revamped_popup_key" "M-g"
  tmux set-option -gq "status-right" "[#{gpu_percentage}]"

  # Act
  bash "${dir}/gpu-revamped.tmux"

  # Assert
  [[ "$(cat "$(_mock_opt_file status-right)")" == "[#($(cd "${TEST_TMPDIR}" && pwd)/it\\'s\\ a\\&b\\ dir/src/gpu.sh gpu_percentage)]" ]] || false
  [[ "$(cat "${BIND_LOG}")" == "bind-key M-g run-shell $(cd "${TEST_TMPDIR}" && pwd)/it\\'s\\ a\\&b\\ dir/src/gpu.sh popup" ]]
}
