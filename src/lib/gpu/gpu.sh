#!/usr/bin/env bash
#
# gpu.sh: GPU load, temperature, frequency, memory, and extended-metric
# acquisition.
#
# Ported from yoru-revamped-tmux with multi-vendor support: NVIDIA via
# nvidia-smi, AMD via rocm-smi, Intel and generic Linux via /sys/class/drm,
# Apple Silicon via ioreg, and macOS temperature via istats. Pure parsers turn
# probe output into numbers; readers wrap the host probes behind seams tests stub.
#
# Every external command is reached through a `_read_*` seam so tests can stub it.
# No GPU tool is ever executed during tests.

[[ -n "${_GPU_REVAMPED_GPU_LOADED:-}" ]] && return 0
_GPU_REVAMPED_GPU_LOADED=1

_GPU_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${_GPU_LIB_DIR}/../utils/has-command.sh"
# shellcheck source=/dev/null
source "${_GPU_LIB_DIR}/../utils/platform.sh"

# ---------------------------------------------------------------------------
# Pure parsers
# ---------------------------------------------------------------------------

# gpu_usage_from_ioreg TEXT -> highest "Utilization %" integer, clamped to 100.
gpu_usage_from_ioreg() {
  local v
  v=$(printf '%s\n' "${1}" | grep -o '"[A-Za-z]* Utilization %"=[0-9]*' \
    | cut -d= -f2 | sort -rn | head -1)
  [[ "${v}" =~ ^[0-9]+$ ]] || { echo ""; return 0; }
  (( v > 100 )) && v=100
  echo "${v}"
}

# gpu_usage_from_nvidia TEXT -> integer utilization.
gpu_usage_from_nvidia() {
  local v
  v=$(printf '%s\n' "${1}" | head -1 | tr -d ' ')
  [[ "${v}" =~ ^[0-9]+$ ]] && echo "${v}"
}

# gpu_usage_from_rocm TEXT -> integer GPU use percent.
gpu_usage_from_rocm() {
  local v
  v=$(printf '%s\n' "${1}" | awk '/GPU use/ {gsub(/%/, ""); print $NF; exit}')
  [[ "${v}" =~ ^[0-9]+$ ]] && echo "${v}"
}

# gpu_temp_from_nvidia TEXT -> integer Celsius.
gpu_temp_from_nvidia() {
  local v
  v=$(printf '%s\n' "${1}" | head -1 | tr -d ' ')
  [[ "${v}" =~ ^[0-9]+$ ]] && echo "${v}"
}

# gpu_temp_from_hwmon MILLIDEG -> integer Celsius.
gpu_temp_from_hwmon() {
  [[ "${1}" =~ ^[0-9]+$ ]] || { echo ""; return 0; }
  echo $(( ${1} / 1000 ))
}

# gpu_temp_from_rocm TEXT -> integer Celsius from the edge sensor.
gpu_temp_from_rocm() {
  printf '%s\n' "${1}" | awk '/edge/ {for(i=1;i<=NF;i++) if($i ~ /^[0-9]+\.?[0-9]*$/) {print int($i); exit}}'
}

# gpu_temp_from_istats TEXT -> integer Celsius from `istats gpu temp`.
gpu_temp_from_istats() {
  printf '%s\n' "${1}" | awk '/GPU/ {for(i=1;i<=NF;i++) if($i ~ /[0-9]/) {gsub(/[^0-9.]/, "", $i); if($i != "") {print int($i); exit}}}'
}

# gpu_freq_from_value VALUE -> the value when it is a positive integer.
gpu_freq_from_value() {
  [[ "${1}" =~ ^[0-9]+$ ]] && (( ${1} > 0 )) && echo "${1}"
}

# gpu_freq_from_rocm TEXT -> integer MHz from the sclk line.
gpu_freq_from_rocm() {
  printf '%s\n' "${1}" | awk '/sclk/ && /Mhz/ {gsub(/[^0-9]/, "", $2); print $2; exit}'
}

# gpu_freq_apple BRAND_STRING -> max GPU clock MHz for an Apple Silicon chip.
gpu_freq_apple() {
  local brand="${1}" gen variant
  gen=$(printf '%s' "${brand}" | grep -oE 'M[1-5]' | grep -oE '[1-5]' | head -1)
  [[ "${gen}" =~ ^[1-5]$ ]] || { echo "0"; return 0; }
  variant=$(printf '%s' "${brand}" | grep -oE '(Pro|Max|Ultra)' | head -1)
  local base=(0 1278 1398 1398 1580 1580)
  local max=(0 1296 1398 1398 1580 1580)
  case "${variant}" in
    Ultra|Max) echo "${max[gen]}" ;;
    *)         echo "${base[gen]}" ;;
  esac
}

# gpu_freq_intel_mac MODEL -> base clock MHz for known Intel-Mac GPUs.
gpu_freq_intel_mac() {
  case "${1}" in
    *"Radeon Pro W6800X"*) echo 2045 ;;
    *"Radeon Pro W6600X"*) echo 1845 ;;
    *"Radeon Pro 5600M"*)  echo 1035 ;;
    *"Radeon Pro 5500"*)   echo 1300 ;;
    *"Radeon Pro 5300"*)   echo 1233 ;;
    *"Radeon Pro Vega"*48*) echo 1500 ;;
    *"Radeon Pro Vega"*20*) echo 1398 ;;
    *"Radeon Pro 580"*)    echo 1266 ;;
    *"Radeon Pro 570"*)    echo 1176 ;;
    *"Radeon Pro 560"*)    echo 1233 ;;
    *"UHD Graphics 630"*)  echo 1200 ;;
    *"Iris Plus"*)         echo 1100 ;;
    *"HD Graphics 630"*)   echo 1150 ;;
    *"HD Graphics 530"*)   echo 1050 ;;
    *)                     echo 0 ;;
  esac
}

# gram_from_smi LINE -> integer percent from "used, total" memory CSV.
gram_from_smi() {
  local -a f
  read -ra f <<< "${1//,/ }"
  local used="${f[0]:-}" total="${f[1]:-}"
  [[ "${used}" =~ ^[0-9]+$ && "${total}" =~ ^[0-9]+$ && "${total}" -gt 0 ]] || { echo ""; return 0; }
  LC_ALL=C awk -v u="${used}" -v t="${total}" 'BEGIN { printf "%.0f", (u / t) * 100 }'
}

# _bytes_to_mib BYTES -> integer mebibytes, empty for non-numeric input.
_bytes_to_mib() {
  [[ "${1}" =~ ^[0-9]+$ ]] || { echo ""; return 0; }
  echo $(( ${1} / 1048576 ))
}

# vram_used PAIR -> first field ("USED TOTAL" in MiB), empty when blank.
vram_used() {
  local -a f
  read -ra f <<< "${1}"
  echo "${f[0]:-}"
}

# vram_total PAIR -> second field of "USED TOTAL".
vram_total() {
  local -a f
  read -ra f <<< "${1}"
  echo "${f[1]:-}"
}

# gram_pct_from_pair PAIR -> integer percent from "USED TOTAL" (space separated).
gram_pct_from_pair() {
  local -a f
  read -ra f <<< "${1}"
  local used="${f[0]:-}" total="${f[1]:-}"
  [[ "${used}" =~ ^[0-9]+$ && "${total}" =~ ^[0-9]+$ && "${total}" -gt 0 ]] || { echo ""; return 0; }
  LC_ALL=C awk -v u="${used}" -v t="${total}" 'BEGIN { printf "%.0f", (u / t) * 100 }'
}

# vram_from_nvidia LINE -> "USED TOTAL" MiB from "used, total" CSV.
vram_from_nvidia() {
  local -a f
  read -ra f <<< "${1//,/ }"
  local used="${f[0]:-}" total="${f[1]:-}"
  [[ "${used}" =~ ^[0-9]+$ && "${total}" =~ ^[0-9]+$ && "${total}" -gt 0 ]] || { echo ""; return 0; }
  echo "${used} ${total}"
}

# vram_from_sys USED_BYTES TOTAL_BYTES -> "USED TOTAL" MiB, empty when invalid.
vram_from_sys() {
  local used total
  used=$(_bytes_to_mib "${1}")
  total=$(_bytes_to_mib "${2}")
  [[ "${used}" =~ ^[0-9]+$ && "${total}" =~ ^[0-9]+$ && "${total}" -gt 0 ]] || { echo ""; return 0; }
  echo "${used} ${total}"
}

# vram_from_rocm TEXT -> "USED TOTAL" MiB from `rocm-smi --showmeminfo vram`.
vram_from_rocm() {
  local used total
  total=$(printf '%s\n' "${1}" | awk '/VRAM Total Memory/ {gsub(/[^0-9]/, "", $NF); print $NF; exit}')
  used=$(printf '%s\n' "${1}" | awk '/VRAM Total Used Memory/ {gsub(/[^0-9]/, "", $NF); print $NF; exit}')
  used=$(_bytes_to_mib "${used}")
  total=$(_bytes_to_mib "${total}")
  [[ "${used}" =~ ^[0-9]+$ && "${total}" =~ ^[0-9]+$ && "${total}" -gt 0 ]] || { echo ""; return 0; }
  echo "${used} ${total}"
}

# vram_used_from_ioreg TEXT -> in-use GPU memory in MiB from an IOAccelerator dump.
vram_used_from_ioreg() {
  local bytes
  bytes=$(printf '%s\n' "${1}" | grep -o '"In use system memory"=[0-9]*' \
    | cut -d= -f2 | sort -rn | head -1)
  _bytes_to_mib "${bytes}"
}

# power_from_nvidia LINE -> integer watts from "draw, limit".
power_from_nvidia() {
  local -a f
  read -ra f <<< "${1//,/ }"
  local draw="${f[0]:-}"
  [[ "${draw}" =~ ^[0-9]+\.?[0-9]*$ ]] || { echo ""; return 0; }
  LC_ALL=C awk -v d="${draw}" 'BEGIN { printf "%.0f", d }'
}

# power_pct_from_nvidia LINE -> draw as integer percent of limit.
power_pct_from_nvidia() {
  local -a f
  read -ra f <<< "${1//,/ }"
  local draw="${f[0]:-}" limit="${f[1]:-}"
  [[ "${draw}" =~ ^[0-9]+\.?[0-9]*$ && "${limit}" =~ ^[0-9]+\.?[0-9]*$ ]] || { echo ""; return 0; }
  LC_ALL=C awk -v d="${draw}" -v l="${limit}" 'BEGIN { if (l <= 0) exit 0; printf "%.0f", (d / l) * 100 }'
}

# power_from_rocm TEXT -> integer watts from the rocm power line.
power_from_rocm() {
  local w
  w=$(printf '%s\n' "${1}" | awk '/Average Graphics Package Power/ {gsub(/[^0-9.]/, "", $NF); print $NF; exit}')
  [[ "${w}" =~ ^[0-9]+\.?[0-9]*$ ]] || { echo ""; return 0; }
  LC_ALL=C awk -v w="${w}" 'BEGIN { printf "%.0f", w }'
}

# fan_from_nvidia VALUE -> integer fan percent.
fan_from_nvidia() {
  local v
  v=$(printf '%s\n' "${1}" | head -1 | tr -d ' ')
  [[ "${v}" =~ ^[0-9]+$ ]] && echo "${v}"
}

# fan_from_rocm TEXT -> integer fan percent from "Fan speed (%): N".
fan_from_rocm() {
  printf '%s\n' "${1}" | awk -F: '/Fan speed/ {gsub(/[^0-9]/, "", $NF); if ($NF != "") {print $NF; exit}}'
}

# enc_from_nvidia LINE -> encoder utilization (first field of "enc, dec").
enc_from_nvidia() {
  local -a f
  read -ra f <<< "${1//,/ }"
  [[ "${f[0]:-}" =~ ^[0-9]+$ ]] && echo "${f[0]}"
}

# dec_from_nvidia LINE -> decoder utilization (second field of "enc, dec").
dec_from_nvidia() {
  local -a f
  read -ra f <<< "${1//,/ }"
  [[ "${f[1]:-}" =~ ^[0-9]+$ ]] && echo "${f[1]}"
}

# throttle_from_nvidia HEX -> a single throttle-reason word, empty when none.
throttle_from_nvidia() {
  local hex="${1}" reasons
  hex=$(printf '%s' "${hex}" | tr -d ' ' | sed 's/^0[xX]//')
  [[ "${hex}" =~ ^[0-9a-fA-F]+$ ]] || { echo ""; return 0; }
  reasons=$(( 16#${hex} ))
  (( reasons == 0 )) && { echo ""; return 0; }
  if (( reasons & 0x60 )); then
    echo "thermal"
  elif (( reasons & 0xC4 )); then
    echo "power"
  elif (( reasons & 0x8 )); then
    echo "hw"
  elif (( reasons & 0x1 )); then
    echo "idle"
  else
    echo "active"
  fi
}

# pstate_from_nvidia VALUE -> the performance state when shaped like "P0".
pstate_from_nvidia() {
  local v
  v=$(printf '%s\n' "${1}" | head -1 | tr -d ' ')
  [[ "${v}" =~ ^P[0-9]+$ ]] && echo "${v}"
}

# top_process_from_nvidia TEXT -> name of the compute app using the most memory.
top_process_from_nvidia() {
  printf '%s\n' "${1}" \
    | awk -F, 'NF >= 2 {n=$1+0; name=$2; sub(/^[ \t]+/, "", name); if (n >= max) {max=n; top=name}} END {if (top != "") print top}'
}

# ---------------------------------------------------------------------------
# Host-probe seams (tests override these)
# ---------------------------------------------------------------------------

_read_ioreg_gpu() { ioreg -r -d 1 -w 0 -c IOAccelerator 2>/dev/null; }
_read_nvidia_usage() { nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null; }
_read_rocm_usage() { rocm-smi -u 2>/dev/null; }
_read_nvidia_temp() { nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null; }
_read_rocm_temp() { rocm-smi -t 2>/dev/null; }
_read_istats_gpu() { istats gpu temp 2>/dev/null; }
_read_nvidia_freq() { nvidia-smi --query-gpu=clocks.current.graphics --format=csv,noheader,nounits 2>/dev/null; }
_read_rocm_freq() { rocm-smi --showclocks 2>/dev/null; }
_read_nvidia_mem() { nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | head -1; }
_read_rocm_mem() { rocm-smi --showmeminfo vram 2>/dev/null; }
_read_apple_mem_total() { sysctl -n hw.memsize 2>/dev/null; }
_read_nvidia_power() { nvidia-smi --query-gpu=power.draw,power.limit --format=csv,noheader,nounits 2>/dev/null | head -1; }
_read_rocm_power() { rocm-smi -P 2>/dev/null; }
_read_nvidia_fan() { nvidia-smi --query-gpu=fan.speed --format=csv,noheader,nounits 2>/dev/null; }
_read_rocm_fan() { rocm-smi -f 2>/dev/null; }
_read_nvidia_encdec() { nvidia-smi --query-gpu=utilization.encoder,utilization.decoder --format=csv,noheader,nounits 2>/dev/null | head -1; }
_read_nvidia_throttle() { nvidia-smi --query-gpu=clocks_throttle_reasons.active --format=csv,noheader 2>/dev/null | head -1; }
_read_nvidia_pstate() { nvidia-smi --query-gpu=pstate --format=csv,noheader 2>/dev/null | head -1; }
_read_nvidia_procs() { nvidia-smi --query-compute-apps=used_memory,process_name --format=csv,noheader,nounits 2>/dev/null; }
_read_brand_string() { sysctl -n machdep.cpu.brand_string 2>/dev/null; }
_read_sp_displays() { system_profiler SPDisplaysDataType 2>/dev/null | awk -F: '/Chipset Model/ {gsub(/^[ \t]+/, "", $2); print $2; exit}'; }

# _read_sys_first GLOB DIVISOR -> first readable numeric value under GLOB,
# divided by DIVISOR (1 for none). Used for /sys/class/drm probes.
_read_sys_first() {
  local glob="${1}" div="${2:-1}" f v
  for f in ${glob}; do
    [[ -r "${f}" ]] || continue
    v=$(cat "${f}" 2>/dev/null)
    [[ "${v}" =~ ^[0-9]+$ ]] || continue
    (( div > 1 )) && v=$(( v / div ))
    echo "${v}"
    return 0
  done
}

_read_sys_gpu_busy() { _read_sys_first "/sys/class/drm/card[0-9]*/device/gpu_busy_percent" 1; }
_read_sys_gpu_temp() { _read_sys_first "/sys/class/drm/card[0-9]*/device/hwmon/hwmon*/temp1_input" 1000; }
_read_sys_gpu_freq() { _read_sys_first "/sys/class/drm/card[0-9]*/gt_cur_freq_mhz" 1; }
_read_sys_vram_used() { _read_sys_first "/sys/class/drm/card[0-9]*/device/mem_info_vram_used" 1; }
_read_sys_vram_total() { _read_sys_first "/sys/class/drm/card[0-9]*/device/mem_info_vram_total" 1; }

# ---------------------------------------------------------------------------
# Readers (the worker calls these)
# ---------------------------------------------------------------------------

read_gpu_usage() {
  if is_macos; then
    gpu_usage_from_ioreg "$(_read_ioreg_gpu)"
  elif is_linux; then
    if has_command nvidia-smi; then
      local v; v=$(gpu_usage_from_nvidia "$(_read_nvidia_usage)"); [[ -n "${v}" ]] && { echo "${v}"; return 0; }
    fi
    local s; s=$(_read_sys_gpu_busy); [[ -n "${s}" ]] && { echo "${s}"; return 0; }
    if has_command rocm-smi; then
      gpu_usage_from_rocm "$(_read_rocm_usage)"
    fi
  fi
}

read_gpu_temp() {
  if is_macos; then
    has_command istats && gpu_temp_from_istats "$(_read_istats_gpu)"
  elif is_linux; then
    if has_command nvidia-smi; then
      local v; v=$(gpu_temp_from_nvidia "$(_read_nvidia_temp)"); [[ -n "${v}" ]] && { echo "${v}"; return 0; }
    fi
    local s; s=$(_read_sys_gpu_temp); [[ -n "${s}" ]] && { echo "${s}"; return 0; }
    if has_command rocm-smi; then
      gpu_temp_from_rocm "$(_read_rocm_temp)"
    fi
  fi
}

read_gpu_freq() {
  if is_macos; then
    if is_apple_silicon; then
      gpu_freq_apple "$(_read_brand_string)"
    else
      gpu_freq_intel_mac "$(_read_sp_displays)"
    fi
  elif is_linux; then
    if has_command nvidia-smi; then
      local v; v=$(gpu_freq_from_value "$(_read_nvidia_freq | head -1 | tr -d ' ')"); [[ -n "${v}" ]] && { echo "${v}"; return 0; }
    fi
    local s; s=$(_read_sys_gpu_freq); [[ -n "${s}" ]] && { echo "${s}"; return 0; }
    if has_command rocm-smi; then
      gpu_freq_from_rocm "$(_read_rocm_freq)"
    fi
  fi
}

# read_vram -> "USED TOTAL" in MiB across NVIDIA, AMD, Intel/sysfs, and Apple.
read_vram() {
  if is_macos; then
    local used total
    used=$(vram_used_from_ioreg "$(_read_ioreg_gpu)")
    [[ -n "${used}" ]] || return 0
    total=$(_bytes_to_mib "$(_read_apple_mem_total)")
    [[ "${total}" =~ ^[0-9]+$ && "${total}" -gt 0 ]] || return 0
    echo "${used} ${total}"
  elif is_linux; then
    if has_command nvidia-smi; then
      local v; v=$(vram_from_nvidia "$(_read_nvidia_mem)"); [[ -n "${v}" ]] && { echo "${v}"; return 0; }
    fi
    local s; s=$(vram_from_sys "$(_read_sys_vram_used)" "$(_read_sys_vram_total)"); [[ -n "${s}" ]] && { echo "${s}"; return 0; }
    if has_command rocm-smi; then
      vram_from_rocm "$(_read_rocm_mem)"
    fi
  fi
}

# read_gram -> integer VRAM-used percent across every supported vendor.
read_gram() {
  gram_pct_from_pair "$(read_vram)"
}

read_power() {
  if is_linux; then
    if has_command nvidia-smi; then
      local v; v=$(power_from_nvidia "$(_read_nvidia_power)"); [[ -n "${v}" ]] && { echo "${v}"; return 0; }
    fi
    if has_command rocm-smi; then
      power_from_rocm "$(_read_rocm_power)"
    fi
  fi
}

read_power_pct() {
  if is_linux && has_command nvidia-smi; then
    power_pct_from_nvidia "$(_read_nvidia_power)"
  fi
}

read_fan() {
  if is_linux; then
    if has_command nvidia-smi; then
      local v; v=$(fan_from_nvidia "$(_read_nvidia_fan)"); [[ -n "${v}" ]] && { echo "${v}"; return 0; }
    fi
    if has_command rocm-smi; then
      fan_from_rocm "$(_read_rocm_fan)"
    fi
  fi
}

read_gpu_enc() {
  if is_linux && has_command nvidia-smi; then
    enc_from_nvidia "$(_read_nvidia_encdec)"
  fi
}

read_gpu_dec() {
  if is_linux && has_command nvidia-smi; then
    dec_from_nvidia "$(_read_nvidia_encdec)"
  fi
}

read_gpu_throttle() {
  if is_linux && has_command nvidia-smi; then
    throttle_from_nvidia "$(_read_nvidia_throttle)"
  fi
}

read_gpu_pstate() {
  if is_linux && has_command nvidia-smi; then
    pstate_from_nvidia "$(_read_nvidia_pstate)"
  fi
}

read_gpu_top_process() {
  if is_linux && has_command nvidia-smi; then
    top_process_from_nvidia "$(_read_nvidia_procs)"
  fi
}

export -f gpu_usage_from_ioreg gpu_usage_from_nvidia gpu_usage_from_rocm
export -f gpu_temp_from_nvidia gpu_temp_from_hwmon gpu_temp_from_rocm gpu_temp_from_istats
export -f gpu_freq_from_value gpu_freq_from_rocm gpu_freq_apple gpu_freq_intel_mac
export -f gram_from_smi _bytes_to_mib vram_used vram_total gram_pct_from_pair
export -f vram_from_nvidia vram_from_sys vram_from_rocm vram_used_from_ioreg
export -f power_from_nvidia power_pct_from_nvidia power_from_rocm
export -f fan_from_nvidia fan_from_rocm enc_from_nvidia dec_from_nvidia
export -f throttle_from_nvidia pstate_from_nvidia top_process_from_nvidia
export -f _read_ioreg_gpu _read_nvidia_usage _read_rocm_usage _read_nvidia_temp _read_rocm_temp
export -f _read_istats_gpu _read_nvidia_freq _read_rocm_freq _read_nvidia_mem _read_rocm_mem
export -f _read_apple_mem_total _read_nvidia_power _read_rocm_power _read_nvidia_fan _read_rocm_fan
export -f _read_nvidia_encdec _read_nvidia_throttle _read_nvidia_pstate _read_nvidia_procs
export -f _read_brand_string _read_sp_displays _read_sys_first
export -f _read_sys_gpu_busy _read_sys_gpu_temp _read_sys_gpu_freq
export -f _read_sys_vram_used _read_sys_vram_total
export -f read_gpu_usage read_gpu_temp read_gpu_freq read_vram read_gram
export -f read_power read_power_pct read_fan
export -f read_gpu_enc read_gpu_dec read_gpu_throttle read_gpu_pstate read_gpu_top_process
