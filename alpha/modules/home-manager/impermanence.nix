{ inputs, ... }: {
  programs.fuse.userAllowOther = true;
  home-manager.sharedModules = [
    inputs.impermanence.nixosModules.home-manager.impermanence
  ];
}
