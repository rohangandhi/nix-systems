# NixOS configuration

Flat, explicit NixOS configuration for a GNOME workstation and an isolated development VM.
Read [TENETS.md](TENETS.md) before making changes.

`flake.nix` contains the main `zion-alpha` host declaration: identity, inputs, and every selected public module. Hardware, storage, and personal preferences are public. Credentials and private services are supplied by a separate, small private extension. The public host uses a locked password placeholder; use the private extension when rebuilding the owner's machine.

The example and workstation template also list their modules directly in `flake.nix`. Feature files contain settings; they do not assemble the workstation through additional import lists.

## Try it

Build and boot a complete example without supplying a host configuration:

```sh
nix build .#example-vm
./result/bin/run-example-vm
```

The serial console automatically logs in as `demo`, with an empty password and passwordless sudo **only in this example VM**. The workstation's GNOME packages are also included. Set `QEMU_OPTS="-display gtk"` and adjust the VM graphics setting if you want a graphical preview. Keep demonstration credentials inside disposable VMs.

## Install your own workstation

```sh
mkdir workstation
cd workstation
nix flake init -t github:rohangandhi/nix-systems#workstation
```

Follow the generated README: provide your identity, hardware configuration, storage mounts, and login hash. All required implementation is public. The template uses x86_64 UEFI and ordinary persistent filesystems. It can live in your own repository or fork.

Shared feature modules include the owner's preferences: automatic GNOME login, wallpaper and editor paths, the fish greeting, and Podman storage under `/p-data`. Review these for your own machine. The example and template do not import this host's disk layout or network share.

`install.sh <flake-path#host>` installs into already-mounted `/mnt`; it never partitions or formats a disk. It prompts for the root password. Prepare storage separately and set your normal user's credentials in your host configuration first.

## Reuse modules

Exports:

- `nixosModules.default`: shared Nix, account, network, font, audio, and upstream module setup.
- `nixosModules.workstation`: shared setup, desktop, apps, proxy, and VM commands. Kept for existing external consumers; this repository's example and template list every module directly in `flake.nix`.
- `nixosModules.gnome`, `proxy`, `matrix-one`, and `matrix-commands`: individual modules.
- `templates.workstation`: a complete starting point for your own host.

Pass `inputs = public.inputs` and the typed `my-options` values through `specialArgs`, as shown in the template. The account name/UID, group name/GID, hostname, and display scale have no hidden owner-specific defaults. Individual app modules can also be imported directly from the input's source path. Optional Cursor integration uses `local.cursor.executable` and `local.cursor.icon`.

Both grouped module exports are declared directly in `flake.nix`. To keep your whole system visible in one file, follow the template's explicit module list. No directory scanning or custom system builders are used.

## Development VM

`matrix-one-vm` launches the isolated guest. Its helpers are `matrix-one-ssh`, `matrix-one-waypipe`, `matrix-one-mount`, and `matrix-one-unmount`.

The persistent disk defaults to `~/p-data/vms/matrix-one-$USER.qcow2`; override it with `NIX_DISK_IMAGE`. SSH uses loopback port 2222. The private SSH key remains in `~/p-data/vms/matrix-one-$USER-ssh-private`, while only the public authorized key is shared from the corresponding `-ssh-auth` directory. Override these with `MATRIX_ONE_SSH_PRIVATE_DIR` and `MATRIX_ONE_SSH_AUTH_DIR`. The mount helper defaults to the corresponding `-fs` directory; use `MATRIX_ONE_MOUNT_DIR` to change it.

Guest network access is restricted to explicit forwards, including the host's loopback Squid proxy on port 3128. The proxy blocks private-network destinations and media domains. The Nix store is shared read-only with a disposable writable overlay. The guest has a convenience account and passwordless sudo; these settings are VM-only.

## Update

```sh
nix flake update
nix build .#example-vm
```

For local consumers, use `--override-input public ../systems --no-write-lock-file` when building or switching from a sibling checkout. This reads current edits without a commit or push; newly added files must be staged so Nix can include them. A local path input without the override still uses its locked snapshot.

Remote consumers can pin this repository and update that input explicitly. The example and template provide independent entry points for another owner; choose your own hardware, storage, and credentials before installation.
