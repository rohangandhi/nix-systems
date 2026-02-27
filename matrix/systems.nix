{ pkgs, inputs, ... }:
let
  mkVm =
    {
      commandName,
      vmName,
      modulePath,
      defaultArgs ? [ ],
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
    in
    pkgs.writeShellScriptBin commandName ''
      set -euo pipefail

      # Default to a persistent per-user disk image unless caller overrides.
      vm_disk_default="''${HOME}/p-data/vms/${vmName}-''${USER}.qcow2"
      export NIX_DISK_IMAGE="''${NIX_DISK_IMAGE:-$vm_disk_default}"
      mkdir -p "$(dirname "$NIX_DISK_IMAGE")"

      # Terminal-mode QEMU shortcuts:
      # - Ctrl-a x          Quit VM immediately
      # - Ctrl-a c, then quit
      #                     Open QEMU monitor and quit
      exec ${vmRunner} ${escapedDefaultArgs} "$@"
    '';
in
{
  environment.systemPackages = [
    (mkVm {
      commandName = "matrix-one-vm";
      vmName = "matrix-one";
      modulePath = ./one/configuration.nix;
      defaultArgs = [ "-nographic" ];
    })
    # (mkVm "matrix-two-vm" "matrix-two" ./two/configuration.nix)
  ];
}
