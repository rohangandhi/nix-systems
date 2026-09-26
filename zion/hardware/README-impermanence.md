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
| `/p-home/home/ephemeral` | Persistent backing directory for selected home paths. |
| `/persist/os`, `/persist/home`, `/persist/data` | Browsing shortcuts to `/p-os`, `/p-home`, and `/p-data`; no extra storage or mounts. |
| `/home/ephemeral/p-data` | Bind mount of the local persistent `/p-data` filesystem, including VM disks. |
| `/home/ephemeral/n-data` | Automounted network share containing these checkouts; availability depends on the server and network. |

The complete home directory is **not** persisted. The selected paths are in
`home.persistence."/p-home"` in `filesystem.nix`. Impermanence appends the
working home path `/home/ephemeral` beneath that persistence root.
Directories use system-managed bind mounts. Fish's state file explicitly uses
a symlink so its atomic file replacements work.
For example, `~/.config/VSCodium` is backed by
`/p-home/home/ephemeral/.config/VSCodium`.

Open `/persist` in Files to browse all three persistent roots. For example,
`/persist/home/home/ephemeral/.mozilla` and
`/p-home/home/ephemeral/.mozilla` are the same files. The extra `home` is the
working path mirrored beneath the storage root. These shortcuts do not change
permissions; accessing root-owned system files still requires appropriate access.

`n-data` remains a CIFS automount at `/home/ephemeral/n-data`, backed by
`//192.168.0.108/zion`. Systemd orders the automount after the home filesystem and
the actual CIFS mount after `network-online.target`. Reading a file triggers the
mount. Both GNOME wallpaper settings keep their existing `file:///home/ephemeral/n-data/wallpapers/...`
paths; they do not move into `/p-home`. Access still requires the network server
to be available.

Persistence entries also cover manually installed applications. Removing an app
module does not establish that its saved data is disposable. Keep the data and
its persistence entry until its retirement is an explicit decision.

## Upgrading from the legacy layout

The old `home-manager-v1` configuration stored data directly under
`/p-home/ephemeral` and mounted it through per-user `bindfs` services. The current
Impermanence module integrates with Home Manager automatically and uses system
bind mounts. Its revision is recorded normally in [flake.lock](../../flake.lock).

For the first upgrade, **prepare a boot generation instead of switching the
running desktop**. Keep a backup of important persistent data. From the private
checkout, with both repositories side by side:

```sh
nix flake check --no-build --override-input public ../systems --no-write-lock-file
sudo nixos-rebuild boot --flake .#zion-alpha --override-input public ../systems --no-write-lock-file
sudo reboot
```

Before NixOS activation on the next boot, `migrate-persistent-home.service` waits
for `/p-home` to be mounted, renames `ephemeral` to `home/ephemeral` within that
filesystem, and leaves `/p-home/ephemeral -> home/ephemeral` for older generations.
There is one copy of the data. The rename preserves ownership, permissions, and
contents, including saved directories no longer listed for persistence.

The migration refuses to merge two existing home directories or follow an
unexpected link. If it stops, inspect the reported paths from a recovery
environment rather than deleting either directory. A completed migration is safe
to repeat, and the compatibility link also lets an older boot generation reach
the same current data. It does not restore an older version of that data.

An activation guard rejects a live switch while the legacy directory is still
in place. Fresh installations have no legacy data to move. Subsequent updates
can use the normal `nixos-rebuild switch` workflow.

Disko only prepares the actual filesystems and the install target's `/nix` bind
mount. It no longer binds the entire saved home onto the installation home, nor
runs bind mounts from the LUKS hook before filesystems are mounted. NixOS and
Impermanence create the home directories during activation.

The disposable VM check covers migration, compatibility paths, permissions,
the browsing shortcuts, and persistence across a reboot. It also uses a test SMB
server and the workstation's actual CIFS options to read the wallpaper path as
the normal user before and after reboot.

```sh
nix build .#checks.x86_64-linux.persistence --no-link -L
```

## Adding or moving persistent state

1. Identify every directory the application uses for durable state. Its settings,
   extensions, and trust database can live in different locations.
2. Close the application before changing its storage location. Preserve its
   existing data and identify the exact destination under `/p-home` or `/p-os`.
3. Populate the persistent destination **before mounting it over the current
   path**. Impermanence creates and mounts directories; it does not
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

GNOME Online Accounts needs both `~/.config/goa-1.0` (account definitions) and
`~/.local/share/keyrings` (credentials). Both are persisted. When adding these
mounts to an existing installation, close Settings and stop Online Accounts and
GNOME Keyring before copying their current directories into `/p-home/home/<user>`.
Back up both directories, preserve their permissions, and do not overwrite an
existing persistent destination. Activate the mounts before restarting the
services. Keep the keyring directory private (`0700`) and its files private
(`0600`).

Persistence does not unlock an encrypted login keyring. With GDM automatic login,
unlock it when prompted; password login can unlock it through PAM when its
password matches the login password. A blank Online Accounts panel can also mean
the daemon is waiting on the keyring. Check its D-Bus response and the session
journal before deleting accounts or keyrings; deleting them discards saved state.

## Diagnose state that does not survive

Check the path the running application actually uses, then its backing mount:

```sh
findmnt -T "$HOME/.config/VSCodium"
findmnt -T "$HOME/.vscode-oss-shared"
readlink -f "$HOME/.config/fish/fish_variables"
systemctl list-units --type=mount
journalctl --boot --unit=migrate-persistent-home.service
```

For these editor directories, the mount source should point into `/p-home`,
rather than the temporary home filesystem. For `fish_variables`, the resolved
file should be under `/p-home/home/ephemeral/.config/fish/`. A mount can work correctly
while another application state directory is missing from persistence.

[The editor guide](../../common/apps/development/README.md) covers writable
settings and workspace trust. Repeated prompts or reopened tabs do not by
themselves establish that the entire profile was lost.

Persistent storage survives reboot; it is not a backup. Rolling back a NixOS
generation changes configuration and packages, not the contents of mutable
databases or VM disks.
