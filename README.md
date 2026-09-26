# NixOS configuration

Flat, explicit NixOS configuration for a GNOME workstation and an isolated development VM.
Read [TENETS.md](TENETS.md) before making changes.

[`flake.nix`](flake.nix) contains the main `zion-alpha` host declaration: identity,
inputs, and every selected public module. Hardware, storage, and personal
preferences are public. Credentials and private services are supplied by a
separate, small private extension. The public host uses a locked password
placeholder; use the private extension when rebuilding the owner's machine.

Feature files contain settings; `flake.nix` selects them explicitly.

## Current workstation

| Area | Configuration |
| --- | --- |
| Desktop | GNOME, with Firefox, Files, Alacritty, VSCodium, and Codex pinned to the dock. |
| Graphics | Radeon RX 7900 XT with the kernel's AMDGPU driver and Mesa; LM Studio's AppImage environment supports its bundled ROCm runtime. |
| Browsers | Firefox and Chromium with privacy policies and encrypted DNS that allows system-resolver fallback. |
| Terminal | Alacritty starts Fish with Starship; tmux is optional. Terminals use Noto Sans Mono Nerd Font, while GNOME keeps its upstream font defaults. |
| Editor | VSCodium with writable settings, Nix IDE, Svelte, and `nil`/`nixfmt` for Nix editing. |
| Codex | Desktop application and CLI, selected through [codex.nix](common/apps/development/codex.nix). |
| Games | Steam with Valve's Proton; the default game library lives under `/p-data/steam/steamapps`. |
| Colors | Shared Midnight Jade palette, with Nord or native application colors available through `my-theme.palette`. |
| Isolation | The `matrix-one` development VM and rootless Podman. Container storage lives under `/p-data/containers/storage`. |
| Persistence | Root and home use tmpfs; selected state lives under `/p-os` and `/p-home/home/ephemeral`. Browse all persistent roots through `/persist`. |

VSCodium's [application module](common/apps/development/codium.nix) and
[palette module](common/theme/codium.nix) are selected separately. The editor
baseline does not evaluate this host's configuration for completion. Its native
settings, extensions, and workspace-trust directories are persisted; the editor
guide below explains ownership and optional project-specific configuration.

## Guides

- [Storage and persistence](zion/hardware/README-impermanence.md): current disk layout, mount behavior, recovery, and diagnosing lost application state.
- [Development applications](common/apps/development/README.md): VSCodium and Codex, settings ownership, persistence, and dock integration.
- [Terminal usage](common/apps/terminal/README.md): Fish shortcuts, optional tmux, the prompt, and fonts.
- [Shared themes](common/theme/README.md): select, disable, or add a palette and understand its application coverage.

Keep operational details in these feature guides, implementation reasons beside
the relevant code, and architectural principles in [TENETS.md](TENETS.md).

## Build and switch this workstation

Keep the public `systems` and private `systems-private` checkouts side by side.
From the private checkout, validate, build, and activate the complete host:

```sh
cd /home/ephemeral/n-data/nix/systems-private
nix flake check --no-build --override-input public ../systems --no-write-lock-file
nix build .#nixosConfigurations.zion-alpha.config.system.build.toplevel --no-link --override-input public ../systems --no-write-lock-file
sudo nixos-rebuild switch --flake .#zion-alpha --override-input public ../systems --no-write-lock-file
```

Use the local override for every check, build, and switch. It reads current
public edits without a commit or push; newly added files must be staged so Nix
can include them. Without the override, the private flake uses its locked public
snapshot. `--no-write-lock-file` leaves that saved lock unchanged.

Editing or committing the configuration does not activate it. Application
removals and dock changes take effect when switching; reopen affected
applications to load their new settings. The public host's locked password
placeholder requires the private credential extension for complete host
validation.

For persistent-filesystem mount-option changes, use `nixos-rebuild boot` with
the same flake and input override, then reboot so every home bind mount receives
the new flags. Restoring data from before the completed persistence migration
requires the [legacy-layout recovery notes](zion/hardware/README-impermanence.md#legacy-layout-and-rollback).

To return to the previous system generation:

```sh
sudo nixos-rebuild switch --rollback
```

This restores the previous packages and configuration, not an earlier copy of
mutable application data.

## Installation

`install.sh <flake-path#host>` installs into already-mounted `/mnt`; it never partitions or formats a disk. Prepare storage separately and set your normal user's credentials in your host configuration first. This host uses declarative accounts, with the login password supplied by the private extension; it does not declare a root password.

## Graphics and LM Studio

[graphics.nix](zion/hardware/graphics.nix) enables AMDGPU and Mesa, including
32-bit graphics support. Desktop rendering and Vulkan inference use this stack.
Hardware video acceleration uses Mesa's native Radeon VA-API driver, without
the legacy VA-API/VDPAU translation packages.
LM Studio is a manually installed AppImage; its downloaded ROCm runtime supplies
the HIP and math libraries for AMD compute. A separate system-wide ROCm SDK or
OpenCL driver is not needed for this application.

[app-image.nix](common/apps/app-image.nix) adds `elfutils` and `zstd` to the
AppImage compatibility environment. Without them, LM Studio's ROCm runtime can
fail to load `libelf.so.1` or `libzstd.so.1`, even though Vulkan works. After
changing this module, switch the system configuration and fully restart LM
Studio so it uses the new environment.

In LM Studio, open **Runtimes** with **Ctrl+Shift+R** and select the Linux
AMD ROCm runtime for GGUF models. If a previous compatibility check failed,
rerun it. Select the **RX 7900 XT** for inference; the Ryzen integrated GPU is
a separate, much smaller GPU whose reported memory includes system RAM.
Its memory is not additional VRAM on the Radeon card.

For models and context sizes that fit in the card's 20 GB of VRAM, prefer full
GPU layer offload and GPU KV-cache offload, leaving room for the desktop.
Compare Vulkan and ROCm using the same model, context, and offload settings;
runtime choice alone does not establish which is faster for a particular model.
Runtime and GPU preferences stay writable in LM Studio. The host persists
`~/.lmstudio` and `~/.config/LM Studio`.

## Steam

[steam.nix](common/apps/steam.nix) enables the standard NixOS Steam module,
including its Linux runtime environment, 32-bit graphics/audio integration,
controller rules, and desktop launcher. Launch Steam from GNOME after switching
the configuration, let it update, and sign in. Steam manages Valve's Proton
versions; use a game's **Properties > Compatibility** when it needs a specific
version. GE-Proton and other gaming utilities can be added when a game needs them.
Remote Play, dedicated-server, and LAN-transfer firewall openings remain disabled.

The host's [filesystem module](zion/hardware/filesystem.nix) persists `~/.steam`
and `~/.local/share/Steam` in encrypted `/p-home`. The default library's
`steamapps` directory is linked to `/p-data/steam/steamapps`, so games, downloaded
Proton runtimes, Windows compatibility prefixes, and shader caches use the data
filesystem automatically. No extra library needs to be selected in Steam.
`/p-data` is unencrypted; saves inside Proton prefixes live there too.

For this machine's first installation, the Steam directories are empty. When
applying this layout to an existing Steam installation, close Steam and move its
existing `steamapps` directory to the data filesystem before activation; Home
Manager deliberately refuses to overwrite an existing directory with the link.

Native Linux games can save outside Steam's directories, for example in
`~/.config`, `~/.local/share`, or `~/.config/unity3d`. Add each game's actual save
directory to persistence as games are installed. Steam Cloud coverage varies by
game; the temporary home alone does not preserve those files across a reboot.
See [Valve's Proton guidance](https://partner.steamgames.com/doc/steamhardware/proton?l=english)
for game-specific compatibility and anti-cheat limitations.

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

## Update dependencies

Update the public lock file from its checkout:

```sh
cd /home/ephemeral/n-data/nix/systems
nix flake update
```

Impermanence uses its current API and is locked alongside the other inputs.
Review storage-related updates using the
[persistence guide](zion/hardware/README-impermanence.md), including generated
mount paths and behavior across reboot.

Then use the [build and switch workflow](#build-and-switch-this-workstation).
Dependency updates change the lock file; they do not update the running system
until a new generation is activated.

Remote consumers can pin this repository and update that input explicitly. Configure your own hardware, storage, preferences, and credentials before using these modules on another machine.

## What validation proves

The [commands above](#build-and-switch-this-workstation) cover evaluation,
building, activation, and rollback. Each stage establishes something different:

| Stage | What it establishes | What still needs checking |
| --- | --- | --- |
| `nix flake check --no-build` | Configuration evaluation, types, assertions, and flake-output checks | Does not build the system or run activation. |
| Build `nixosConfigurations.zion-alpha.config.system.build.toplevel` | The selected system closure can be built or fetched | The running system and application state have not changed. |
| `nixos-rebuild switch` | The generation is activated and activation scripts run | Check affected services and applications; existing processes can retain old settings. |
| Reboot, then reopen affected applications | Startup mounts, recreated home paths, and application state can be checked across a boot | Verify the specific state that should survive, such as a saved preference or trusted workspace. |

Choose checks for the change. For an editor-state change, test saving a preference
and reopening the editor. For persistence changes, also verify the backing mount
and survival across a reboot. For palette changes, exercise both palettes and
`null`, including the transition back to native colors. Documentation-only edits
need link, example, and consistency checks.

Report which stages actually ran. A system-generation rollback does not restore
an earlier copy of mutable application data; persistence and data backups are
separate concerns.
