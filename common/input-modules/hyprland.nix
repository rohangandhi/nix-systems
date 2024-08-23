{ inputs, pkgs, ... }: {
  programs.hyprland.package = inputs.hyprland.packages.${pkgs.system}.hyprland;

  home-manager.sharedModules = [
    { wayland.windowManager.hyprland.package = inputs.hyprland.packages.${pkgs.system}.hyprland; }
  ];

  nix.settings = {
    substituters = [ "https://hyprland.cachix.org" ];
    trusted-public-keys = [ "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" ];
  };
}
