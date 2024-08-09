{ inputs, ... }: {
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];
  home-manager.backupFileExtension = "hmbkup";
  home-manager.useUserPackages = true;
  home-manager.useGlobalPkgs = false;
}
