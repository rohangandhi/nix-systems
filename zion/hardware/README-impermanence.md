# Storage and persistence

[filesystem.nix](filesystem.nix) declares the storage layout and persistence for
`zion-alpha`. The root filesystem and the user's home are separate tmpfs mounts.
Ordinary files written there disappear on reboot unless their paths are backed
by persistent storage. Home Manager recreates its generated configuration during
activation.

## Current layout

The table uses the current account, `ephemeral`; the module obtains the account
name from `my-options.user.name`.

| Visible path | Backing storage and lifetime |
| --- | --- |
| `/` | Temporary root filesystem. Selected system paths below it are persistent mounts. |
| `/home/ephemeral` | Temporary home. Only declared mounts and persisted files survive reboot. |
| `/p-os` | Persistent system storage. `/nix` is bound from `/p-os/nix`; selected system state includes NetworkManager connections, logs, and NixOS state. |
| `/p-home/ephemeral` | Persistent backing directory for selected home paths. |
| `/home/ephemeral/p-data` | Bind mount of the local persistent `/p-data` filesystem, including VM disks. |
| `/home/ephemeral/n-data` | Automounted network share containing these checkouts; availability depends on the server and network. |

The complete home directory is **not** persisted. The selected paths are in
`home.persistence."/p-home/${my-options.user.name}"` in `filesystem.nix`.
Directories use `bindfs` by default; individual persisted files use symlinks.
For example, `~/.config/VSCodium` is backed by
`/p-home/ephemeral/.config/VSCodium`.

Persistence entries also cover manually installed applications. Removing an app
module does not establish that its saved data is disposable. Keep the data and
its persistence entry until its retirement is an explicit decision.

## Why impermanence is pinned

[flake.nix](../../flake.nix) pins impermanence to
`4b3e914cdf97a5b536a889e939fb2fd2b043a170`, using the `home-manager-v1` interface.
This is a storage compatibility decision. The current interface takes
`/p-home/ephemeral` as the persistent prefix directly, and
[the Home Manager integration](../../common/input-modules/home-manager/impermanence.nix)
imports its persistence module explicitly.

Changing the input to a different interface can change both the expected module
imports and the generated storage paths. Treat that as a migration: compare the
resolved source and destination paths, prepare and back up the data, then verify
activation and reboot behavior. Updating the pin alone is not a data migration.

The explicit `fsType = "none"` declarations for the system bind mounts in
`filesystem.nix` accommodate the pinned module's filesystem declarations. Review
them together with the module imports when changing the pin.

## Adding or moving persistent state

1. Identify every directory the application uses for durable state. Its settings,
   extensions, and trust database can live in different locations.
2. Close the application before changing its storage location. Preserve its
   existing data and identify the exact destination under `/p-home` or `/p-os`.
3. Populate the persistent destination **before mounting it over the current
   path**. The pinned home module creates and mounts directories; it does not
   automatically migrate the files that the new mount hides.
4. Add the persistence declaration and any necessary migration alongside it.
   Make migrations safe to rerun and preserve an existing destination. Use an
   application's supported database backup mechanism where appropriate.
5. Evaluate and build, activate, and inspect the actual mount. Verify the saved
   state after reopening the application and after a reboot.

The `persistFishVariables` hook runs after `writeBoundary` and before
`linkGeneration`. It seeds the persistent `fish_variables` file from existing
state, or creates an empty file on first use. Fish's atomic universal-variable
writes need an existing symlink target; a dangling persistence link can be
replaced by a local file whose contents then disappear on reboot.

VSCodium needs no custom activation hook on a fresh installation. Its three
directories are mounted before Home Manager writes settings or the editor starts.
Workspace trust lives in `~/.vscode-oss-shared/sharedStorage/state.vscdb` with the
configured package. Persisting only `~/.config/VSCodium` misses it.

## Diagnose state that does not survive

Check the path the running application actually uses, then its backing mount:

```sh
findmnt -T "$HOME/.config/VSCodium"
findmnt -T "$HOME/.vscode-oss-shared"
readlink -f "$HOME/.config/fish/fish_variables"
systemctl --user list-units 'bindMount-*'
journalctl --user --boot --unit='bindMount-*'
```

For these editor directories, the mount source should point into `/p-home`,
rather than the temporary home filesystem. For `fish_variables`, the resolved
file should be under `/p-home/ephemeral/.config/fish/`. A mount can work correctly
while another application state directory is missing from persistence.

[The editor guide](../../common/apps/development/README.md) covers writable
settings and workspace trust. Repeated prompts or reopened tabs do not by
themselves establish that the entire profile was lost.

Persistent storage survives reboot; it is not a backup. Rolling back a NixOS
generation changes configuration and packages, not the contents of mutable
databases or VM disks.
