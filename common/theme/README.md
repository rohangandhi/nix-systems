# Shared themes

Choose one value in the public `flake.nix` desktop section:

```nix
{ my-theme.palette = "midnight-jade"; } # charcoal and mint (current)
{ my-theme.palette = "nord"; }          # cool gray and blue
{ my-theme.palette = null; }            # native application colors
```

These are alternatives: keep only one declaration. Rebuild from the private
checkout as usual:

```sh
cd /home/ephemeral/n-data/nix/systems-private
sudo nixos-rebuild switch --flake .#zion-alpha --override-input public ../systems --no-write-lock-file
```

The switch is declarative and takes effect on rebuild. Applications load the
new configuration at different times:

| Application | After switching |
| --- | --- |
| GTK applications | Reopen them to load the generated CSS and settings. |
| Alacritty, Fish, and Starship | Start a fresh terminal to apply shell colors and prompt settings together. |
| tmux | Existing servers retain settings; start a new server after finishing work in the old sessions, especially when disabling the palette. |
| VSCodium and Zed | Close and reopen the editor to load the theme and extension changes. |

For changes to editor storage or settings ownership, close the editor before the
rebuild too; see [editor settings and state](../apps/development/README.md).

## What turning it off does

`null` removes GTK CSS, GNOME's custom accent, Alacritty colors, Fish color
overrides, and tmux styling. VSCodium selects Dark Modern and removes the local
palette theme; its writable settings retain unrelated UI preferences. Starship
keeps its compact layout with built-in module styles. Zed explicitly selects its
built-in One Light and One Dark themes in system mode, because its mutable
settings otherwise retain the previous selection. Its generated palette theme
is removed.

Fonts, padding, key bindings, shell behavior, and the existing GNOME dark-mode
preference are independent of the palette. Disabling the palette does not change
them. Existing user-selected Fish colors can still apply when our overrides are
absent.

## Why editors use native themes

Both editors merge declared settings into writable user settings. Removing a
declaration alone can leave its previous value on disk, including nested color
overrides. The palette therefore lives in a native theme, with an explicit
built-in theme selection when disabled.

The separately selected [VSCodium theme module](codium.nix) installs
`local.shared-palette`, with the stable theme ID `Shared Palette` and the selected
palette as its display name. It inherits Dark Modern's remaining colors and
syntax rules. Zed writes `themes/shared-palette.json`. Their generated theme files
remain Nix-managed while unrelated user settings remain writable.

## Adding a palette

Add a file under `palettes/` following `midnight-jade.nix` or `nord.nix`, then add
its explicit import to the `palettes` attribute set in `options.nix`. That registry
also supplies the allowed selector values. Names, required color roles, six-digit
hex values, and GNOME accent names are checked during Nix evaluation.

Colors are bare RGB hex strings; consumers add `#` where needed. `accent` is the
main UI highlight, independent of the ANSI green color. The current adapters are
designed for dark palettes. Nord uses the [Nord colors](https://www.nordtheme.com/docs/colors-and-palettes/)
with a brighter muted-text role for readability.

## Coverage

Each application keeps its color mapping in its own feature module:

- Alacritty, Fish, Starship, and tmux use the terminal colors.
- GNOME's module uses the colors in GTK 3 CSS and libadwaita CSS variables.
- VSCodium installs a local theme for workbench, syntax, and integrated terminal colors.
- Zed installs and selects the chosen local theme.

Fonts are configured separately; see [terminal fonts](../apps/terminal/README.md#fonts-and-colors).
GNOME retains its upstream font defaults.
The shell panel, overview, and login screen keep GNOME's built-in styling;
the shell uses the palette's closest supported named accent. Browser content, Qt applications,
and apps with their own theme engines need separate integrations.

Global user CSS can be overridden by an application's own styling, and sandboxed
apps may not read the host GTK configuration.

When changing an adapter, check Midnight Jade, Nord, and `null`, including a
transition from enabled to disabled. Verify the generated settings and the
application after restart: successful Nix evaluation alone does not establish
that old mutable settings or running processes have released the previous colors.
