# System Resources

A local GNOME Shell 50 extension installed and enabled by `common/desktop/gnome.nix`.
It uses Shell's panel button, popup menus, buttons, and level bars with native
colors. Numeric values use the same **NotoSansM Nerd Font Mono** family as the
terminal; headings and app names keep GNOME's normal font.

The top bar has three unlabeled values, in order: **CPU %**, **GPU %**, **RAM used**.
Its accessible name includes those labels. Open it for **Persistent Storage**,
**Volatile Storage**, and **Memory**. Capacity values align around the slash and
have usage bars. Memory shows RAM and VRAM together, followed by the five largest
consumers; the RAM/VRAM buttons switch the list. The dropdown scrolls when needed
at the current monitor scale. Normal GNOME keyboard navigation opens the panel
item; arrow/page keys scroll, Tab reaches the buttons, and Escape closes it.

## Readings

- Persistent storage queries `/p-os`, `/p-home`, `/p-data`, and `/p-shared` only
  when mounted. An absent drive says **Not mounted**, never the parent's usage.
  Values show used/total in binary units; bars use used/(used + user-available)
  like `df`, accounting for filesystem reserved blocks.
- Volatile Storage shows only the current user's **Home** and **Root** tmpfs
  filesystems. Bind aliases are counted once. These are filesystem allocations,
  which can include swapped-out pages, rather than a second total of physical
  RAM. `/dev/shm` (shared buffers), `/run` (system runtime files), and
  `/run/user/<uid>` (login-session runtime files) have no separate rows; their
  resident memory is still covered by the system's overall RAM reading.
- RAM used is `MemTotal - MemAvailable`, allowing for reclaimable cache.
  Volatile files and app memory overlap; these sections must not be added up.
- RAM consumers are this user's apps and services. GNOME/systemd app scopes
  group child processes and separate launches of the same desktop app. Memory
  uses PSS, proportionally accounting for shared pages. `≈` marks groups with an
  RSS fallback when PSS is inaccessible. Other users' processes are excluded;
  no elevated privileges are used. Children launched in a terminal remain part
  of that terminal's application scope.
- The AMD GPU with the largest VRAM capacity is selected, choosing this host's
  RX 7900 XT over its integrated GPU. Kernel `gpu_busy_percent` and VRAM
  counters provide usage; unsupported readings display **Unavailable** or `—`.
- VRAM consumers use the selected GPU's resident VRAM counters in readable
  `/proc/<pid>/fdinfo` files, grouped into the same apps/services as RAM. Repeated
  DRM client IDs are counted once, and shared clients are apportioned between
  app groups. The legacy AMD memory counter is an alias, not an extra amount.
  Separate clients can still share GPU buffers, and unreadable/system clients
  are excluded, so the list does not add up to the card-wide total. See the
  [kernel DRM accounting documentation](https://docs.kernel.org/gpu/drm-usage-stats.html).

CPU/GPU/RAM refresh every two seconds; storage every thirty seconds. Process
details are collected only while the menu is open. A read-only Python helper
does the I/O outside Shell; requests never overlap and time out after five
seconds. Disabling the extension cancels collection and removes all UI/timers.
There are no logs of application activity, history files, network requests,
background services, or privileged collectors.

## Build and activate

Use the complete private host's build/switch workflow in the repository README.
The GNOME module installs the extension and Home Manager enables
`system-resources@local`. Existing sessions may need a logout/login to discover
the newly installed extension. Source updates also need a new Shell session on
Wayland. Do not restart the running compositor.

Build just the extension and its accounting checks, from the public repo:

```sh
nix build path:.#checks.x86_64-linux.system-resources --no-link
```

The Python tests cover mount detection, reserved space, GPU selection,
app-memory grouping, and VRAM client deduplication/accounting. JavaScript tests
cover display formatting, column alignment, and CPU counter deltas. With GNOME
50 installed, run the isolated UI check against that built package (use
`--scale 1` to also check normal scaling):

```sh
python3 common/desktop/gnome-extensions/system-resources/tests/run-shell-test.py /nix/store/…-gnome-shell-extension-system-resources-2 --scale 2
```

This opens a separate headless compositor and D-Bus session with disposable
settings. Screenshots and its log go to `/tmp/system-resources-ui-test`. It
checks native bar styling, font selection, live readings, RAM/VRAM selection,
menu bounds, keyboard focus, and disable/re-enable during collection.
