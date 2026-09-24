# Editor settings and state

The public [flake](../../../flake.nix) selects the development applications.
[codium.nix](codium.nix) owns VSCodium's editor settings;
[filesystem.nix](../../../zion/hardware/filesystem.nix) owns persistence.
Use the [shared theme guide](../../theme/README.md) for palette selection.

## Nix settings and UI settings

VSCodium uses Home Manager's mutable-settings support. On activation,
Home Manager merges the declared settings into the saved settings file:

- A value declared in Nix is reapplied on rebuild. Change its declaration for a
  lasting change to that value.
- Other settings can be changed in the editor UI and survive rebuilds, provided
  their files remain in the persisted profile.
- Removing a setting from Nix does not necessarily remove its saved value.
  Nested objects are merged too. Reset a retired setting explicitly or remove
  its saved value as a deliberate migration.

Keep VSCodium setting names quoted in Nix, for example
`"nix.enableLanguageServer" = true;`. This produces the dotted JSON keys that
the settings interface expects. Objects such as `"nix.serverSettings"` then
contain their normal nested configuration.

## VSCodium

### Installation and ownership

[codium.nix](codium.nix) installs the normal Nix package through Home Manager,
Nix IDE, and Svelte. Nix updates the application. The extensions directory and
settings file are writable so the editor can install extensions and save UI
preferences. Rebuilds reapply the small declared baseline; other preferences
survive. No wrapper, custom profile path, or database-migration hook is needed.

The baseline disables telemetry, selects Fish for the integrated terminal, and
sets the Noto Sans Mono Nerd Font family and weights. Extension update checks
are explicitly enabled. File associations are left to the desktop's defaults
and the user's choices.

### State locations

The host's [filesystem.nix](../../../zion/hardware/filesystem.nix) persists all
three native directories:

| Location | Purpose |
| --- | --- |
| `~/.config/VSCodium` | Writable user settings, workspace/session state, extension state, and unsaved-file recovery. |
| `~/.vscode-oss` | Installed extensions and launcher arguments. |
| `~/.vscode-oss-shared` | Shared application state, including workspace trust in `sharedStorage/state.vscdb`. |

`User/settings.json` is a regular file inside the first directory. Keeping only
that directory misses workspace trust. Trust stays enabled, with no pretrusted
folders. Logs under `~/.local/state/VSCodium` are temporary. The
[persistence guide](../../../zion/hardware/README-impermanence.md) describes mount
checks. Profile resets are deliberate operations, never part of a rebuild.

### Nix editing

Nix IDE uses `nil` for diagnostics, navigation, and local completion, and
`nixfmt` for formatting. Both have explicit store paths. Automatic flake
archiving, input evaluation, and NixOS-option evaluation are disabled in the
baseline. Opening a Nix file does not need to evaluate this machine's NixOS and
Home Manager configuration.

This trades automatic host-option and package completion for a simpler default.
Projects that need deeper completion can configure their language server in
`.vscode/settings.json`. The editor configuration does not depend on the host's
name, a checkout location, or a source snapshot of the host flake.

### Palette

The flake separately selects [the VSCodium theme module](../../theme/codium.nix).
It supplies the `local.shared-palette` extension, which inherits the bundled
Dark Modern theme and applies the selected shared palette. The application
module remains usable without that theme module.

Disabling the shared palette selects `Dark Modern` and removes the palette
extension. Keeping colors in an extension avoids stale nested color overrides
in mutable settings. Close and reopen the editor after changing the extension
list or palette. Use the [shared theme guide](../../theme/README.md) to select a
palette or return to native colors.

### Busy pointer on GNOME

The upstream launchers advertise `StartupNotify=true`. GNOME can keep showing
its busy pointer after an Electron window is already ready. The application
module generates user-level copies of both upstream desktop entries with
`StartupNotify=false`; launcher actions, icons, and URL handling are retained.
This changes launch feedback rather than disabling background editor work.

To investigate actual delays, use **Developer: Startup Performance** and
**Developer: Show Running Extensions**. Logs distinguish application startup,
extension activation, language-server work, and filesystem errors. In
particular, projects on network shares can have file-watcher limitations that
are separate from a lingering startup cursor.

### Isolated checks

Give a disposable instance separate user, extension, and shared-data directories:

```sh
codium --user-data-dir /tmp/codium-check/user-data \
  --extensions-dir /tmp/codium-check/extensions \
  --shared-data-dir /tmp/codium-check/shared-data
```

`--user-data-dir` alone does not isolate workspace trust. Test writable settings,
language-server formatting, palette selection, and trust across reopening.
Host persistence across reboot requires a separate check.
