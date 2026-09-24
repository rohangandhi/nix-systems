# Terminal usage

[Alacritty](alacritty.nix) starts [Fish](fish.nix) directly. Fish opens with a quiet
startup and a [Starship prompt](starship.nix). System information is available on
demand, and [tmux](tmux.nix) is an optional session manager.

The public [flake](../../../flake.nix) lists each terminal module explicitly.

## Everyday commands

These shortcuts are Fish abbreviations: they expand into visible commands as you
type. `cat`, `ls`, and `du` retain their usual meanings.

| Abbreviation | Action |
| --- | --- |
| `gs` | `git status` |
| `gl` | Git graph with commit summaries, authors, relative dates, and decorations |
| `,cat` | `bat -n` |
| `,ls` | Detailed `eza` listing including hidden files and icons, with directories first |
| `,du` | `dust` summary one directory level deep |
| `,df` | `duf` filesystem usage |
| `,tmux` | `tmux new-session -A -s main`: create or attach to the `main` session |

[,info](fastfetch.nix) is a Fish function. It displays the date, a three-month
calendar, Fastfetch system information, and disk usage for the root, home, and
persistent data filesystems. It does not run on shell startup.

Keep command abbreviations in [commands.nix](commands.nix), the information
function in [fastfetch.nix](fastfetch.nix), and the session launcher in
[tmux.nix](tmux.nix).

## Prompt and sessions

Starship shows the working directory, Git branch/state, Nix shell state, and failed
exit status. Identity appears when needed, including SSH/root sessions. Commands
taking at least two seconds show their duration on the right. Transient prompts
keep previous commands compact.

tmux uses Fish, mouse support, window numbering from 1, and a 50,000-line history
limit. Its status and pane colors follow the shared palette. The setup has no
tmux plugins or session-restoration service: a tmux session can outlive its
terminal window, but its processes and scrollback do not survive reboot.

## Fonts and colors

The Noto Nerd Font package is installed by
[fonts.nix](../../../zion/os/fonts.nix). Terminal font settings are application
settings:

| Application | Font and size |
| --- | --- |
| Alacritty | `NotoSansM Nerd Font Mono`, Light at 11 pt; Medium for bold |
| VSCodium integrated terminal | The same family at 15 px, weights 300/500 |

The sizes approximately match because the applications use different units.
Noto Mono's original Regular-only face is different from the Noto Sans Mono face
selected here for its Light and Medium weights.

Installing the font package does not make it the desktop default. GNOME uses its
upstream font defaults; this configuration has no GNOME font-name or global
fontconfig default-family overrides. Keep desktop typography and terminal font
choices separate when making changes.

Colors come from [the shared palette](../../theme/README.md). Disabling it changes
color overrides while keeping terminal fonts, padding, cursor behavior, and
shortcuts. Start a fresh Fish shell after a palette change. Existing tmux servers
retain settings; start a new server after finishing work in the old sessions,
especially when testing that disabled colors return to defaults.

## Saved shell state

Fish history is persisted in `~/.local/share/fish`. Universal variables are
persisted through `~/.config/fish/fish_variables`. Its backing-file initialization
is intentional; see [the persistence guide](../../../zion/hardware/README-impermanence.md#adding-or-moving-persistent-state).

The palette uses Fish global variables for each interactive shell. It does not
rewrite saved universal colors. With the palette disabled, any user-selected
universal colors can therefore become visible again.
