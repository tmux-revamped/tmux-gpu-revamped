#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../helpers.bash"

setup() {
  setup_test_environment
  unset _GPU_REVAMPED_RENDER_LOADED
  source "${BATS_TEST_DIRNAME}/../../../src/lib/gpu/render.sh"
}

teardown() {
  cleanup_test_environment
}

@test "render.sh - _gpu_level classifies by thresholds" {
  [[ "$(_gpu_level 10 30 80)" == "low" ]]
  [[ "$(_gpu_level 50 30 80)" == "medium" ]]
  [[ "$(_gpu_level 90 30 80)" == "high" ]]
}

@test "render.sh - _gpu_level treats non-numeric as zero" {
  [[ "$(_gpu_level zz 30 80)" == "low" ]]
}

@test "render.sh - _gpu_c_to_f converts and rejects junk" {
  [[ "$(_gpu_c_to_f 60)" == "140" ]]
  [[ -z "$(_gpu_c_to_f xx)" ]]
}

@test "render.sh - metric_value is empty on cold start" {
  [[ -z "$(metric_value "" "@gpu_revamped_percentage_format" "%s%%")" ]]
}

@test "render.sh - metric_value formats with the default" {
  [[ "$(metric_value 45 "@gpu_revamped_percentage_format" "%s%%")" == "45%" ]]
}

@test "render.sh - metric_value honors a custom format" {
  set_tmux_option "@gpu_revamped_percentage_format" "G %s%%"
  [[ "$(metric_value 45 "@gpu_revamped_percentage_format" "%s%%")" == "G 45%" ]]
}

@test "render.sh - metric_level reads thresholds from options" {
  set_tmux_option "@gpu_revamped_high_thresh" "40"
  [[ "$(metric_level 45 gpu_revamped 30 80)" == "high" ]]
}

@test "render.sh - metric_icon is empty on cold start" {
  [[ -z "$(metric_icon "" gpu_revamped 30 80 a b c)" ]]
}

@test "render.sh - metric_icon picks the level default icon" {
  [[ "$(metric_icon 50 gpu_revamped 30 80 LO MED HI)" == "MED" ]]
  [[ "$(metric_icon 90 gpu_revamped 30 80 LO MED HI)" == "HI" ]]
  [[ "$(metric_icon 5 gpu_revamped 30 80 LO MED HI)" == "LO" ]]
}

@test "render.sh - metric_icon honors a configured icon" {
  set_tmux_option "@gpu_revamped_high_icon" "CUSTOM"
  [[ "$(metric_icon 95 gpu_revamped 30 80 LO MED HI)" == "CUSTOM" ]]
}

@test "render.sh - metric_color is empty on cold start" {
  [[ -z "$(metric_color "" gpu_revamped 30 80 fg)" ]]
}

@test "render.sh - metric_color returns the configured color" {
  set_tmux_option "@gpu_revamped_high_fg_color" "#[fg=red]"
  [[ "$(metric_color 95 gpu_revamped 30 80 fg)" == "#[fg=red]" ]]
}

@test "render.sh - gpu_render_freq is empty on cold start or zero" {
  [[ -z "$(gpu_render_freq "")" ]]
  [[ -z "$(gpu_render_freq 0)" ]]
}

@test "render.sh - gpu_render_freq formats with the default" {
  [[ "$(gpu_render_freq 1398)" == "1398MHz" ]]
}

@test "render.sh - gpu_render_freq honors a custom format" {
  set_tmux_option "@gpu_revamped_freq_format" "%s MHz"
  [[ "$(gpu_render_freq 1398)" == "1398 MHz" ]]
}

@test "render.sh - gpu_temp_value is empty on cold start" {
  [[ -z "$(gpu_temp_value "")" ]]
}

@test "render.sh - gpu_temp_value formats Celsius by default" {
  [[ "$(gpu_temp_value 60)" == "60°C" ]]
}

@test "render.sh - gpu_temp_value converts to Fahrenheit" {
  set_tmux_option "@gpu_revamped_temp_unit" "F"
  [[ "$(gpu_temp_value 60)" == "140°F" ]]
}

@test "render.sh - load tier color passes every tmux color spec through verbatim" {
  for spec in '#[fg=red]' '#[fg=colour203]' '#[fg=#f38ba8]' '#[fg=#f38ba8,bg=#1e1e2e]' '#[fg=brightred]'; do
    set_tmux_option "@gpu_revamped_high_fg_color" "${spec}"
    [[ "$(metric_color 95 gpu_revamped 30 80 fg)" == "${spec}" ]]
  done
}

@test "render.sh - temperature tier color passes every tmux color spec through verbatim" {
  for spec in '#[fg=red]' '#[fg=colour203]' '#[fg=#f38ba8]' '#[fg=#f38ba8,bg=#1e1e2e]' '#[fg=brightred]'; do
    set_tmux_option "@gpu_revamped_temp_high_fg_color" "${spec}"
    [[ "$(metric_color 95 gpu_revamped_temp 65 80 fg)" == "${spec}" ]]
  done
}

@test "render.sh - GPU memory tier color passes every tmux color spec through verbatim" {
  for spec in '#[fg=red]' '#[fg=colour203]' '#[fg=#f38ba8]' '#[fg=#f38ba8,bg=#1e1e2e]' '#[fg=brightred]'; do
    set_tmux_option "@gpu_revamped_gram_high_fg_color" "${spec}"
    [[ "$(metric_color 95 gpu_revamped_gram 50 85 fg)" == "${spec}" ]]
  done
}

@test "render.sh - _mib_to_human formats GiB" {
  [[ "$(_mib_to_human 2048)" == "2.0G" ]]
  [[ "$(_mib_to_human 24576)" == "24G" ]]
  [[ -z "$(_mib_to_human xx)" ]]
}

@test "render.sh - gram_abs_value renders used and total" {
  [[ "$(gram_abs_value 18432 24576)" == "18G / 24G" ]]
  [[ "$(gram_abs_value 2048 8192)" == "2.0G / 8.0G" ]]
}

@test "render.sh - gram_abs_value is empty when unset or zero" {
  [[ -z "$(gram_abs_value '' 8192)" ]]
  [[ -z "$(gram_abs_value 2048 0)" ]]
  [[ -z "$(gram_abs_value xx 8192)" ]]
}

@test "render.sh - gram_abs_value honors a custom format" {
  set_tmux_option "@gpu_revamped_gram_abs_format" "%s of %s"
  [[ "$(gram_abs_value 24576 49152)" == "24G of 48G" ]]
}

@test "gpu - a comma-decimal locale still formats with a dot" {
  locale -a 2>/dev/null | grep -qiE '^pt_BR\.utf-?8$' || skip "the pt_BR.UTF-8 locale is not installed"
  LC_ALL=pt_BR.UTF-8 LC_NUMERIC=pt_BR.UTF-8 run _mib_to_human 1536

  [[ "${output}" == "1.5G" ]]
}
