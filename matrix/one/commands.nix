{ pkgs, inputs, ... }:
let
  vm = (inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [ ./configuration.nix ];
  }).config.system.build.vm;
in {
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "matrix-one-vm" ''
        set -euo pipefail
        vm_disk_default="''${HOME}/p-data/vms/matrix-one-''${USER}.qcow2"
        export NIX_DISK_IMAGE="''${NIX_DISK_IMAGE:-$vm_disk_default}"
        mkdir -p "$(dirname "$NIX_DISK_IMAGE")"
        ssh_private_dir_default="''${HOME}/p-data/vms/matrix-one-''${USER}-ssh-private"
        ssh_private_dir="''${MATRIX_ONE_SSH_PRIVATE_DIR:-$ssh_private_dir_default}"
        export MATRIX_ONE_SSH_PRIVATE_DIR="$ssh_private_dir"
        mkdir -p "$ssh_private_dir"
        chmod 700 "$ssh_private_dir"
        ssh_key="$ssh_private_dir/id_ed25519"
        if [[ ! -s "$ssh_key" || ! -s "$ssh_key.pub" ]]; then
          rm -f "$ssh_key" "$ssh_key.pub"
          ${pkgs.openssh}/bin/ssh-keygen -q -t ed25519 -N "" -f "$ssh_key"
        fi
        ssh_auth_dir_default="''${HOME}/p-data/vms/matrix-one-''${USER}-ssh-auth"
        ssh_auth_dir="''${MATRIX_ONE_SSH_AUTH_DIR:-$ssh_auth_dir_default}"
        export MATRIX_ONE_SSH_AUTH_DIR="$ssh_auth_dir"
        mkdir -p "$ssh_auth_dir"
        chmod 700 "$ssh_auth_dir"
        ${pkgs.coreutils}/bin/install -m 600 "$ssh_key.pub" "$ssh_auth_dir/authorized_keys"
        # Ctrl-a x quits QEMU; Ctrl-a c opens its monitor.
        exec ${pkgs.lib.getExe vm} -nographic "$@"
    '')
    (pkgs.writeShellScriptBin "matrix-one-ssh" ''
        set -euo pipefail
        ssh_private_dir_default="''${HOME}/p-data/vms/matrix-one-''${USER}-ssh-private"
        ssh_private_dir="''${MATRIX_ONE_SSH_PRIVATE_DIR:-$ssh_private_dir_default}"
        export MATRIX_ONE_SSH_PRIVATE_DIR="$ssh_private_dir"
        mkdir -p "$ssh_private_dir"
        chmod 700 "$ssh_private_dir"
        ssh_key="$ssh_private_dir/id_ed25519"
        if [[ ! -s "$ssh_key" || ! -s "$ssh_key.pub" ]]; then
          rm -f "$ssh_key" "$ssh_key.pub"
          ${pkgs.openssh}/bin/ssh-keygen -q -t ed25519 -N "" -f "$ssh_key"
        fi
        ssh_auth_dir_default="''${HOME}/p-data/vms/matrix-one-''${USER}-ssh-auth"
        ssh_auth_dir="''${MATRIX_ONE_SSH_AUTH_DIR:-$ssh_auth_dir_default}"
        export MATRIX_ONE_SSH_AUTH_DIR="$ssh_auth_dir"
        mkdir -p "$ssh_auth_dir"
        chmod 700 "$ssh_auth_dir"
        ${pkgs.coreutils}/bin/install -m 600 "$ssh_key.pub" "$ssh_auth_dir/authorized_keys"
        exec ${pkgs.openssh}/bin/ssh -i "$ssh_key" -p 2222 \
          -o IdentitiesOnly=yes -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null -o GlobalKnownHostsFile=/dev/null \
          -o LogLevel=ERROR autologin@127.0.0.1 "$@"
    '')
    (pkgs.writeShellScriptBin "matrix-one-waypipe" ''
        set -euo pipefail
        ssh_private_dir_default="''${HOME}/p-data/vms/matrix-one-''${USER}-ssh-private"
        ssh_private_dir="''${MATRIX_ONE_SSH_PRIVATE_DIR:-$ssh_private_dir_default}"
        export MATRIX_ONE_SSH_PRIVATE_DIR="$ssh_private_dir"
        mkdir -p "$ssh_private_dir"
        chmod 700 "$ssh_private_dir"
        ssh_key="$ssh_private_dir/id_ed25519"
        if [[ ! -s "$ssh_key" || ! -s "$ssh_key.pub" ]]; then
          rm -f "$ssh_key" "$ssh_key.pub"
          ${pkgs.openssh}/bin/ssh-keygen -q -t ed25519 -N "" -f "$ssh_key"
        fi
        ssh_auth_dir_default="''${HOME}/p-data/vms/matrix-one-''${USER}-ssh-auth"
        ssh_auth_dir="''${MATRIX_ONE_SSH_AUTH_DIR:-$ssh_auth_dir_default}"
        export MATRIX_ONE_SSH_AUTH_DIR="$ssh_auth_dir"
        mkdir -p "$ssh_auth_dir"
        chmod 700 "$ssh_auth_dir"
        ${pkgs.coreutils}/bin/install -m 600 "$ssh_key.pub" "$ssh_auth_dir/authorized_keys"
        if [[ $# -eq 0 ]]; then
          echo "usage: matrix-one-waypipe <command> [args...]" >&2
          exit 1
        fi
        if [[ -z "''${WAYLAND_DISPLAY:-}" ]]; then
          echo "matrix-one-waypipe must be run from a Wayland session on the host." >&2
          exit 1
        fi
        exec ${pkgs.waypipe}/bin/waypipe \
          --compress "''${WAYPIPE_COMPRESSION:-none}" --no-gpu \
          --remote-bin /run/current-system/sw/bin/waypipe \
          --ssh-bin ${pkgs.openssh}/bin/ssh \
          ssh -i "$ssh_key" -p 2222 \
          -o IdentitiesOnly=yes -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null -o GlobalKnownHostsFile=/dev/null \
          -o LogLevel=ERROR autologin@127.0.0.1 "$@"
    '')
    (pkgs.writeShellScriptBin "matrix-one-mount" ''
        set -euo pipefail
        ssh_private_dir_default="''${HOME}/p-data/vms/matrix-one-''${USER}-ssh-private"
        ssh_private_dir="''${MATRIX_ONE_SSH_PRIVATE_DIR:-$ssh_private_dir_default}"
        export MATRIX_ONE_SSH_PRIVATE_DIR="$ssh_private_dir"
        mkdir -p "$ssh_private_dir"
        chmod 700 "$ssh_private_dir"
        ssh_key="$ssh_private_dir/id_ed25519"
        if [[ ! -s "$ssh_key" || ! -s "$ssh_key.pub" ]]; then
          rm -f "$ssh_key" "$ssh_key.pub"
          ${pkgs.openssh}/bin/ssh-keygen -q -t ed25519 -N "" -f "$ssh_key"
        fi
        ssh_auth_dir_default="''${HOME}/p-data/vms/matrix-one-''${USER}-ssh-auth"
        ssh_auth_dir="''${MATRIX_ONE_SSH_AUTH_DIR:-$ssh_auth_dir_default}"
        export MATRIX_ONE_SSH_AUTH_DIR="$ssh_auth_dir"
        mkdir -p "$ssh_auth_dir"
        chmod 700 "$ssh_auth_dir"
        ${pkgs.coreutils}/bin/install -m 600 "$ssh_key.pub" "$ssh_auth_dir/authorized_keys"
        mount_dir_default="''${HOME}/p-data/vms/matrix-one-''${USER}-fs"
        mount_dir="''${MATRIX_ONE_MOUNT_DIR:-$mount_dir_default}"
        export MATRIX_ONE_MOUNT_DIR="$mount_dir"
        guest_path="''${1:-/home/autologin}"
        mkdir -p "$mount_dir"
        if ${pkgs.util-linux}/bin/mountpoint -q "$mount_dir"; then
          echo "matrix-one is already mounted at $mount_dir" >&2
          exit 0
        fi
        exec ${pkgs.sshfs}/bin/sshfs \
          -o IdentityFile="$ssh_key" -p 2222 \
          -o IdentitiesOnly=yes -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null -o GlobalKnownHostsFile=/dev/null \
          -o reconnect "autologin@127.0.0.1:$guest_path" "$mount_dir"
    '')
    (pkgs.writeShellScriptBin "matrix-one-unmount" ''
        set -euo pipefail
        mount_dir_default="''${HOME}/p-data/vms/matrix-one-''${USER}-fs"
        mount_dir="''${MATRIX_ONE_MOUNT_DIR:-$mount_dir_default}"
        export MATRIX_ONE_MOUNT_DIR="$mount_dir"
        if ! ${pkgs.util-linux}/bin/mountpoint -q "$mount_dir"; then
          echo "matrix-one is not mounted at $mount_dir" >&2
          exit 0
        fi
        exec ${pkgs.fuse3}/bin/fusermount3 -u "$mount_dir"
    '')
  ];
}
