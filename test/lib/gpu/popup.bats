#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../helpers.bash"

setup() {
  setup_test_environment
  unset _GPU_REVAMPED_POPUP_LOADED _TMUX_PLUGIN_PLATFORM_LOADED \
    _TMUX_PLUGIN_HAS_COMMAND_LOADED _TMUX_PLUGIN_TMUX_OPS_LOADED
  source "${BATS_TEST_DIRNAME}/../../../src/lib/gpu/popup.sh"
}

teardown() {
  cleanup_test_environment
}

@test "popup.sh - gpu_popup_command honors an override" {
  set_tmux_option "@gpu_revamped_popup_command" "my-monitor"
  [[ "$(gpu_popup_command)" == "my-monitor" ]]
}

@test "popup.sh - gpu_popup_command prefers nvtop" {
  has_command() { [[ "$1" == "nvtop" ]]; }
  [[ "$(gpu_popup_command)" == "nvtop" ]]
}

@test "popup.sh - gpu_popup_command falls back to rocm-smi" {
  has_command() { [[ "$1" == "rocm-smi" ]]; }
  [[ "$(gpu_popup_command)" == "watch -n 1 rocm-smi" ]]
}

@test "popup.sh - gpu_popup_command falls back to nvidia-smi" {
  has_command() { [[ "$1" == "nvidia-smi" ]]; }
  [[ "$(gpu_popup_command)" == "watch -n 1 nvidia-smi" ]]
}

@test "popup.sh - gpu_popup_command falls back to btop" {
  has_command() { [[ "$1" == "btop" ]]; }
  [[ "$(gpu_popup_command)" == "btop" ]]
}

@test "popup.sh - gpu_popup_command falls back to top when no monitor is installed" {
  # Arrange
  has_command() { return 1; }

  # Act
  run gpu_popup_command

  # Assert
  [[ "${output}" == "top" ]]
}

@test "popup.sh - gpu_popup drives the tmux seam without launching" {
  has_command() { [[ "$1" == "nvtop" ]]; }
  _tmux() { echo "TMUX $*"; }
  run gpu_popup
  [[ "${output}" == *"display-popup"* ]]
  [[ "${output}" == *"nvtop"* ]]
  [[ "${output}" == *"80%"* ]]
}

@test "popup.sh - gpu_popup honors custom popup size" {
  has_command() { return 1; }
  set_tmux_option "@gpu_revamped_popup_width" "60%"
  set_tmux_option "@gpu_revamped_popup_height" "50%"
  _tmux() { echo "TMUX $*"; }
  run gpu_popup
  [[ "${output}" == *"-w 60%"* ]]
  [[ "${output}" == *"-h 50%"* ]]
}

@test "popup.sh - _tmux seam forwards to tmux" {
  run _tmux set-option -gq "@gpu_revamped_seam_probe" "ok"
  [[ "$(get_tmux_option "@gpu_revamped_seam_probe" "")" == "ok" ]]
}

@test "popup.sh - gpu_doctor reports detected tools" {
  _PLATFORM_OS_CACHE="Linux"
  _PLATFORM_ARCH_CACHE="x86_64"
  has_command() { [[ "$1" == "nvidia-smi" ]]; }
  _drm_present() { return 0; }
  run gpu_doctor
  [[ "${output}" == *"OS: Linux (x86_64)"* ]]
  [[ "${output}" == *"NVIDIA probe: detected"* ]]
  [[ "${output}" == *"AMD probe: missing"* ]]
  [[ "${output}" == *"present"* ]]
  [[ "${output}" == *"NVIDIA-only"* ]]
}

@test "popup.sh - gpu_doctor asks for macmon on Apple Silicon without it" {
  # Arrange
  _PLATFORM_OS_CACHE="Darwin"
  _PLATFORM_ARCH_CACHE="arm64"
  has_command() { return 1; }
  _drm_present() { return 1; }

  # Act
  run gpu_doctor

  # Assert
  [[ "${output}" == *"absent"* ]] || false
  [[ "${output}" == *"Apple Silicon temperature: missing (macmon)"* ]] || false
  [[ "${output}" == *"note: Apple Silicon GPU temperature needs macmon, so #{gpu_temp} is empty"* ]]
}

@test "popup.sh - gpu_doctor reports macmon on Apple Silicon without a sudo note" {
  # Arrange
  _PLATFORM_OS_CACHE="Darwin"
  _PLATFORM_ARCH_CACHE="arm64"
  has_command() { [[ "${1}" == "macmon" ]]; }
  _drm_present() { return 1; }

  # Act
  run gpu_doctor

  # Assert
  [[ "${output}" == *"Apple Silicon temperature: detected (macmon)"* ]] || false
  [[ "${output}" != *"sudo"* ]] || false
  [[ "${output}" != *"needs macmon"* ]]
}

@test "popup.sh - _drm_present is callable" {
  run _drm_present
  true
}
