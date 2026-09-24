# Editor settings and state

The public [flake](../../../flake.nix) selects the development applications.
[codium.nix](codium.nix) and [zed.nix](zed.nix) own their editor settings;
[filesystem.nix](../../../zion/hardware/filesystem.nix) owns persistence.
Use the [shared theme guide](../../theme/README.md) for palette selection.

## Nix settings and UI settings

VSCodium and Zed use Home Manager's mutable-settings support. On activation,
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

### State locations

The configured package uses three home directories, all declared for persistence:

| Location | Purpose |
| --- | --- |
| `~/.config/VSCodium` | User settings, workspace/session state, and unsaved-file recovery. Settings are in `User/settings.json`. |
| `~/.vscode-oss` | Installed extensions and launcher arguments. |
| `~/.vscode-oss-shared` | Shared application state, including workspace trust in `sharedStorage/state.vscdb`. |

The trust database is separate from the main profile. Losing it can cause the
same directory to require trust again even though extensions and preferences
survive. The [persistence guide](../../../zion/hardware/README-impermanence.md)
explains the migration and mount checks. Trust stays enabled; the migration
preserves existing decisions rather than adding trusted directories.

### Settings migration and recovery

`profiles.default.mutableUserSettings = true` makes `User/settings.json` writable.
When moving from the previous generated symlink, Home Manager's link cleanup
removes the obsolete managed link before its settings merger writes a regular
file. The parent profile directory remains persistent.

Close VSCodium before this migration or other changes to its storage layout.
After switching, `settings.json` should no longer resolve into `/nix/store`.

The old read-only setup could leave a recovered, unsaved settings tab after an
editor settings migration. Fixing the file on disk does not discard that buffer.
Review the recovered draft, save any wanted edits separately, and close or revert
the stale tab. Avoid replacing the entire new settings file with an old draft.
The configured built-in fallback theme is `Dark Modern`; the older
`Default Dark Modern` name prompted a migration in the package we audited.

### Extensions and Nix support

Nix supplies VSCodium, the Nix IDE and Svelte extensions, and the local palette
extension when enabled. Application updates come through the flake. The
extensions directory remains mutable, so additional installations and extension
updates are available through the UI.

Nix IDE uses explicit store paths for `nixd` and `nixfmt`, with Nix IDE selected as
the Nix formatter. Package completion follows the pinned nixpkgs input. NixOS and
Home Manager option completion use the **public configuration snapshot from the
build**, independent of the checkout's location. Newly edited options appear in
that snapshot after a rebuild. A project's `.vscode/settings.json` can override
`nix.serverSettings` to inspect a different or live flake.

### Palette lifecycle

The local `local.shared-palette` extension contributes the `Shared Palette` theme,
labelled with the selected palette's name. It inherits the bundled Dark Modern
theme and changes workbench, syntax, and terminal colors. Color mappings live in
the theme instead of being merged into mutable user settings.

Disabling the palette explicitly selects `Dark Modern` and removes the local
extension. Home Manager refreshes the extension registry when its declared
extension list changes. Close and reopen the editor when testing these changes;
changing extension symlinks alone can leave a cached extension list.

### Testing without changing the active profile

Give a disposable VSCodium instance separate user, extension, and shared-data
directories. `--user-data-dir` alone does not isolate the workspace trust store:

```sh
codium --user-data-dir /tmp/codium-check/user-data \
  --extensions-dir /tmp/codium-check/extensions \
  --shared-data-dir /tmp/codium-check/shared-data
```

Populate that profile with the generated settings and extensions under test.
Verify that a UI setting can be saved, a trusted test workspace remains trusted
after reopening, and palette transitions work. Temporary-profile tests establish
editor behavior; persistence across a host reboot still needs a separate check.

## Zed

Zed's settings are under `~/.config/zed`; application data is under
`~/.local/share/zed`. Both directories are persisted. The Nix extension is enabled
in `zed.nix`.

The palette is generated as `~/.config/zed/themes/shared-palette.json` and selected
in the mutable settings. Disabling it explicitly selects `One Dark` and
`One Light` in system mode and removes the generated theme. Omitting the `theme`
declaration would leave the previous selection in the merged settings file.
