{ inputs, ... }: {
  home-manager.sharedModules = [
    inputs.plasma-manager.homeManagerModules.plasma-manager
  ];
}
