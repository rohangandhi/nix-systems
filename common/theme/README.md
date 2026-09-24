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

The switch is declarative and takes effect on rebuild. Reopen GTK apps and start
a fresh terminal afterward. Existing Fish sessions and tmux servers retain their
loaded colors; start a new tmux server after finishing work in the old sessions.
Editor windows may need to be reloaded.

## What turning it off does

`null` removes GTK CSS, GNOME's custom accent, Alacritty colors, Fish color
overrides, tmux styling, and VSCodium color overrides. Starship keeps its compact
layout with built-in module styles. Zed explicitly selects its built-in One Light
and One Dark themes in system mode, because its mutable settings otherwise retain
the previous selection. Its generated palette theme is removed.

Fonts, padding, key bindings, shell behavior, and the existing GNOME dark-mode
preference are independent of the palette. Disabling the palette does not change
them. Existing user-selected Fish colors can still apply when our overrides are
absent.

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
- VSCodium uses workbench, syntax, and integrated terminal color settings.
- Zed installs and selects the chosen local theme.

Fonts are configured separately. GNOME retains its default Adwaita fonts.
The shell panel, overview, and login screen keep GNOME's built-in styling;
the shell uses the palette's closest supported named accent. Browser content, Qt applications,
and apps with their own theme engines need separate integrations.

Global user CSS can be overridden by an application's own styling, and sandboxed
apps may not read the host GTK configuration.
