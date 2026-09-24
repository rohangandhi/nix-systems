# NixOS configuration

Flat, explicit NixOS modules for a GNOME workstation and an isolated development VM.
Read [TENETS.md](TENETS.md) before making changes.

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

`install.sh <flake-path#host>` installs into already-mounted `/mnt`; it never partitions or formats a disk. It prompts for the root password. Prepare storage separately and set your normal user's credentials in your host configuration first.

## Reuse modules

Exports:

- `nixosModules.default`: shared Nix, account, network, font, audio, and upstream module setup.
- `nixosModules.workstation`: default plus explicit desktop, app, proxy, and VM-command imports.
- `nixosModules.gnome`, `proxy`, `matrix-one`, and `matrix-commands`: individual modules.
- `templates.workstation`: a complete starting point for your own host.

Pass `inputs = public.inputs` and the typed `my-options` values through `specialArgs`, as shown in the template. The account name/UID, group name/GID, hostname, and display scale have no hidden owner-specific defaults. Individual app modules can also be imported directly from the input's source path. Optional Cursor integration uses `local.cursor.executable` and `local.cursor.icon`.

The standard module system combines explicitly listed imports. No directory scanning or custom system builders are used.

## Development VM

`matrix-one-vm` launches the isolated guest. Its helpers are `matrix-one-ssh`, `matrix-one-waypipe`, `matrix-one-mount`, and `matrix-one-unmount`.

The persistent disk defaults to `~/p-data/vms/matrix-one-$USER.qcow2`; override it with `NIX_DISK_IMAGE`. SSH uses loopback port 2222. The private SSH key remains in `~/p-data/vms/matrix-one-$USER-ssh-private`, while only the public authorized key is shared from the corresponding `-ssh-auth` directory. Override these with `MATRIX_ONE_SSH_PRIVATE_DIR` and `MATRIX_ONE_SSH_AUTH_DIR`. The mount helper defaults to the corresponding `-fs` directory; use `MATRIX_ONE_MOUNT_DIR` to change it.

Guest network access is restricted to explicit forwards, including the host's loopback Squid proxy on port 3128. The proxy blocks private-network destinations and media domains. The Nix store is shared read-only with a disposable writable overlay. The guest has a convenience account and passwordless sudo; these settings are VM-only.

## Update

```sh
nix flake update
nix build .#example-vm
```

Consumers pin this repository in their own lock file and update that input explicitly. Real hardware, account credentials, and local storage choices belong in each consumer's configuration.
