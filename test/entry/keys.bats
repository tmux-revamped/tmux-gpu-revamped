#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031,SC2154

# shellcheck source=test/tmux_helpers.bash
source "${BATS_TEST_DIRNAME}/../tmux_helpers.bash"

wait_for() {
  local delay
  for delay in 0.01 0.02 0.05 0.1 0.1 0.2 0.2 0.5 0.5 1 1 1 2 2; do
    "$@" && return 0
    sleep "${delay}"
  done
  "$@" && return 0
  command tmux -S "${HOST}" capture-pane -p -t host || :
  return 1
}

attached() {
  local clients
  clients=$(tmux list-clients -F x 2>/dev/null)
  [[ -n "${clients}" ]]
}

host_shows() {
  local screen
  screen=$(command tmux -S "${HOST}" capture-pane -p -t host)
  [[ "${screen}" == *"$1"* ]]
}

host_lacks() {
  ! host_shows "$1"
}

said() {
  local messages
  messages=$(tmux show-messages)
  [[ "${messages}" == *"$1"* ]]
}

stand_in() {
  printf '#!/bin/sh\nprintf "%%s\\n" "%s stand-in running $*"\nread -r stand_in_wait\n' "$1" >"${STUBS}/$1"
  chmod +x "${STUBS}/$1"
}

without_monitors() {
  local folder old_ifs="${IFS}"
  FARM="${BATS_TEST_TMPDIR}/farm"
  mkdir -p "${FARM}"
  IFS=:
  for folder in ${PATH}; do
    [[ -d "${folder}" ]] || continue
    ln -s "${folder}"/* "${FARM}/" 2>/dev/null || :
  done
  IFS="${old_ifs}"
  rm -f "${FARM}/nvtop" "${FARM}/rocm-smi" "${FARM}/nvidia-smi" "${FARM}/btop" "${FARM}/top" "${FARM}/watch"
  PATH="${STUBS}:${FARM}"
}

setup() {
  unset BASH_ENV
  ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  STUBS="${BATS_TEST_TMPDIR}/stubs"
  export HOME="${BATS_TEST_TMPDIR}/home"
  mkdir -p "${HOME}" "${STUBS}"
  HOST="${TMUX_SOCKET}-host"
  without_monitors
}

serve() {
  setup_tmux_server
  tmux set-option -g default-command "env PS1='$ ' sh"
  [[ -z "${1:-}" ]] || tmux set-option -g @gpu_revamped_popup_command "$1"
  command tmux -S "${HOST}" -f /dev/null new-session -d -s host -x 120 -y 40 \
    "env -u TMUX TERM=xterm-256color tmux -S '${TMUX_SOCKET}' attach-session -t test"
  wait_for attached
  tmux run-shell "'${ROOT}/gpu-revamped.tmux'"
}

teardown() {
  command tmux -S "${HOST}" kill-server 2>/dev/null || :
  rm -f "${HOST}"
  teardown_tmux_server
}

press() {
  local key
  for key in "$@"; do
    command tmux -S "${HOST}" send-keys -t host "${key}"
  done
}

@test "keys - prefix M-g opens the detail popup running nvtop, and it stays until nvtop ends" {
  # Arrange
  stand_in nvtop
  stand_in top
  serve

  # Act
  press C-b M-g

  # Assert
  wait_for host_shows "nvtop stand-in running"
  press Enter
  wait_for host_lacks "nvtop stand-in running"
}

@test "keys - with only nvidia-smi the popup watches it" {
  # Arrange
  stand_in nvidia-smi
  stand_in watch
  serve

  # Act
  press C-b M-g

  # Assert
  wait_for host_shows "watch stand-in running -n 1 nvidia-smi"
}

@test "keys - without any GPU monitor the popup runs btop, then top" {
  # Arrange
  stand_in top
  serve

  # Act
  press C-b M-g

  # Assert
  wait_for host_shows "top stand-in running"
}

@test "keys - a popup command that is not installed is named in a message" {
  # Arrange
  stand_in top
  serve "no-such-gpu-tool -c"

  # Act
  press C-b M-g

  # Assert
  wait_for said "gpu-revamped: no-such-gpu-tool is not installed"
}
