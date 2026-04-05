{ pkgs, inputs, ... }:
let
  mkVm =
    {
      commandName,
      vmName,
      modulePath,
      defaultArgs ? [ ],
      sshPort ? null,
      sshUser ? "autologin",
    }:
    let
      vm = (
        inputs.nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ modulePath ];
        }
      ).config.system.build.vm;
      vmRunner = pkgs.lib.getExe vm;
      escapedDefaultArgs = pkgs.lib.escapeShellArgs defaultArgs;
      sshTarget = "${sshUser}@127.0.0.1";
      sshCommonArgs = [
        "-p"
        (toString sshPort)
        "-o"
        "IdentitiesOnly=yes"
        "-o"
        "StrictHostKeyChecking=no"
        "-o"
        "UserKnownHostsFile=/dev/null"
        "-o"
        "GlobalKnownHostsFile=/dev/null"
      ];
      escapedSshCommonArgs = pkgs.lib.optionalString (sshPort != null) (pkgs.lib.escapeShellArgs sshCommonArgs);
      vmRuntimeSetup = ''
        # Default to a persistent per-user disk image unless caller overrides.
        vm_disk_default="''${HOME}/p-data/vms/${vmName}-''${USER}.qcow2"
        export NIX_DISK_IMAGE="''${NIX_DISK_IMAGE:-$vm_disk_default}"
        mkdir -p "$(dirname "$NIX_DISK_IMAGE")"
      '';
      sshPrivateKeySetup = pkgs.lib.optionalString (sshPort != null) ''
        ssh_private_dir_default="''${HOME}/p-data/vms/${vmName}-''${USER}-ssh-private"
        export MATRIX_ONE_SSH_PRIVATE_DIR="''${MATRIX_ONE_SSH_PRIVATE_DIR:-$ssh_private_dir_default}"
        mkdir -p "$MATRIX_ONE_SSH_PRIVATE_DIR"
        chmod 700 "$MATRIX_ONE_SSH_PRIVATE_DIR"

        ssh_key="$MATRIX_ONE_SSH_PRIVATE_DIR/id_ed25519"
        if [[ ! -s "$ssh_key" || ! -s "$ssh_key.pub" ]]; then
          rm -f "$ssh_key" "$ssh_key.pub"
          ${pkgs.openssh}/bin/ssh-keygen -q -t ed25519 -N "" -f "$ssh_key"
        fi
      '';
      sshAuthorizedKeysSetup = pkgs.lib.optionalString (sshPort != null) ''
        ssh_auth_dir_default="''${HOME}/p-data/vms/${vmName}-''${USER}-ssh-auth"
        export MATRIX_ONE_SSH_AUTH_DIR="''${MATRIX_ONE_SSH_AUTH_DIR:-$ssh_auth_dir_default}"
        mkdir -p "$MATRIX_ONE_SSH_AUTH_DIR"
        chmod 700 "$MATRIX_ONE_SSH_AUTH_DIR"

        ${pkgs.coreutils}/bin/install -m 600 "$ssh_key.pub" "$MATRIX_ONE_SSH_AUTH_DIR/authorized_keys"
      '';
      sshSetup = sshPrivateKeySetup + sshAuthorizedKeysSetup;
      vmScript = pkgs.writeShellScriptBin commandName ''
        set -euo pipefail

        ${vmRuntimeSetup}
        ${sshSetup}

        # Terminal-mode QEMU shortcuts:
        # - Ctrl-a x          Quit VM immediately
        # - Ctrl-a c, then quit
        #                     Open QEMU monitor and quit
        exec ${vmRunner} ${escapedDefaultArgs} "$@"
      '';
      sshScript = pkgs.lib.optional (sshPort != null) (pkgs.writeShellScriptBin "${vmName}-ssh" ''
        set -euo pipefail

        ${sshSetup}

        exec ${pkgs.openssh}/bin/ssh \
          -i "$ssh_key" \
          ${escapedSshCommonArgs} \
          ${sshTarget} "$@"
      '');
      waypipeScript = pkgs.lib.optional (sshPort != null) (pkgs.writeShellScriptBin "${vmName}-waypipe" ''
        set -euo pipefail

        ${sshSetup}

        if [[ $# -eq 0 ]]; then
          echo "usage: ${vmName}-waypipe <command> [args...]" >&2
          echo "example: ${vmName}-waypipe emacs" >&2
          exit 1
        fi

        if [[ -z "''${WAYLAND_DISPLAY:-}" ]]; then
          echo "${vmName}-waypipe must be run from a Wayland session on the host." >&2
          exit 1
        fi

        exec ${pkgs.waypipe}/bin/waypipe \
          --no-gpu \
          --remote-bin /run/current-system/sw/bin/waypipe \
          --ssh-bin ${pkgs.openssh}/bin/ssh \
          ssh \
          -i "$ssh_key" \
          ${escapedSshCommonArgs} \
          ${sshTarget} \
          "$@"
      '');
      mountScript = pkgs.lib.optional (sshPort != null) (pkgs.writeShellScriptBin "${vmName}-mount" ''
        set -euo pipefail

        ${sshSetup}

        mount_dir_default="''${HOME}/p-data/vms/${vmName}-''${USER}-fs"
        export MATRIX_ONE_MOUNT_DIR="''${MATRIX_ONE_MOUNT_DIR:-$mount_dir_default}"
        guest_path="''${1:-/home/${sshUser}}"
        mkdir -p "$MATRIX_ONE_MOUNT_DIR"

        if ${pkgs.util-linux}/bin/mountpoint -q "$MATRIX_ONE_MOUNT_DIR"; then
          echo "${vmName} is already mounted at $MATRIX_ONE_MOUNT_DIR" >&2
          exit 0
        fi

        exec ${pkgs.sshfs}/bin/sshfs \
          -o IdentityFile="$ssh_key" \
          -p ${toString sshPort} \
          -o IdentitiesOnly=yes \
          -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null \
          -o GlobalKnownHostsFile=/dev/null \
          -o reconnect \
          "${sshTarget}:$guest_path" \
          "$MATRIX_ONE_MOUNT_DIR"
      '');
      unmountScript = pkgs.lib.optional (sshPort != null) (pkgs.writeShellScriptBin "${vmName}-unmount" ''
        set -euo pipefail

        mount_dir_default="''${HOME}/p-data/vms/${vmName}-''${USER}-fs"
        export MATRIX_ONE_MOUNT_DIR="''${MATRIX_ONE_MOUNT_DIR:-$mount_dir_default}"

        if ! ${pkgs.util-linux}/bin/mountpoint -q "$MATRIX_ONE_MOUNT_DIR"; then
          echo "${vmName} is not mounted at $MATRIX_ONE_MOUNT_DIR" >&2
          exit 0
        fi

        exec ${pkgs.fuse3}/bin/fusermount3 -u "$MATRIX_ONE_MOUNT_DIR"
      '');
    in
    [ vmScript ] ++ sshScript ++ waypipeScript ++ mountScript ++ unmountScript;
in
{
  environment.systemPackages = mkVm {
      commandName = "matrix-one-vm";
      vmName = "matrix-one";
      modulePath = ./one/configuration.nix;
      defaultArgs = [ "-nographic" ];
      sshPort = 2222;
    };
  # ++ mkVm { commandName = "matrix-two-vm"; vmName = "matrix-two"; modulePath = ./two/configuration.nix; };
}
