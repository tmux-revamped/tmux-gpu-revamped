# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- GPU temperature on macOS: `macmon` on Apple Silicon, read without sudo,
  and `osx-cpu-temp -g` on Intel, ahead of the `istats` fallback.
- `@gpu_revamped_render 'options'` replaces the `#()` calls with tmux option
  reads, written by one background process per server every
  `@gpu_revamped_interval` seconds, 5 by default. tmux reruns a `#()` call on every redraw, so a
  shared bar ran each one about once a second and painted values one by one.
- `@gpu_revamped_fixed_width 'on'` pads each value to its widest form, and
  `@gpu_revamped_<metric>_width` sets one metric's width, so a value changing
  length no longer shifts the rest of the status line.
- Metric labels. `@gpu_revamped_<metric>_label` prints an icon or word before a
  value only when the value is not empty, and `@gpu_revamped_icons` set to
  `nerd` labels every metric from a Nerd Font set. The default adds no labels.

### Changed

- The options-mode background process reads every option it needs in one tmux
  call per tick, sends its cache writes and published values in a second, and
  keeps its functions out of the environment of the commands it runs.
  Temperature, frequency, power, fan, encoder, decoder, throttle, P-state and
  top process refresh every `@gpu_revamped_detail_interval` seconds, 60 by
  default.

### Fixed

- A comma-decimal locale such as pt_BR printed memory as `1,5G`. The
  formatters now run under the C locale.

## [1.2.0] - 2026-06-29

### Added

- Cross-vendor VRAM: `#{gram_percentage}` and the new `#{gram_used}` absolute
  figure now populate on AMD (`rocm-smi`), Intel and generic Linux
  (`/sys/class/drm`), and Apple Silicon (`ioreg`), not only NVIDIA.
- History sparkline `#{gpu_graph}`, a bounded ring buffer kept in a tmux
  user-option with no temp file.
- Power draw `#{gpu_power}` and percent of TDP `#{gpu_power_pct}` on NVIDIA and
  AMD; fan speed `#{gpu_fan}` on NVIDIA and AMD.
- NVIDIA-only metrics that render empty on other vendors: encoder
  `#{gpu_enc}`, decoder `#{gpu_dec}`, throttle reason `#{gpu_throttle}`,
  performance state `#{gpu_pstate}`, and top compute app `#{gpu_top_process}`.
- Detail popup bound to `@gpu_revamped_popup_key`, opening nvtop, a vendor smi,
  or btop through `display-popup`.
- `doctor` subcommand reporting detected probes and why a token is empty,
  including the Apple Silicon temperature note.

## [1.1.1] - 2026-06-23

### Changed

- Reviewed the upstream `catppuccin/tmux` GPU work. The `#{gram_percentage}`
  VRAM placeholder already ships what catppuccin only proposed in PR #588, and
  the load, temperature, and frequency placeholders match the companion
  `tmux-cpu-revamped` plugin. No code change needed; confirmed ahead of upstream.

## [1.1.0] - 2026-06-20

### Added

- AMD (`rocm-smi`), Intel and generic Linux (`/sys/class/drm`), and Apple Silicon
  (`ioreg`) GPU load, so the plugin works beyond NVIDIA.
- GPU frequency placeholder `#{gpu_freq}` with per-chip clock tables for Apple
  Silicon and Intel Macs.
- macOS GPU temperature via `istats`.

### Changed

- Each metric now probes multiple vendors and renders empty only when no source
  exists on the host.

## [1.0.0] - 2026-06-19

### Added

- GPU load placeholders: `#{gpu_percentage}`, `#{gpu_icon}`, `#{gpu_fg_color}`,
  `#{gpu_bg_color}`.
- GPU temperature placeholders: `#{gpu_temp}`, `#{gpu_temp_icon}`,
  `#{gpu_temp_fg_color}`, `#{gpu_temp_bg_color}`.
- GPU memory placeholders: `#{gram_percentage}`, `#{gram_icon}`,
  `#{gram_fg_color}`, `#{gram_bg_color}`.
- Non-blocking design: one `nvidia-smi` query runs in a background worker and the
  three values are read from tmux user-options, with no temp files.
- Graceful empty output when no NVIDIA GPU is present.
