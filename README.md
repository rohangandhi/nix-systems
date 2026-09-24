# NixOS configuration

Flat, explicit NixOS configuration for a GNOME workstation and an isolated development VM.
Read [TENETS.md](TENETS.md) before making changes.

`flake.nix` contains the main `zion-alpha` host declaration: identity, inputs, and every selected public module. Hardware, storage, and personal preferences are public. Credentials and private services are supplied by a separate, small private extension. The public host uses a locked password placeholder; use the private extension when rebuilding the owner's machine.

Feature files contain settings; `flake.nix` selects them explicitly.

## Installation

`install.sh <flake-path#host>` installs into already-mounted `/mnt`; it never partitions or formats a disk. It prompts for the root password. Prepare storage separately and set your normal user's credentials in your host configuration first.

## Reuse modules

Exports:

- `nixosModules.default`: shared Nix, account, network, font, audio, and upstream module setup.
- `nixosModules.workstation`: shared setup, desktop, apps, proxy, and VM commands. Kept for existing external consumers.
- `nixosModules.gnome`, `proxy`, `matrix-one`, and `matrix-commands`: individual modules.

Pass `inputs = public.inputs` and the typed `my-options` values through `specialArgs`. The account name/UID, group name/GID, hostname, and display scale have no hidden owner-specific defaults. Individual app modules can also be imported directly from the input's source path.

Both grouped module exports are declared directly in `flake.nix`. The host lists its selected modules explicitly. No directory scanning or custom system builders are used.

Persistence entries in `zion/hardware/filesystem.nix` also cover manually installed tools. Keep their saved state when removing an application module.

## Development VM

`matrix-one-vm` launches the isolated guest. Its helpers are `matrix-one-ssh`, `matrix-one-waypipe`, `matrix-one-mount`, and `matrix-one-unmount`.

The persistent disk defaults to `~/p-data/vms/matrix-one-$USER.qcow2`; override it with `NIX_DISK_IMAGE`. SSH uses loopback port 2222. The private SSH key remains in `~/p-data/vms/matrix-one-$USER-ssh-private`, while only the public authorized key is shared from the corresponding `-ssh-auth` directory. Override these with `MATRIX_ONE_SSH_PRIVATE_DIR` and `MATRIX_ONE_SSH_AUTH_DIR`. The mount helper defaults to the corresponding `-fs` directory; use `MATRIX_ONE_MOUNT_DIR` to change it.

Guest network access is restricted to explicit forwards, including the host's loopback Squid proxy on port 3128. The proxy blocks private-network destinations and media domains. The Nix store is shared read-only with a disposable writable overlay. The guest has a convenience account and passwordless sudo; these settings are VM-only.

Launcher authentication setup is shared locally in `matrix/one/commands.nix`; each command remains explicit.

## Update

```sh
nix flake update
```

For local consumers, use `--override-input public ../systems --no-write-lock-file` when building or switching from a sibling checkout. This reads current edits without a commit or push; newly added files must be staged so Nix can include them. A local path input without the override still uses its locked snapshot.

Validate the owner's complete configuration from the private checkout:

```sh
nix flake check --no-build --override-input public ../systems --no-write-lock-file
```

The public host's locked password placeholder intentionally requires credentials from the private extension before the complete host can pass validation.

Remote consumers can pin this repository and update that input explicitly. Configure your own hardware, storage, preferences, and credentials before using these modules on another machine.
