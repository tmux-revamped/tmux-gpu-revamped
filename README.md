<div align="center">

<h1>tmux-gpu-revamped</h1>

**GPU load, temperature, frequency, and memory for your tmux status bar.**

[![Tests](https://github.com/tmux-revamped/tmux-gpu-revamped/actions/workflows/tests.yml/badge.svg)](https://github.com/tmux-revamped/tmux-gpu-revamped/actions/workflows/tests.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE) [![Version](https://img.shields.io/badge/version-1.2.0-blue.svg)](CHANGELOG.md)

</div>

**23** placeholders · **4** vendors · **193** tests · **95%+** coverage

GPU load, temperature, frequency, and memory in your tmux status line across NVIDIA, AMD, Intel, and Apple Silicon. A detached background worker probes the GPU and writes values to tmux server user-options, so the status render never blocks and no temp files are written. When a metric has no source on the host the matching placeholders render empty.

Built from [tmux-plugin-template](https://github.com/tmux-revamped/tmux-plugin-template).

<table>
<tr>
<td><b>Non-blocking</b><br/>A detached worker probes the GPU while the status line reads cached user-options instantly.</td>
<td><b>No temp files</b><br/>Values live in tmux server user-options, never on disk.</td>
</tr>
<tr>
<td><b>Four GPU vendors</b><br/>NVIDIA, AMD, Intel, and Apple Silicon, each with its own probe path.</td>
<td><b>Tested</b><br/>193 bats tests hold coverage above 95 percent.</td>
</tr>
</table>

## Placeholders

| Placeholder | Output |
|-------------|--------|
| `#{gpu_percentage}` | GPU load, for example `45%` |
| `#{gpu_icon}` | a tier icon for the load |
| `#{gpu_fg_color}` / `#{gpu_bg_color}` | colors for the load tier |
| `#{gpu_temp}` | GPU temperature, for example `60°C` |
| `#{gpu_temp_icon}` | a tier icon for the temperature |
| `#{gpu_temp_fg_color}` / `#{gpu_temp_bg_color}` | colors for the temperature tier |
| `#{gpu_freq}` | GPU clock, for example `1398MHz` |
| `#{gpu_graph}` | load history sparkline, for example `▁▃▅█` |
| `#{gpu_power}` | power draw in watts, for example `120W` (NVIDIA, AMD) |
| `#{gpu_power_pct}` | power draw as percent of TDP (NVIDIA) |
| `#{gpu_fan}` | fan speed percent (NVIDIA, AMD) |
| `#{gpu_enc}` / `#{gpu_dec}` | encoder / decoder utilization percent (NVIDIA) |
| `#{gpu_throttle}` | active throttle reason such as `thermal` (NVIDIA) |
| `#{gpu_pstate}` | performance state such as `P0` (NVIDIA) |
| `#{gpu_top_process}` | top GPU compute app name (NVIDIA) |
| `#{gram_percentage}` | GPU memory used, for example `25%` |
| `#{gram_icon}` | a tier icon for memory |
| `#{gram_fg_color}` / `#{gram_bg_color}` | colors for the memory tier |
| `#{gram_used}` | absolute VRAM, for example `18G / 24G` |

Power and fan come from NVIDIA and AMD. Encoder, decoder, throttle reason,
performance state, and top process are NVIDIA-only and render empty on other
vendors. Apple Silicon GPU temperature needs root, so `#{gpu_temp}` is empty
there. Run `src/gpu.sh doctor` to see which probes were detected on the host.

## Install

With [TPM](https://github.com/tmux-plugins/tpm):

```tmux
set -g @plugin 'tmux-revamped/tmux-gpu-revamped'
set -g status-right '#{gpu_icon} #{gpu_percentage} #{gpu_temp} #{gram_percentage}'
```

Press `prefix + I` to install.

## Configuration

| Option | Default | Meaning |
|--------|---------|---------|
| `@gpu_revamped_interval` | `5` | seconds a sample stays fresh |
| `@gpu_revamped_percentage_format` | `%s%%` | format for the load value |
| `@gpu_revamped_medium_thresh` | `30` | load percent for the medium tier |
| `@gpu_revamped_high_thresh` | `80` | load percent for the high tier |
| `@gpu_revamped_{low,medium,high}_icon` | `▰▱▱`, `▰▰▱`, `▰▰▰` | load tier icons |
| `@gpu_revamped_{low,medium,high}_{fg,bg}_color` | empty | load tier colors |
| `@gpu_revamped_temp_unit` | `C` | `C` or `F` |
| `@gpu_revamped_temp_format` | `%s°C` | format for the temperature value |
| `@gpu_revamped_temp_medium_thresh` | `65` | degrees Celsius for the medium tier |
| `@gpu_revamped_temp_high_thresh` | `80` | degrees Celsius for the high tier |
| `@gpu_revamped_temp_{low,medium,high}_icon` | empty | temperature tier icons |
| `@gpu_revamped_temp_{low,medium,high}_{fg,bg}_color` | empty | temperature tier colors |
| `@gpu_revamped_freq_format` | `%sMHz` | format for the GPU clock |
| `@gpu_revamped_gram_format` | `%s%%` | format for the memory value |
| `@gpu_revamped_gram_medium_thresh` | `50` | memory percent for the medium tier |
| `@gpu_revamped_gram_high_thresh` | `85` | memory percent for the high tier |
| `@gpu_revamped_gram_{low,medium,high}_icon` | `▰▱▱`, `▰▰▱`, `▰▰▰` | memory tier icons |
| `@gpu_revamped_gram_{low,medium,high}_{fg,bg}_color` | empty | memory tier colors |
| `@gpu_revamped_gram_abs_format` | `%s / %s` | format for `#{gram_used}` |
| `@gpu_revamped_power_format` | `%sW` | format for the power draw |
| `@gpu_revamped_power_pct_format` | `%s%%` | format for power as percent of TDP |
| `@gpu_revamped_fan_format` | `%s%%` | format for the fan speed |
| `@gpu_revamped_enc_format` / `@gpu_revamped_dec_format` | `%s%%` | format for encoder / decoder use |
| `@gpu_revamped_throttle_format` | `%s` | format for the throttle reason |
| `@gpu_revamped_pstate_format` | `%s` | format for the performance state |
| `@gpu_revamped_top_process_format` | `%s` | format for the top compute app |
| `@gpu_revamped_history_size` | `20` | samples kept for `#{gpu_graph}` |
| `@gpu_revamped_popup_key` | empty | prefix key that opens the GPU detail popup |
| `@gpu_revamped_popup_command` | auto | command run in the popup (nvtop, vendor smi, or btop) |
| `@gpu_revamped_popup_width` / `@gpu_revamped_popup_height` | `80%` | popup size |
| `@gpu_revamped_enable_logging` | `0` | set to `1` to log under `~/.tmux/gpu-revamped-logs` |

## Theme color suggestions

The defaults leave the tier colors empty, so each metric inherits its tier color from the 16 ANSI names your active theme already remaps, which matches any theme out of the box. For exact hex instead of remapped ANSI, copy one block below. Each tier maps low to green, medium to yellow, and high to red, across the load, temperature, and GPU memory families.

### Catppuccin Mocha

```tmux
set -g @gpu_revamped_low_fg_color '#[fg=#a6e3a1]'
set -g @gpu_revamped_medium_fg_color '#[fg=#f9e2af]'
set -g @gpu_revamped_high_fg_color '#[fg=#f38ba8]'
set -g @gpu_revamped_temp_low_fg_color '#[fg=#a6e3a1]'
set -g @gpu_revamped_temp_medium_fg_color '#[fg=#f9e2af]'
set -g @gpu_revamped_temp_high_fg_color '#[fg=#f38ba8]'
set -g @gpu_revamped_gram_low_fg_color '#[fg=#a6e3a1]'
set -g @gpu_revamped_gram_medium_fg_color '#[fg=#f9e2af]'
set -g @gpu_revamped_gram_high_fg_color '#[fg=#f38ba8]'
```

### Dracula

```tmux
set -g @gpu_revamped_low_fg_color '#[fg=#50fa7b]'
set -g @gpu_revamped_medium_fg_color '#[fg=#f1fa8c]'
set -g @gpu_revamped_high_fg_color '#[fg=#ff5555]'
set -g @gpu_revamped_temp_low_fg_color '#[fg=#50fa7b]'
set -g @gpu_revamped_temp_medium_fg_color '#[fg=#f1fa8c]'
set -g @gpu_revamped_temp_high_fg_color '#[fg=#ff5555]'
set -g @gpu_revamped_gram_low_fg_color '#[fg=#50fa7b]'
set -g @gpu_revamped_gram_medium_fg_color '#[fg=#f1fa8c]'
set -g @gpu_revamped_gram_high_fg_color '#[fg=#ff5555]'
```

### Nord

```tmux
set -g @gpu_revamped_low_fg_color '#[fg=#a3be8c]'
set -g @gpu_revamped_medium_fg_color '#[fg=#ebcb8b]'
set -g @gpu_revamped_high_fg_color '#[fg=#bf616a]'
set -g @gpu_revamped_temp_low_fg_color '#[fg=#a3be8c]'
set -g @gpu_revamped_temp_medium_fg_color '#[fg=#ebcb8b]'
set -g @gpu_revamped_temp_high_fg_color '#[fg=#bf616a]'
set -g @gpu_revamped_gram_low_fg_color '#[fg=#a3be8c]'
set -g @gpu_revamped_gram_medium_fg_color '#[fg=#ebcb8b]'
set -g @gpu_revamped_gram_high_fg_color '#[fg=#bf616a]'
```

### Gruvbox Dark

```tmux
set -g @gpu_revamped_low_fg_color '#[fg=#b8bb26]'
set -g @gpu_revamped_medium_fg_color '#[fg=#fabd2f]'
set -g @gpu_revamped_high_fg_color '#[fg=#fb4934]'
set -g @gpu_revamped_temp_low_fg_color '#[fg=#b8bb26]'
set -g @gpu_revamped_temp_medium_fg_color '#[fg=#fabd2f]'
set -g @gpu_revamped_temp_high_fg_color '#[fg=#fb4934]'
set -g @gpu_revamped_gram_low_fg_color '#[fg=#b8bb26]'
set -g @gpu_revamped_gram_medium_fg_color '#[fg=#fabd2f]'
set -g @gpu_revamped_gram_high_fg_color '#[fg=#fb4934]'
```

### Tokyo Night

```tmux
set -g @gpu_revamped_low_fg_color '#[fg=#9ece6a]'
set -g @gpu_revamped_medium_fg_color '#[fg=#e0af68]'
set -g @gpu_revamped_high_fg_color '#[fg=#f7768e]'
set -g @gpu_revamped_temp_low_fg_color '#[fg=#9ece6a]'
set -g @gpu_revamped_temp_medium_fg_color '#[fg=#e0af68]'
set -g @gpu_revamped_temp_high_fg_color '#[fg=#f7768e]'
set -g @gpu_revamped_gram_low_fg_color '#[fg=#9ece6a]'
set -g @gpu_revamped_gram_medium_fg_color '#[fg=#e0af68]'
set -g @gpu_revamped_gram_high_fg_color '#[fg=#f7768e]'
```

### Solarized Dark

```tmux
set -g @gpu_revamped_low_fg_color '#[fg=#859900]'
set -g @gpu_revamped_medium_fg_color '#[fg=#b58900]'
set -g @gpu_revamped_high_fg_color '#[fg=#dc322f]'
set -g @gpu_revamped_temp_low_fg_color '#[fg=#859900]'
set -g @gpu_revamped_temp_medium_fg_color '#[fg=#b58900]'
set -g @gpu_revamped_temp_high_fg_color '#[fg=#dc322f]'
set -g @gpu_revamped_gram_low_fg_color '#[fg=#859900]'
set -g @gpu_revamped_gram_medium_fg_color '#[fg=#b58900]'
set -g @gpu_revamped_gram_high_fg_color '#[fg=#dc322f]'
```

## Support by platform and architecture

| Setup | Load | Temperature | Frequency | Memory |
|-------|------|-------------|-----------|--------|
| Linux + NVIDIA (`nvidia-smi`) | yes | yes | yes | yes |
| Linux + AMD (`rocm-smi`) | yes | yes | yes | no |
| Linux + Intel or generic (`/sys/class/drm`) | yes | yes | yes | no |
| macOS Apple Silicon | yes, `ioreg` | no, see note | yes, chip table | no |
| macOS Intel | yes, `ioreg` | no, see note | yes, model table | no |

Verified on an Apple M3 Max: load reads through `ioreg` and frequency comes from a
per-chip clock table, so the GPU placeholders are populated even though there is no
`nvidia-smi`. GPU temperature on macOS is not available without elevated access: istats has no
GPU category and powermetrics needs sudo, so the macOS GPU temperature placeholder
stays empty (validated on an Apple M3 Max). GPU temperature works on Linux. GPU memory (`gram`) is NVIDIA only. Any metric with no source on
the host renders empty and never errors.

## Development

```sh
make test
make lint
make coverage
```

## License

[MIT](LICENSE), copyright Gustavo Franco.

<!-- family:begin -->

## The tmux-revamped family

This plugin is one member of the tmux-revamped family. Every member carries the
same contract in [`FAMILY.md`](FAMILY.md), the same tooling under `family/`, and
the same shared library, all held byte-identical by a checksum manifest. They are
built to be installed together: no member claims a key or a tmux option that
another member claims.

A defect found in one member is hunted across all of them before the fix is
called done. That obligation is written into the contract rather than left to
memory, and `family/bin/sweep` is how it is discharged.

| Member | What it does |
|---|---|
| [`tmux-autoreload-revamped`](https://github.com/tmux-revamped/tmux-autoreload-revamped) | Edit your tmux config, save, and watch it reload itself, no key, no command |
| [`tmux-battery-revamped`](https://github.com/tmux-revamped/tmux-battery-revamped) | Battery status for your tmux status bar, without ever blocking the status render |
| [`tmux-bluetooth-revamped`](https://github.com/tmux-revamped/tmux-bluetooth-revamped) | Every connected Bluetooth device and its battery in your tmux status bar, without blocking the render |
| [`tmux-cpu-revamped`](https://github.com/tmux-revamped/tmux-cpu-revamped) | CPU load, temperature, and frequency in your tmux status bar, without ever blocking the render |
| [`tmux-disk-revamped`](https://github.com/tmux-revamped/tmux-disk-revamped) | Disk usage for your tmux status bar, without ever blocking the status render |
| [`tmux-extract-revamped`](https://github.com/tmux-revamped/tmux-extract-revamped) | Fuzzy-grab any URL, path, or word off the screen and paste it, pure shell, no Python |
| [`tmux-fzf-revamped`](https://github.com/tmux-revamped/tmux-fzf-revamped) | Jump to any session, window, or pane, or kill it, from one fzf popup |
| [`tmux-git-revamped`](https://github.com/tmux-revamped/tmux-git-revamped) | Git repository status in your tmux status bar, without ever blocking the render |
| [`tmux-gpu-revamped`](https://github.com/tmux-revamped/tmux-gpu-revamped) | **this plugin**, GPU load, temperature, frequency, and memory for your tmux status bar |
| [`tmux-kube-revamped`](https://github.com/tmux-revamped/tmux-kube-revamped) | Current Kubernetes context and namespace in your tmux status bar, async, kubectl-free, never blocking |
| [`tmux-launcher-revamped`](https://github.com/tmux-revamped/tmux-launcher-revamped) | Launch any TUI app in a popup or a window, scoped to the current pane's directory, with one configurable bindi |
| [`tmux-logging-revamped`](https://github.com/tmux-revamped/tmux-logging-revamped) | Capture any pane to a file: live logging, full scrollback, or a one-shot screenshot |
| [`tmux-music-revamped`](https://github.com/tmux-revamped/tmux-music-revamped) | Now playing in your tmux status bar, without ever blocking the status render |
| [`tmux-network-revamped`](https://github.com/tmux-revamped/tmux-network-revamped) | Network throughput in your tmux status bar, without ever blocking the render |
| [`tmux-pain-control-revamped`](https://github.com/tmux-revamped/tmux-pain-control-revamped) | Standard pane and window management bindings for tmux, version aware, vim friendly, and fully configurable |
| [`tmux-persist-revamped`](https://github.com/tmux-revamped/tmux-persist-revamped) | One plugin that captures every session, window, pane, layout, and working |
| [`tmux-plugin-template`](https://github.com/tmux-revamped/tmux-plugin-template) | A template for building non-blocking tmux status plugins |
| [`tmux-pomodoro-revamped`](https://github.com/tmux-revamped/tmux-pomodoro-revamped) | A Pomodoro timer in your tmux status bar, with zero temp files: all state lives in tmux options |
| [`tmux-ram-revamped`](https://github.com/tmux-revamped/tmux-ram-revamped) | RAM usage for your tmux status bar, without ever blocking the status render |
| [`tmux-scroll-revamped`](https://github.com/tmux-revamped/tmux-scroll-revamped) | Mouse wheel that does the right thing: scroll the app directly, copy-mode everywhere else. No app names to con |
| [`tmux-sensible-revamped`](https://github.com/tmux-revamped/tmux-sensible-revamped) | Sensible tmux defaults that normalize behavior across every tmux version, OS, and terminal, without clobbering |
| [`tmux-tiling-revamped`](https://github.com/tmux-revamped/tmux-tiling-revamped) | --- |
| [`tmux-time-revamped`](https://github.com/tmux-revamped/tmux-time-revamped) | Local clock and world clocks in your tmux status bar, without ever blocking the render |
| [`tmux-weather-revamped`](https://github.com/tmux-revamped/tmux-weather-revamped) | Weather in your tmux status bar, fetched in the background so the render never waits on the network |

### Checking an installation

With every member on disk, one command reports any conflict between them:

```sh
family/bin/doctor --live
```

It reads each member and the running tmux server, and reports duplicate keys,
duplicate status placeholders, options outside the naming grammar, and any
member whose contract version has fallen behind.

<!-- family:end -->
