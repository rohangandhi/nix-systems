{ inputs, ... }: {
  home-manager.sharedModules = [
    inputs.stylix.homeManagerModules.stylix
  ];
}
