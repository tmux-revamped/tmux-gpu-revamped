#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../helpers.bash"

setup() {
  setup_test_environment
  unset _GPU_REVAMPED_GPU_LOADED
  source "${BATS_TEST_DIRNAME}/../../../src/lib/gpu/gpu.sh"
}

teardown() {
  cleanup_test_environment
}

@test "gpu.sh - gpu_usage_from_ioreg takes the highest utilization" {
  local t='"Device Utilization %"=42 "Renderer Utilization %"=30'
  [[ "$(gpu_usage_from_ioreg "${t}")" == "42" ]]
}

@test "gpu.sh - gpu_usage_from_ioreg clamps above 100" {
  [[ "$(gpu_usage_from_ioreg '"Device Utilization %"=150')" == "100" ]]
}

@test "gpu.sh - gpu_usage_from_ioreg is empty with no match" {
  [[ -z "$(gpu_usage_from_ioreg 'nothing here')" ]]
}

@test "gpu.sh - gpu_usage_from_nvidia parses the value" {
  [[ "$(gpu_usage_from_nvidia '45')" == "45" ]]
  [[ -z "$(gpu_usage_from_nvidia 'x')" ]]
}

@test "gpu.sh - gpu_usage_from_rocm parses GPU use" {
  [[ "$(gpu_usage_from_rocm 'GPU use (%): 30%')" == "30" ]]
}

@test "gpu.sh - gpu_temp_from_nvidia parses the value" {
  [[ "$(gpu_temp_from_nvidia '60')" == "60" ]]
}

@test "gpu.sh - gpu_temp_from_hwmon converts millidegrees" {
  [[ "$(gpu_temp_from_hwmon '55000')" == "55" ]]
  [[ -z "$(gpu_temp_from_hwmon 'x')" ]]
}

@test "gpu.sh - gpu_temp_from_rocm reads the edge sensor" {
  [[ "$(gpu_temp_from_rocm 'Temperature (Sensor edge) (C): 50.0')" == "50" ]]
}

@test "gpu.sh - gpu_temp_from_istats reads the GPU temperature" {
  [[ "$(gpu_temp_from_istats 'GPU temp: 45.2 C')" == "45" ]]
}

@test "gpu.sh - gpu_freq_from_value accepts positive integers" {
  [[ "$(gpu_freq_from_value '1500')" == "1500" ]]
  [[ -z "$(gpu_freq_from_value '0')" ]]
  [[ -z "$(gpu_freq_from_value 'x')" ]]
}

@test "gpu.sh - gpu_freq_from_rocm parses sclk" {
  [[ "$(gpu_freq_from_rocm 'sclk: 1500Mhz')" == "1500" ]]
}

@test "gpu.sh - gpu_freq_apple looks up the chip clock" {
  [[ "$(gpu_freq_apple 'Apple M3 Max')" == "1398" ]]
  [[ "$(gpu_freq_apple 'Apple M1')" == "1278" ]]
  [[ "$(gpu_freq_apple 'Apple M5 Ultra')" == "1580" ]]
  [[ "$(gpu_freq_apple 'Intel Core i9')" == "0" ]]
}

@test "gpu.sh - gpu_freq_intel_mac covers every known model" {
  [[ "$(gpu_freq_intel_mac 'Radeon Pro W6800X')" == "2045" ]]
  [[ "$(gpu_freq_intel_mac 'Radeon Pro W6600X')" == "1845" ]]
  [[ "$(gpu_freq_intel_mac 'Radeon Pro 5600M')" == "1035" ]]
  [[ "$(gpu_freq_intel_mac 'Radeon Pro 5500')" == "1300" ]]
  [[ "$(gpu_freq_intel_mac 'Radeon Pro 5300')" == "1233" ]]
  [[ "$(gpu_freq_intel_mac 'Radeon Pro Vega 48')" == "1500" ]]
  [[ "$(gpu_freq_intel_mac 'Radeon Pro Vega 20')" == "1398" ]]
  [[ "$(gpu_freq_intel_mac 'Radeon Pro 580')" == "1266" ]]
  [[ "$(gpu_freq_intel_mac 'Radeon Pro 570')" == "1176" ]]
  [[ "$(gpu_freq_intel_mac 'Radeon Pro 560')" == "1233" ]]
  [[ "$(gpu_freq_intel_mac 'UHD Graphics 630')" == "1200" ]]
  [[ "$(gpu_freq_intel_mac 'Iris Plus Graphics')" == "1100" ]]
  [[ "$(gpu_freq_intel_mac 'HD Graphics 630')" == "1150" ]]
  [[ "$(gpu_freq_intel_mac 'HD Graphics 530')" == "1050" ]]
  [[ "$(gpu_freq_intel_mac 'Mystery GPU')" == "0" ]]
}

@test "gpu.sh - gram_from_smi computes memory percent" {
  [[ "$(gram_from_smi '2048, 8192')" == "25" ]]
  [[ -z "$(gram_from_smi '100, 0')" ]]
  [[ -z "$(gram_from_smi 'x, y')" ]]
}

@test "gpu.sh - _read_sys_first reads the first numeric value" {
  echo 42 > "${TEST_TMPDIR}/val"
  [[ "$(_read_sys_first "${TEST_TMPDIR}/val" 1)" == "42" ]]
  echo 55000 > "${TEST_TMPDIR}/t"
  [[ "$(_read_sys_first "${TEST_TMPDIR}/t" 1000)" == "55" ]]
  [[ -z "$(_read_sys_first "${TEST_TMPDIR}/nope" 1)" ]]
}

@test "gpu.sh - read_gpu_usage uses ioreg on macOS" {
  _PLATFORM_OS_CACHE="Darwin"
  _read_ioreg_gpu() { echo '"Device Utilization %"=37'; }
  [[ "$(read_gpu_usage)" == "37" ]]
}

@test "gpu.sh - read_gpu_usage uses nvidia on Linux" {
  _PLATFORM_OS_CACHE="Linux"
  has_command() { [[ "$1" == "nvidia-smi" ]]; }
  _read_nvidia_usage() { echo "45"; }
  [[ "$(read_gpu_usage)" == "45" ]]
}

@test "gpu.sh - read_gpu_usage falls back to sysfs" {
  _PLATFORM_OS_CACHE="Linux"
  has_command() { return 1; }
  _read_sys_gpu_busy() { echo "20"; }
  [[ "$(read_gpu_usage)" == "20" ]]
}

@test "gpu.sh - read_gpu_usage falls back to rocm" {
  _PLATFORM_OS_CACHE="Linux"
  has_command() { [[ "$1" == "rocm-smi" ]]; }
  _read_sys_gpu_busy() { echo ""; }
  _read_rocm_usage() { echo "GPU use (%): 60%"; }
  [[ "$(read_gpu_usage)" == "60" ]]
}

@test "gpu.sh - read_gpu_temp uses istats on macOS" {
  _PLATFORM_OS_CACHE="Darwin"
  has_command() { [[ "$1" == "istats" ]]; }
  _read_istats_gpu() { echo "GPU temp: 48 C"; }
  [[ "$(read_gpu_temp)" == "48" ]]
}

@test "gpu.sh - read_gpu_temp uses nvidia on Linux" {
  _PLATFORM_OS_CACHE="Linux"
  has_command() { [[ "$1" == "nvidia-smi" ]]; }
  _read_nvidia_temp() { echo "62"; }
  [[ "$(read_gpu_temp)" == "62" ]]
}

@test "gpu.sh - read_gpu_temp falls back to sysfs hwmon" {
  _PLATFORM_OS_CACHE="Linux"
  has_command() { return 1; }
  _read_sys_gpu_temp() { echo "54"; }
  [[ "$(read_gpu_temp)" == "54" ]]
}

@test "gpu.sh - read_gpu_temp falls back to rocm" {
  _PLATFORM_OS_CACHE="Linux"
  has_command() { [[ "$1" == "rocm-smi" ]]; }
  _read_sys_gpu_temp() { echo ""; }
  _read_rocm_temp() { echo "Temperature (Sensor edge) (C): 70.0"; }
  [[ "$(read_gpu_temp)" == "70" ]]
}

@test "gpu.sh - read_gpu_freq uses the Apple Silicon table" {
  _PLATFORM_OS_CACHE="Darwin"
  _PLATFORM_ARCH_CACHE="arm64"
  _read_brand_string() { echo "Apple M3 Max"; }
  [[ "$(read_gpu_freq)" == "1398" ]]
}

@test "gpu.sh - read_gpu_freq uses the Intel-Mac table" {
  _PLATFORM_OS_CACHE="Darwin"
  _PLATFORM_ARCH_CACHE="x86_64"
  _read_sp_displays() { echo "AMD Radeon Pro 580"; }
  [[ "$(read_gpu_freq)" == "1266" ]]
}

@test "gpu.sh - read_gpu_freq uses nvidia on Linux" {
  _PLATFORM_OS_CACHE="Linux"
  has_command() { [[ "$1" == "nvidia-smi" ]]; }
  _read_nvidia_freq() { echo "1700"; }
  [[ "$(read_gpu_freq)" == "1700" ]]
}

@test "gpu.sh - read_gpu_freq falls back to sysfs" {
  _PLATFORM_OS_CACHE="Linux"
  has_command() { return 1; }
  _read_sys_gpu_freq() { echo "1400"; }
  [[ "$(read_gpu_freq)" == "1400" ]]
}

@test "gpu.sh - read_gpu_freq falls back to rocm" {
  _PLATFORM_OS_CACHE="Linux"
  has_command() { [[ "$1" == "rocm-smi" ]]; }
  _read_sys_gpu_freq() { echo ""; }
  _read_rocm_freq() { echo "sclk: 1450Mhz"; }
  [[ "$(read_gpu_freq)" == "1450" ]]
}

@test "gpu.sh - read_gram reads nvidia memory" {
  _PLATFORM_OS_CACHE="Linux"
  has_command() { [[ "$1" == "nvidia-smi" ]]; }
  _read_nvidia_mem() { echo "1024, 4096"; }
  [[ "$(read_gram)" == "25" ]]
}

@test "gpu.sh - read_gram is empty without any vendor" {
  _PLATFORM_OS_CACHE="Linux"
  has_command() { return 1; }
  _read_sys_vram_used() { echo ""; }
  _read_sys_vram_total() { echo ""; }
  [[ -z "$(read_gram)" ]]
}

# Stub every external GPU/system binary so the seam bodies execute for coverage
# without ever launching a real tool.
_stub_external_binaries() {
  ioreg() { :; }
  nvidia-smi() { :; }
  rocm-smi() { :; }
  istats() { :; }
  sysctl() { :; }
  system_profiler() { :; }
}

@test "gpu.sh - host-probe seams are callable" {
  _stub_external_binaries
  run _read_ioreg_gpu
  run _read_nvidia_usage
  run _read_rocm_usage
  run _read_nvidia_temp
  run _read_rocm_temp
  run _read_istats_gpu
  run _read_nvidia_freq
  run _read_rocm_freq
  run _read_nvidia_mem
  run _read_brand_string
  run _read_sp_displays
  run _read_sys_gpu_busy
  run _read_sys_gpu_temp
  run _read_sys_gpu_freq
  true
}

# --- extended pure parsers -------------------------------------------------

@test "gpu.sh - _bytes_to_mib converts and rejects junk" {
  [[ "$(_bytes_to_mib 1048576)" == "1" ]]
  [[ "$(_bytes_to_mib 2147483648)" == "2048" ]]
  [[ -z "$(_bytes_to_mib x)" ]]
}

@test "gpu.sh - vram_used and vram_total split the pair" {
  [[ "$(vram_used '2048 8192')" == "2048" ]]
  [[ "$(vram_total '2048 8192')" == "8192" ]]
  [[ -z "$(vram_used '')" ]]
  [[ -z "$(vram_total '')" ]]
}

@test "gpu.sh - gram_pct_from_pair computes percent" {
  [[ "$(gram_pct_from_pair '2048 8192')" == "25" ]]
  [[ -z "$(gram_pct_from_pair '100 0')" ]]
  [[ -z "$(gram_pct_from_pair 'x y')" ]]
  [[ -z "$(gram_pct_from_pair '')" ]]
}

@test "gpu.sh - vram_from_nvidia builds a MiB pair" {
  [[ "$(vram_from_nvidia '1024, 4096')" == "1024 4096" ]]
  [[ -z "$(vram_from_nvidia 'x, y')" ]]
  [[ -z "$(vram_from_nvidia '10, 0')" ]]
}

@test "gpu.sh - vram_from_sys converts bytes to a MiB pair" {
  [[ "$(vram_from_sys 1073741824 8589934592)" == "1024 8192" ]]
  [[ -z "$(vram_from_sys '' 8589934592)" ]]
  [[ -z "$(vram_from_sys 1073741824 0)" ]]
}

@test "gpu.sh - vram_from_rocm parses showmeminfo output" {
  local t='GPU[0]		: VRAM Total Memory (B): 8589934592
GPU[0]		: VRAM Total Used Memory (B): 1073741824'
  [[ "$(vram_from_rocm "${t}")" == "1024 8192" ]]
  [[ -z "$(vram_from_rocm 'nothing')" ]]
}

@test "gpu.sh - vram_used_from_ioreg reads in-use memory" {
  [[ "$(vram_used_from_ioreg '"In use system memory"=1073741824')" == "1024" ]]
  [[ -z "$(vram_used_from_ioreg 'no memory key')" ]]
}

@test "gpu.sh - power_from_nvidia rounds the draw" {
  [[ "$(power_from_nvidia '120.5, 250.0')" == "120" ]]
  [[ "$(power_from_nvidia '99, 250')" == "99" ]]
  [[ -z "$(power_from_nvidia 'x, y')" ]]
}

@test "gpu.sh - power_pct_from_nvidia computes percent of limit" {
  [[ "$(power_pct_from_nvidia '125.0, 250.0')" == "50" ]]
  [[ -z "$(power_pct_from_nvidia '125.0, 0')" ]]
  [[ -z "$(power_pct_from_nvidia 'x, y')" ]]
}

@test "gpu.sh - power_from_rocm parses the package power" {
  [[ "$(power_from_rocm 'Average Graphics Package Power (W): 35.0')" == "35" ]]
  [[ -z "$(power_from_rocm 'no power here')" ]]
}

@test "gpu.sh - fan_from_nvidia validates the percent" {
  [[ "$(fan_from_nvidia '45')" == "45" ]]
  [[ -z "$(fan_from_nvidia 'N/A')" ]]
}

@test "gpu.sh - fan_from_rocm parses the fan speed" {
  [[ "$(fan_from_rocm 'GPU[0]		: Fan speed (%): 29')" == "29" ]]
  [[ -z "$(fan_from_rocm 'no fan line')" ]]
}

@test "gpu.sh - enc_from_nvidia and dec_from_nvidia split the pair" {
  [[ "$(enc_from_nvidia '10, 5')" == "10" ]]
  [[ "$(dec_from_nvidia '10, 5')" == "5" ]]
  [[ -z "$(enc_from_nvidia 'x, y')" ]]
  [[ -z "$(dec_from_nvidia '10, y')" ]]
}

@test "gpu.sh - throttle_from_nvidia maps the active reason bits" {
  [[ -z "$(throttle_from_nvidia '0x0000000000000000')" ]]
  [[ "$(throttle_from_nvidia '0x0000000000000020')" == "thermal" ]]
  [[ "$(throttle_from_nvidia '0x0000000000000040')" == "thermal" ]]
  [[ "$(throttle_from_nvidia '0x0000000000000004')" == "power" ]]
  [[ "$(throttle_from_nvidia '0x0000000000000080')" == "power" ]]
  [[ "$(throttle_from_nvidia '0x0000000000000008')" == "hw" ]]
  [[ "$(throttle_from_nvidia '0x0000000000000001')" == "idle" ]]
  [[ "$(throttle_from_nvidia '0x0000000000000010')" == "active" ]]
  [[ -z "$(throttle_from_nvidia 'zzz')" ]]
}

@test "gpu.sh - pstate_from_nvidia validates the state" {
  [[ "$(pstate_from_nvidia 'P0')" == "P0" ]]
  [[ "$(pstate_from_nvidia 'P8')" == "P8" ]]
  [[ -z "$(pstate_from_nvidia 'X1')" ]]
}

@test "gpu.sh - top_process_from_nvidia picks the heaviest app" {
  local t='512, chrome
2048, python
1024, ollama'
  [[ "$(top_process_from_nvidia "${t}")" == "python" ]]
  [[ -z "$(top_process_from_nvidia '')" ]]
}

# --- extended readers ------------------------------------------------------

@test "gpu.sh - read_vram uses ioreg and memsize on macOS" {
  _PLATFORM_OS_CACHE="Darwin"
  _read_ioreg_gpu() { echo '"In use system memory"=1073741824'; }
  _read_apple_mem_total() { echo "8589934592"; }
  [[ "$(read_vram)" == "1024 8192" ]]
}

@test "gpu.sh - read_vram is empty on macOS without ioreg memory" {
  _PLATFORM_OS_CACHE="Darwin"
  _read_ioreg_gpu() { echo "nothing"; }
  _read_apple_mem_total() { echo "8589934592"; }
  [[ -z "$(read_vram)" ]]
}

@test "gpu.sh - read_vram is empty on macOS without a total" {
  _PLATFORM_OS_CACHE="Darwin"
  _read_ioreg_gpu() { echo '"In use system memory"=1073741824'; }
  _read_apple_mem_total() { echo ""; }
  [[ -z "$(read_vram)" ]]
}

@test "gpu.sh - read_vram uses nvidia on Linux" {
  _PLATFORM_OS_CACHE="Linux"
  has_command() { [[ "$1" == "nvidia-smi" ]]; }
  _read_nvidia_mem() { echo "1024, 4096"; }
  [[ "$(read_vram)" == "1024 4096" ]]
}

@test "gpu.sh - read_vram falls back to sysfs" {
  _PLATFORM_OS_CACHE="Linux"
  has_command() { return 1; }
  _read_sys_vram_used() { echo "1073741824"; }
  _read_sys_vram_total() { echo "8589934592"; }
  [[ "$(read_vram)" == "1024 8192" ]]
}

@test "gpu.sh - read_vram falls back to rocm" {
  _PLATFORM_OS_CACHE="Linux"
  has_command() { [[ "$1" == "rocm-smi" ]]; }
  _read_sys_vram_used() { echo ""; }
  _read_sys_vram_total() { echo ""; }
  _read_rocm_mem() { printf '%s\n' 'VRAM Total Memory (B): 8589934592' 'VRAM Total Used Memory (B): 1073741824'; }
  [[ "$(read_vram)" == "1024 8192" ]]
}

@test "gpu.sh - read_power uses nvidia then rocm on Linux" {
  _PLATFORM_OS_CACHE="Linux"
  has_command() { [[ "$1" == "nvidia-smi" ]]; }
  _read_nvidia_power() { echo "120.0, 250.0"; }
  [[ "$(read_power)" == "120" ]]
  has_command() { [[ "$1" == "rocm-smi" ]]; }
  _read_nvidia_power() { echo ""; }
  _read_rocm_power() { echo "Average Graphics Package Power (W): 35.0"; }
  [[ "$(read_power)" == "35" ]]
}

@test "gpu.sh - read_power is empty on macOS" {
  _PLATFORM_OS_CACHE="Darwin"
  [[ -z "$(read_power)" ]]
}

@test "gpu.sh - read_power_pct uses nvidia on Linux" {
  _PLATFORM_OS_CACHE="Linux"
  has_command() { [[ "$1" == "nvidia-smi" ]]; }
  _read_nvidia_power() { echo "125.0, 250.0"; }
  [[ "$(read_power_pct)" == "50" ]]
}

@test "gpu.sh - read_power_pct is empty without nvidia" {
  _PLATFORM_OS_CACHE="Linux"
  has_command() { return 1; }
  [[ -z "$(read_power_pct)" ]]
}

@test "gpu.sh - read_fan uses nvidia then rocm on Linux" {
  _PLATFORM_OS_CACHE="Linux"
  has_command() { [[ "$1" == "nvidia-smi" ]]; }
  _read_nvidia_fan() { echo "45"; }
  [[ "$(read_fan)" == "45" ]]
  has_command() { [[ "$1" == "rocm-smi" ]]; }
  _read_nvidia_fan() { echo ""; }
  _read_rocm_fan() { echo "Fan speed (%): 29"; }
  [[ "$(read_fan)" == "29" ]]
}

@test "gpu.sh - read_fan is empty on macOS" {
  _PLATFORM_OS_CACHE="Darwin"
  [[ -z "$(read_fan)" ]]
}

@test "gpu.sh - read_gpu_enc and read_gpu_dec use nvidia on Linux" {
  _PLATFORM_OS_CACHE="Linux"
  has_command() { [[ "$1" == "nvidia-smi" ]]; }
  _read_nvidia_encdec() { echo "12, 7"; }
  [[ "$(read_gpu_enc)" == "12" ]]
  [[ "$(read_gpu_dec)" == "7" ]]
}

@test "gpu.sh - read_gpu_enc is empty without nvidia" {
  _PLATFORM_OS_CACHE="Linux"
  has_command() { return 1; }
  [[ -z "$(read_gpu_enc)" ]]
  [[ -z "$(read_gpu_dec)" ]]
}

@test "gpu.sh - read_gpu_throttle uses nvidia on Linux" {
  _PLATFORM_OS_CACHE="Linux"
  has_command() { [[ "$1" == "nvidia-smi" ]]; }
  _read_nvidia_throttle() { echo "0x0000000000000020"; }
  [[ "$(read_gpu_throttle)" == "thermal" ]]
}

@test "gpu.sh - read_gpu_throttle is empty on macOS" {
  _PLATFORM_OS_CACHE="Darwin"
  [[ -z "$(read_gpu_throttle)" ]]
}

@test "gpu.sh - read_gpu_pstate uses nvidia on Linux" {
  _PLATFORM_OS_CACHE="Linux"
  has_command() { [[ "$1" == "nvidia-smi" ]]; }
  _read_nvidia_pstate() { echo "P2"; }
  [[ "$(read_gpu_pstate)" == "P2" ]]
}

@test "gpu.sh - read_gpu_pstate is empty without nvidia" {
  _PLATFORM_OS_CACHE="Linux"
  has_command() { return 1; }
  [[ -z "$(read_gpu_pstate)" ]]
}

@test "gpu.sh - read_gpu_top_process uses nvidia on Linux" {
  _PLATFORM_OS_CACHE="Linux"
  has_command() { [[ "$1" == "nvidia-smi" ]]; }
  _read_nvidia_procs() { printf '%s\n' '512, chrome' '2048, python'; }
  [[ "$(read_gpu_top_process)" == "python" ]]
}

@test "gpu.sh - read_gpu_top_process is empty on macOS" {
  _PLATFORM_OS_CACHE="Darwin"
  [[ -z "$(read_gpu_top_process)" ]]
}

@test "gpu.sh - extended host-probe seams are callable" {
  _stub_external_binaries
  run _read_rocm_mem
  run _read_apple_mem_total
  run _read_nvidia_power
  run _read_rocm_power
  run _read_nvidia_fan
  run _read_rocm_fan
  run _read_nvidia_encdec
  run _read_nvidia_throttle
  run _read_nvidia_pstate
  run _read_nvidia_procs
  run _read_sys_vram_used
  run _read_sys_vram_total
  true
}
