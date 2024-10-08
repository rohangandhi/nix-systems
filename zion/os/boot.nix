{ pkgs, config, ... }: {

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 200;
  boot.loader.systemd-boot.extraInstallCommands =
    # for refind. Putting the efi in nixos directory results in correct nixos logo for boot option
    ''
      ${pkgs.coreutils}/bin/mkdir -p /boot/EFI/nixos
      ${pkgs.coreutils}/bin/cp ${config.boot.loader.efi.efiSysMountPoint}/EFI/systemd/systemd-bootx64.efi \
         ${config.boot.loader.efi.efiSysMountPoint}/EFI/nixos/systemd-bootx64.efi
    '';
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub.device = "nodev";

  # boot.initrd.systemd.enable = true;
  # boot.plymouth.enable = true;
  boot.kernelParams = ["quiet"]; # Pretty sure this one's optional.

  environment.systemPackages = [
    pkgs.refind # TODO: bundle refind installation into config
    pkgs.efibootmgr
  ];
}
