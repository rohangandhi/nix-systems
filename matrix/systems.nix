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
      vmRuntimeSetup = ''
        # Default to a persistent per-user disk image unless caller overrides.
        vm_disk_default="''${HOME}/p-data/vms/${vmName}-''${USER}.qcow2"
        export NIX_DISK_IMAGE="''${NIX_DISK_IMAGE:-$vm_disk_default}"
        mkdir -p "$(dirname "$NIX_DISK_IMAGE")"
      '';
      sshSetup = pkgs.lib.optionalString (sshPort != null) ''
        vm_state_dir_default="''${HOME}/p-data/vms/${vmName}-''${USER}"
        ssh_dir_default="''${vm_state_dir_default}-ssh"
        export MATRIX_ONE_SSH_DIR="''${MATRIX_ONE_SSH_DIR:-$ssh_dir_default}"
        mkdir -p "$MATRIX_ONE_SSH_DIR"
        chmod 700 "$MATRIX_ONE_SSH_DIR"

        ssh_key="$MATRIX_ONE_SSH_DIR/id_ed25519"
        if [[ ! -s "$ssh_key" || ! -s "$ssh_key.pub" ]]; then
          rm -f "$ssh_key" "$ssh_key.pub"
          ${pkgs.openssh}/bin/ssh-keygen -q -t ed25519 -N "" -f "$ssh_key"
        fi

        ${pkgs.coreutils}/bin/install -m 600 "$ssh_key.pub" "$MATRIX_ONE_SSH_DIR/authorized_keys"
      '';
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
          -p ${toString sshPort} \
          -o IdentitiesOnly=yes \
          -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null \
          -o GlobalKnownHostsFile=/dev/null \
          ${sshUser}@127.0.0.1 "$@"
      '');
    in
    [ vmScript ] ++ sshScript;
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
