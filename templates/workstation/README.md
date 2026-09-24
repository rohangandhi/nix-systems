# Workstation configuration

This is a standalone consumer of the public modules. No private repository is required.
Read the public repository's TENETS.md before changing its modules.

`flake.nix` is the complete high-level system declaration. Select applications, desktops, services, and hardware there; their files hold the individual settings.

1. Set hostname, username, UID/GID, and display scale explicitly in `flake.nix`.
2. Prepare and mount your target filesystems at `/mnt`, including `/mnt/boot` for UEFI. Formatting is a separate destructive decision; use the NixOS installation manual for your layout.
3. Run `sudo nixos-generate-config --root /mnt`. Copy `/mnt/etc/nixos/hardware-configuration.nix` to `zion/hardware/generated.nix` in this checkout.
4. Generate your login hash with `nix-shell -p mkpasswd --run 'mkpasswd -m yescrypt'`. Replace `!` in `zion/os/users.nix`. Do not publish your real hash. Change `time.timeZone` in `flake.nix` if wanted.
5. Run `git init` and `git add .` so Nix includes all source files. Run `nix flake lock` to pin public inputs.
6. Build with `nix build .#nixosConfigurations.workstation.config.system.build.toplevel`.
7. Install with `sudo nixos-install --flake .#workstation --no-channel-copy`. Set the installer-requested root password, then reboot.

The included boot module targets x86_64 UEFI machines. For other hardware, choose the matching platform and boot module explicitly. Use the generated hardware configuration for your actual disk layout. This template uses ordinary persistent filesystems; it does not assume a separate persistence partition.

Review the public feature settings for your machine, including automatic GNOME login, wallpaper/editor paths, the shell greeting, and Podman storage at `/p-data/containers/storage`. If using Podman, provide a writable, exec-capable storage location or change those paths in your copy of the module.

For later changes: `sudo nixos-rebuild switch --flake .#workstation`.
To update public modules: `nix flake update public`, build, then switch.

Full installation guide: https://nixos.org/manual/nixos/stable/#sec-installation-manual
