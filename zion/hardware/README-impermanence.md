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

`/p-home` is mounted by the system with `nosuid,nodev,exec`. Executable files in
persisted directories are needed by application extensions and downloaded tools;
set-user-ID bits and device nodes remain disabled. Do not add the `user` mount
option: it implicitly enables `noexec,nosuid,nodev` unless later options override
them, and the home bind mounts inherit those flags. After changing these flags,
prepare a boot generation and reboot to recreate all home bind mounts.

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

## Legacy layout and rollback

This workstation has completed the persistence migration. The old
`home-manager-v1` configuration stored data directly under
`/p-home/ephemeral` and mounted it through per-user `bindfs` services. The current
Impermanence module integrates with Home Manager automatically and uses system
bind mounts. Its revision is recorded normally in [flake.lock](../../flake.lock).

The completed migration moved the existing user directory to
`/p-home/home/ephemeral`, preserving its contents and permissions, and left
`/p-home/ephemeral -> home/ephemeral` for older generations. Keep that existing
link while retaining those generations. The current configuration neither
creates nor removes it, and fresh installations do not need it.

The one-time boot migration has been retired. Its implementation and original
instructions remain in [commit 4e5dc87](https://github.com/rohangandhi/nix-systems/commit/4e5dc87).
Normal updates use `nixos-rebuild switch`; mount-option changes require a reboot.

A small activation guard refuses an unmigrated directory at `/p-home/ephemeral`.
If restoring an old-layout backup, arrange the saved user directory at
`/p-home/home/ephemeral` from a recovery environment before activation. Inspect
both locations and preserve existing data; the guard does not merge, rename,
or delete anything. The compatibility link lets an older generation reach the
same current data, not an earlier version of it.

Keep the migration backup and previous working generation until recovery copies
are no longer needed. The local backup's `previous-system` link is also a Nix
garbage-collection root. Removing that link releases its protection for the old
system closure. A backup on `/p-data` shares the workstation's physical disk and
is unencrypted; it does not protect against failure of that disk.

Disko only prepares the actual filesystems and the install target's `/nix` bind
mount. It no longer binds the entire saved home onto the installation home, nor
runs bind mounts from the LUKS hook before filesystems are mounted. NixOS and
Impermanence create the home directories during activation.

## Persistence checks

The disposable VM check starts with an empty backing disk and exercises fresh
home creation, ownership and private file permissions, executable extension
tools, Fish's atomic universal-variable updates, the browsing shortcuts, and
persistence across a reboot. It checks rejection of an unmigrated directory and
preservation of an existing compatibility link. A test SMB server and the
workstation's actual CIFS options exercise wallpaper access as the normal user
before and after reboot. The home filesystem uses the workstation's actual
mount options so accidental `noexec` settings fail the executable-file check.

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
findmnt -T "$HOME/.config/VSCodium" -o TARGET,SOURCE,FSTYPE,OPTIONS
findmnt -T "$HOME/.vscode-oss-shared" -o TARGET,SOURCE,FSTYPE,OPTIONS
readlink -f "$HOME/.config/fish/fish_variables"
systemctl list-units --type=mount
journalctl --boot --unit=home-manager-ephemeral.service
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
