{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    impermanence.url = "github:nix-community/impermanence";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland = {
      url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs = { self, ... } @inputs: {
    input-modules = [
      ./common/input-modules/impermanence.nix
      ./common/input-modules/disko.nix
      ./common/input-modules/home-manager.nix
      ./common/input-modules/home-manager/impermanence.nix
      ./common/input-modules/home-manager/stylix.nix
      ./common/input-modules/home-manager/plasma-manager.nix
      ./common/input-modules/hyprland.nix      
    ];

    nixosConfigurations.zion-alpha = import ./zion/system.nix {
      inherit inputs;
      system-name = "zion-alpha";
      input-modules = self.input-modules;
      desktop = [
        #./common/desktop/hyprland/hyprland.nix
        ./common/desktop/kde/kde.nix
        #./common/desktop/gnome.nix
      ];
      apps = [
        # Browser
        ./common/apps/browser/firefox.nix
        ./common/apps/browser/chromium.nix

        # Terminal
        ./common/apps/terminal/fastfetch.nix
        ./common/apps/terminal/alacritty.nix
        ./common/apps/terminal/tmux.nix
        ./common/apps/terminal/fish.nix
        ./common/apps/terminal/starship.nix
        ./common/apps/terminal/commands.nix
        ./common/apps/terminal/yazi.nix

        # Development
        ./common/apps/development/codium.nix
        #./common/apps/development/zed.nix
        #./common/apps/development/emacs.nix

        # Misc
        #./common/apps/container.nix
        ./common/apps/virt.nix
        ./common/apps/git.nix
        ./common/apps/slack.nix
        ./common/apps/zoom.nix
        ./common/apps/mpv.nix
      ];
    };
  };
}
