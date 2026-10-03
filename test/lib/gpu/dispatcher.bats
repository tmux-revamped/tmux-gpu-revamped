#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../helpers.bash"

setup() {
  setup_test_environment
  unset _GPU_REVAMPED_GPU_LOADED _GPU_REVAMPED_RENDER_LOADED \
    _GPU_REVAMPED_HISTORY_LOADED _GPU_REVAMPED_POPUP_LOADED
  export CACHE_SYNC=1
  source "${BATS_TEST_DIRNAME}/../../../src/gpu.sh"
  read_gpu_usage() { echo "45"; }
  read_gpu_temp() { echo "60"; }
  read_gpu_freq() { echo "1398"; }
  read_vram() { echo "2048 8192"; }
  read_power() { echo "120"; }
  read_power_pct() { echo "48"; }
  read_fan() { echo "33"; }
  read_gpu_enc() { echo "12"; }
  read_gpu_dec() { echo "7"; }
  read_gpu_throttle() { echo "thermal"; }
  read_gpu_pstate() { echo "P2"; }
  read_gpu_top_process() { echo "python"; }
}

teardown() {
  cleanup_test_environment
}

@test "gpu.sh dispatcher - functions are defined" {
  function_exists main
  function_exists gpu_refresh
  function_exists gpu_tick
  function_exists gpu_max_age
}

@test "gpu.sh dispatcher - gpu_max_age default is 5" {
  [[ "$(gpu_max_age)" == "5" ]]
}

@test "gpu.sh dispatcher - gpu_max_age honors the interval option" {
  set_tmux_option "@gpu_revamped_interval" "7"
  [[ "$(gpu_max_age)" == "7" ]]
}

@test "gpu.sh dispatcher - gpu_refresh caches every metric" {
  gpu_refresh
  [[ "$(cache_get util)" == "45" ]]
  [[ "$(cache_get temp)" == "60" ]]
  [[ "$(cache_get freq)" == "1398" ]]
  [[ "$(cache_get gram)" == "25" ]]
}

@test "gpu.sh dispatcher - refresh subcommand caches metrics" {
  main refresh
  [[ "$(cache_get util)" == "45" ]]
}

@test "gpu.sh dispatcher - gpu_percentage renders the cached load" {
  run main gpu_percentage
  [[ "${output}" == "45%" ]]
}

@test "gpu.sh dispatcher - gpu_icon maps the cached load" {
  run main gpu_icon
  [[ "${output}" == "▰▰▱" ]]
}

@test "gpu.sh dispatcher - gpu_temp renders the cached temperature" {
  run main gpu_temp
  [[ "${output}" == "60°C" ]]
}

@test "gpu.sh dispatcher - gpu_freq renders the cached frequency" {
  run main gpu_freq
  [[ "${output}" == "1398MHz" ]]
}

@test "gpu.sh dispatcher - gram_percentage renders the cached memory" {
  run main gram_percentage
  [[ "${output}" == "25%" ]]
}

@test "gpu.sh dispatcher - gram_icon maps the cached memory" {
  run main gram_icon
  [[ "${output}" == "▰▱▱" ]]
}

@test "gpu.sh dispatcher - gpu colors map the cached load" {
  set_tmux_option "@gpu_revamped_medium_fg_color" "#[fg=yellow]"
  set_tmux_option "@gpu_revamped_medium_bg_color" "#[bg=yellow]"
  run main gpu_fg_color
  [[ "${output}" == "#[fg=yellow]" ]]
  run main gpu_bg_color
  [[ "${output}" == "#[bg=yellow]" ]]
}

@test "gpu.sh dispatcher - gpu temperature tier placeholders map the cache" {
  set_tmux_option "@gpu_revamped_temp_low_icon" "COOL"
  set_tmux_option "@gpu_revamped_temp_low_fg_color" "#[fg=blue]"
  set_tmux_option "@gpu_revamped_temp_low_bg_color" "#[bg=blue]"
  run main gpu_temp_icon
  [[ "${output}" == "COOL" ]]
  run main gpu_temp_fg_color
  [[ "${output}" == "#[fg=blue]" ]]
  run main gpu_temp_bg_color
  [[ "${output}" == "#[bg=blue]" ]]
}

@test "gpu.sh dispatcher - gram colors map the cached memory" {
  set_tmux_option "@gpu_revamped_gram_low_fg_color" "#[fg=green]"
  set_tmux_option "@gpu_revamped_gram_low_bg_color" "#[bg=green]"
  run main gram_fg_color
  [[ "${output}" == "#[fg=green]" ]]
  run main gram_bg_color
  [[ "${output}" == "#[bg=green]" ]]
}

@test "gpu.sh dispatcher - unknown subcommand produces no output" {
  run main bogus
  [[ -z "${output}" ]]
}

@test "gpu.sh dispatcher - extended functions are defined" {
  function_exists gpu_history_push
  function_exists gpu_history_size
  function_exists gpu_graph
  function_exists gpu_popup
  function_exists gpu_doctor
}

@test "gpu.sh dispatcher - gpu_refresh caches the extended metrics" {
  gpu_refresh
  [[ "$(cache_get gram_used)" == "2048" ]]
  [[ "$(cache_get gram_total)" == "8192" ]]
  [[ "$(cache_get power)" == "120" ]]
  [[ "$(cache_get power_pct)" == "48" ]]
  [[ "$(cache_get fan)" == "33" ]]
  [[ "$(cache_get enc)" == "12" ]]
  [[ "$(cache_get dec)" == "7" ]]
  [[ "$(cache_get throttle)" == "thermal" ]]
  [[ "$(cache_get pstate)" == "P2" ]]
  [[ "$(cache_get top_process)" == "python" ]]
}

@test "gpu.sh dispatcher - gpu_refresh records util history" {
  gpu_refresh
  [[ "$(get_tmux_option "@gpu_revamped_util_history" "")" == "45" ]]
  gpu_refresh
  [[ "$(get_tmux_option "@gpu_revamped_util_history" "")" == "45 45" ]]
}

@test "gpu.sh dispatcher - history honors a custom size" {
  set_tmux_option "@gpu_revamped_history_size" "2"
  gpu_history_push 1
  gpu_history_push 2
  gpu_history_push 3
  [[ "$(get_tmux_option "@gpu_revamped_util_history" "")" == "2 3" ]]
}

@test "gpu.sh dispatcher - gpu_history_push ignores non-numeric input" {
  gpu_history_push "x"
  [[ -z "$(get_tmux_option "@gpu_revamped_util_history" "")" ]]
}

@test "gpu.sh dispatcher - gpu_graph renders the history sparkline" {
  cache_set util 50
  set_tmux_option "@gpu_revamped_util_history" "0 50 100"
  run main gpu_graph
  [[ "${output}" == "▁▄█" ]]
}

@test "gpu.sh dispatcher - gram_used renders the absolute memory" {
  run main gram_used
  [[ "${output}" == "2.0G / 8.0G" ]]
}

@test "gpu.sh dispatcher - gpu_power renders watts" {
  run main gpu_power
  [[ "${output}" == "120W" ]]
}

@test "gpu.sh dispatcher - gpu_power_pct renders percent" {
  run main gpu_power_pct
  [[ "${output}" == "48%" ]]
}

@test "gpu.sh dispatcher - gpu_fan renders percent" {
  run main gpu_fan
  [[ "${output}" == "33%" ]]
}

@test "gpu.sh dispatcher - gpu_enc and gpu_dec render percent" {
  run main gpu_enc
  [[ "${output}" == "12%" ]]
  run main gpu_dec
  [[ "${output}" == "7%" ]]
}

@test "gpu.sh dispatcher - gpu_throttle renders the reason" {
  run main gpu_throttle
  [[ "${output}" == "thermal" ]]
}

@test "gpu.sh dispatcher - gpu_pstate renders the state" {
  run main gpu_pstate
  [[ "${output}" == "P2" ]]
}

@test "gpu.sh dispatcher - gpu_top_process renders the app" {
  run main gpu_top_process
  [[ "${output}" == "python" ]]
}

@test "gpu.sh dispatcher - popup subcommand drives the seam without launching" {
  has_command() { [[ "$1" == "nvtop" ]]; }
  _tmux() { echo "TMUX $*"; }
  run main popup
  [[ "${output}" == *"display-popup"* ]]
  [[ "${output}" == *"nvtop"* ]]
}

@test "gpu.sh dispatcher - doctor subcommand prints the report" {
  has_command() { return 1; }
  _drm_present() { return 1; }
  run main doctor
  [[ "${output}" == *"tmux-gpu-revamped doctor"* ]]
}

@test "gpu.sh dispatcher - a metric renders without a label by default" {
  run gpu_labelled gpu_percentage "42%"

  [[ "${output}" == "42%" ]]
}

@test "gpu.sh dispatcher - the nerd icon set labels a metric" {
  set_tmux_option "@gpu_revamped_icons" "nerd"

  run gpu_labelled gpu_percentage "42%"

  [[ "${output}" == $'\xf3\xb0\xa2\xae'" 42%" ]]
}

@test "gpu.sh dispatcher - a label option drops the gpu prefix" {
  set_tmux_option "@gpu_revamped_icons" "nerd"
  set_tmux_option "@gpu_revamped_percentage_label" "G"

  run gpu_labelled gpu_percentage "42%"

  [[ "${output}" == "G 42%" ]]
}

@test "gpu.sh dispatcher - an empty label removes the icon set's label" {
  set_tmux_option "@gpu_revamped_icons" "nerd"
  gpu_option_exists() { [[ "${1}" == "@gpu_revamped_percentage_label" ]]; }

  run gpu_labelled gpu_percentage "42%"

  [[ "${output}" == "42%" ]]
}

@test "gpu.sh dispatcher - an empty value renders nothing even with a label" {
  set_tmux_option "@gpu_revamped_icons" "nerd"

  run gpu_labelled gpu_percentage ""

  [ -z "${output}" ]
}

@test "gpu.sh dispatcher - only value metrics carry a label" {
  run gpu_is_labelled gpu_fg_color

  [ "${status}" -eq 1 ]
}

@test "gpu.sh dispatcher - main labels a rendered metric" {
  set_tmux_option "@gpu_revamped_icons" "nerd"
  gpu_tick() { :; }
  gpu_render_metric() { echo "42%"; }

  run main gpu_percentage

  [[ "${output}" == $'\xf3\xb0\xa2\xae'" 42%" ]]
}

@test "gpu.sh dispatcher - a width option pads the value on the left" {
  set_tmux_option "@gpu_revamped_percentage_width" "5"

  run gpu_labelled gpu_percentage "42%"

  [[ "${output}" == "  42%" ]]
}

@test "gpu.sh dispatcher - a value wider than the width is not cut" {
  set_tmux_option "@gpu_revamped_percentage_width" "2"

  run gpu_labelled gpu_percentage "42%"

  [[ "${output}" == "42%" ]]
}

@test "gpu.sh dispatcher - a non-numeric width adds no padding" {
  set_tmux_option "@gpu_revamped_percentage_width" "wide"

  run gpu_labelled gpu_percentage "42%"

  [[ "${output}" == "42%" ]]
}

@test "gpu.sh dispatcher - the padding sits between the label and the value" {
  set_tmux_option "@gpu_revamped_percentage_label" "X"
  set_tmux_option "@gpu_revamped_percentage_width" "5"

  run gpu_labelled gpu_percentage "42%"

  [[ "${output}" == "X   42%" ]]
}

@test "gpu dispatcher - fixed width pads a value to its widest form" {
  set_tmux_option "@gpu_revamped_fixed_width" "on"

  run gpu_labelled gpu_percentage "9%"

  [[ "${output}" == "  9%" ]]
}

@test "gpu dispatcher - natural widths cover the padded metrics" {
  run bash -c 'source "$1"; for m in gpu_percentage gpu_temp gram_percentage gpu_graph; do printf "%s=%s " "$m" "$(gpu_natural_width "$m")"; done' _ "${BATS_TEST_DIRNAME}/../../../src/gpu.sh"

  [[ "${output}" == "gpu_percentage=4 gpu_temp=5 gram_percentage=4 gpu_graph=0 " ]]
}

@test "gpu dispatcher - publish writes every published metric in one batch" {
  export PUBLISH_LOG="${TEST_TMPDIR}/publish.log"
  _publish_tmux() { [[ "${1}" == "list-clients" ]] && return 0; printf '%s\n' "$@" > "${PUBLISH_LOG}"; }
  gpu_refresh() { return 0; }
  gpu_output() { printf 'v-%s' "${1}"; }
  set_tmux_option "@gpu_revamped_published" "alpha beta"

  gpu_publish

  [[ "$(paste -sd'|' "${PUBLISH_LOG}")" == "set-option|-gq|@gpu_revamped_out_alpha|v-alpha|;|set-option|-gq|@gpu_revamped_out_beta|v-beta" ]]
}

@test "gpu dispatcher - the daemon re-executes after the tick limit" {
  ticker_run() { return 0; }
  _gpu_reexec() { echo "reexec" > "${TEST_TMPDIR}/reexec"; }

  gpu_daemon

  [[ "$(cat "${TEST_TMPDIR}/reexec")" == "reexec" ]]
}

@test "gpu dispatcher - the daemon stops when it loses ownership" {
  ticker_run() { return 1; }
  _gpu_reexec() { echo "reexec" > "${TEST_TMPDIR}/reexec"; }

  gpu_daemon

  [ ! -f "${TEST_TMPDIR}/reexec" ]
}

@test "gpu dispatcher - main daemon runs the ticker" {
  gpu_daemon() { echo "daemon" > "${TEST_TMPDIR}/daemon"; }

  main daemon

  [[ "$(cat "${TEST_TMPDIR}/daemon")" == "daemon" ]]
}

@test "gpu dispatcher - main start spawns the daemon" {
  _ticker_spawn() { printf '%s' "${1}" > "${TEST_TMPDIR}/spawn"; }

  main start

  [[ "$(cat "${TEST_TMPDIR}/spawn")" == *"/src/gpu.sh" ]]
}

@test "gpu dispatcher - the metric renderer does not start the daemon" {
  gpu_daemon() { echo "daemon" > "${TEST_TMPDIR}/daemon"; }

  gpu_render_metric daemon >/dev/null

  [ ! -f "${TEST_TMPDIR}/daemon" ]
}

@test "gpu dispatcher - a detail probe keeps its cache inside the detail interval" {
  gpu_refresh
  read_gpu_temp() { echo "probed" > "${TEST_TMPDIR}/probed"; echo "fresh"; }

  gpu_refresh

  [ ! -f "${TEST_TMPDIR}/probed" ]
}

@test "gpu dispatcher - a detail probe runs again after the detail interval" {
  gpu_refresh
  read_gpu_temp() { echo "fresh"; }
  export MOCK_EPOCH=$(( MOCK_EPOCH + 61 ))

  gpu_refresh

  [[ "$(cache_get temp)" == "fresh" ]]
}
