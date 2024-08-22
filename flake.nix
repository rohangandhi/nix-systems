{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    impermanence.url = "github:nix-community/impermanence";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    stylix.url = "github:danth/stylix";
    stylix.inputs.nixpkgs.follows = "nixpkgs";
    hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
    hyprland.inputs.nixpkgs.follows = "nixpkgs";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";    
  };

  outputs = { ... } @inputs: {

    nixosConfigurations.zion-alpha = import ./zion/system.nix {
      inherit inputs;
      system-name = "zion-alpha";
      desktop = [
        ./common/desktop/hyprland/hyprland.nix
      ];
      apps = [
        # Browser
        ./common/apps/browser/firefox.nix
        #./common/apps/browser/chromium.nix

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
        #./common/apps/virt.nix
        ./common/apps/git.nix
      ];
    };
  };
}
