# System Resources

A local GNOME Shell 50 extension installed and enabled by
`common/desktop/gnome.nix`. All source, icons, packaging and tests live here.

The top bar shows three unlabeled values: **CPU %**, **GPU %**, **RAM used**.
Its accessible name includes the labels. The menu fits without a scroll view:

- Six equal storage tiles, ordered **Root, Home** (Volatile Storage), then
  **P-Home, P-Data, P-Shared, P-OS** (Persistent Storage). Click a tile to open
  that directory in Files. Each shows total capacity and a utilization bar;
  hover or keyboard focus shows available space, without raw byte counts.
- The **CPU** card has a dense mosaic of physical cores with adjacent hardware
  threads (three core pairs across on this 12-core/24-thread host), temperature
  at the top right, power below it, RAM, and the three largest RAM consumers.
- The **GPU** card has three equal activity tiles for graphics/compute, memory
  controller and video engines. Temperature and power occupy the same positions
  as the CPU card, followed by VRAM and its three largest consumers.
- A full-width **Network** card below CPU/GPU shows system DNS servers, the
  configured NAS and router. Set `my-machine.nasAddress` and
  `my-machine.routerAddress` in the private host module; unset devices are not probed.
  Its header shows the default-route interface and local address. NAS/router
  buttons open their HTTPS interfaces. Hover/focus reveals TCP connection time,
  mounted SMB share paths, and the current default gateway.

Activity tiles and rings use five shades from a neutral derived from the theme
through the active Shell theme's accent. Rings show bands rather than exact values;
hover or keyboard focus reveals the reading and range. CPU tooltips identify
core/thread pairs without the operating system's logical CPU number. Memory is
informational, not a button; consumer names are muted and have no tooltips.

The popup uses the same native style class and corner radius as Quick Settings.
Cards, hover/focus states, bars and text take colors from the active **Shell**
theme. The shared palette now also supplies that Shell theme, including the
exact accent and contrasting icon color. Setting `my-theme.palette = null`
restores native colors. Custom drawings repaint on theme/accent changes,
including native light and high-contrast modes when the palette is disabled.
The five [Lucide icons](icons/README.md) match the preview, are bundled locally
with their license, and are recolored as symbolic icons by Shell. Labels inherit GNOME's font; numeric values use the terminal's
**NotoSansM Nerd Font Mono**. Application-only GTK styles do not style Shell.
Arrow keys and Tab move through the menu; Escape closes it.
Tooltips are raised above the popup on every show and prefer the space above
the focused/hovered item, falling below only near the screen's upper edge.

## Readings

- Persistent storage queries only mounted filesystems; missing mounts never
  report their parent filesystem's usage. Bars use used/(used + user-available),
  like `df`, accounting for reserved blocks. Tooltips report user-available space.
- Volatile Storage contains the root and current user's home tmpfs, counting
  aliases once. Allocations may include swapped-out pages. Shared/runtime tmpfs
  mounts have no separate tiles, but their resident memory is in overall RAM.
- RAM used is `MemTotal - MemAvailable`, allowing for reclaimable cache. Volatile
  files and app memory overlap; these sections must not be added together.
- RAM consumers are this user's apps and services, grouped by systemd app scope
  with shared pages apportioned using PSS. `≈` marks an RSS fallback. Children
  launched in a terminal remain part of that terminal's application scope.
- CPU usage uses `/proc/stat` deltas, with topology from sysfs. The mosaic groups
  by physical package/core and labels those groups in order. First samples,
  counter resets and unsupported readings remain unknown rather than zero.
- CPU temperature uses k10temp Tctl. This Ryzen 9 7900 has a documented 95°C
  limit. Package power comes from Raphael's readable AMDGPU SoC PPT sensor and
  **includes integrated graphics and SoC**, not just CPU cores. The 0–100 W
  gauge reference is a display scale, not a measured cap or a safety limit.
- The AMD GPU with the largest VRAM capacity is selected (this host's RX 7900 XT).
  `gpu_busy_percent`, `mem_busy_percent` and the version-checked `gpu_metrics`
  v1.1–v1.3 prefix provide activity; unknown metric layouts are not guessed.
  Temperature uses **edge**, not hotspot, with its reported critical limit;
  power uses average board/SoC power and the reported power cap.
- Thermal bands are below 40, 40–60, 60–80, 80–90, and 90+ °C for the CPU;
  the GPU's final boundary is 95°C. These are display ranges, not alarms.
  They leave normal sustained workloads room: published Ryzen 7900 testing
  measured 70–79°C at stock, and RX 7900 XT testing measured 65°C edge/77°C
  hotspot under its stated test conditions. The highest shade starts near the
  relevant hardware limit. See [AMD's CPU specification](https://www.amd.com/en/products/processors/desktops/ryzen/7000-series/amd-ryzen-9-7900.html),
  [CPU measurements](https://www.techspot.com/review/2602-amd-ryzen-7600-7700-7900/),
  [GPU measurements](https://www.techspot.com/review/2589-amd-radeon-7900-xt/), and
  [kernel sensor semantics](https://docs.kernel.org/gpu/amdgpu/thermal.html#hwmon-interfaces).
- VRAM consumers use the selected GPU's resident counters in readable
  `/proc/<pid>/fdinfo`. DRM client IDs are deduplicated and shared clients
  apportioned between app groups. Separate clients may still share buffers;
  unreadable/system clients are excluded, so the list is not an additive
  card-wide total. The legacy AMD counter is an alias, not an extra allocation.
  See [DRM accounting](https://docs.kernel.org/gpu/drm-usage-stats.html).
- DNS comes from `/etc/resolv.conf`; NetworkManager connection DNS servers are
  also available in the tooltip when they differ (e.g. a local stub resolver).
  These are configured servers, not a per-query log; split DNS, VPNs and browser
  secure DNS can select other resolvers. The lowest-metric default route in the
  main routing table is used, preferring IPv4, with an IPv6 fallback.
- Network device reachability means a TCP connection to **port 443**, not a
  TLS/HTTP health check, Internet connectivity test, or ICMP ping. Only the two
  configured addresses are probed, with a 600 ms timeout, concurrently. Mount
  status is read from `/proc/self/mountinfo` without touching or automounting NAS
  files. A mounted share does not prove that its server is responding. Reading
  NAS disk/RAID health or router client/traffic data would require a separate
  authenticated API/SNMP integration; this extension stores no credentials.

Totals refresh every two seconds; storage every thirty seconds. Per-thread
counters/topology, sensors and process details are collected only while the menu
is open. A read-only Python helper does the I/O outside Shell, without elevated
privileges. Network collection runs separately every sixteen seconds (the first
two-second tick after fifteen seconds), only with the menu open; its timeouts
cannot delay CPU/RAM updates. Each collection lane allows one request at a time
and times out after five seconds. Disabling cancels both collectors and removes
all actors, tooltips and timers. No activity history, background services or
privileged helpers are used.

## Build and activate

Use the complete private host's build/switch workflow in the repository README.
The GNOME module already installs the package and Home Manager enables
`system-resources@local`; no separate configuration entry is needed. Source
updates on Wayland need a new Shell session after switching the configuration.
Do not restart the running compositor.

Build the extension and its accounting checks from the public repo:

```sh
nix build path:.#checks.x86_64-linux.system-resources --no-link
```

Python tests cover storage/accounting, physical topology, sensor selection,
versioned GPU metrics, RAM/VRAM grouping, network parsing and timeout handling. JavaScript tests cover formatting,
counter deltas and band boundaries. With GNOME 50 installed, verify the native
UI against the built package at both scales:

```sh
python3 common/desktop/gnome-extensions/system-resources/tests/run-shell-test.py /nix/store/…-gnome-shell-extension-system-resources-3 --scale 1
python3 common/desktop/gnome-extensions/system-resources/tests/run-shell-test.py /nix/store/…-gnome-shell-extension-system-resources-3 --scale 2
```

This uses a separate headless compositor, D-Bus session and disposable settings.
It checks live readings, equal tile widths, capacity truncation, card/sensor
alignment, centered gauge icons, network columns, keyboard focus, directory and
device web links, tooltip stacking/placement, live accent/light/high-contrast
changes, and cleanup during in-flight resource and network requests.
Screenshots and the session log go to `/tmp/system-resources-ui-test` by default.

To also check shared palettes, add `--themes cases.json --user-themes
/nix/store/…-gnome-shell-extension-user-themes-76`. The JSON file is an array of
cases with `name` (for example `shared-midnight-jade`), `package` (the built Shell
theme's store path), and `colors` (the palette's `background`, `surface`,
`foreground`, and `accent` hex values). The check loads each theme through User
Themes, verifies actual panel/menu/bar/icon colors and repainted gauges, then
unloads it and verifies native colors return. Extension downloads are disabled
in this disposable session so only the supplied packages are tested.
