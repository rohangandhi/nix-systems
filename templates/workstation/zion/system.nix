{ public, ... }: {
  imports = [
    public.nixosModules.workstation
    "${public}/zion/os/boot.nix"
    ./hardware/generated.nix
    ./os/users.nix
  ];
  time.timeZone = "UTC";
}
