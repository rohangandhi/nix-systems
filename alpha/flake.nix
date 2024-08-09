{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    impermanence.url = "github:nix-community/impermanence";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    stylix.url = "github:danth/stylix";
    hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
  };

  outputs = { ... } @inputs: {

    nixosConfigurations.zion-alpha = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        inputs = inputs;
        my-options = {
          name = "zion-alpha";
          display = {
            scaling = "2";
          };
          user = {
            name = "ephemeral";
            uid = 1001;
          };
          group = {
            name = "devs";
            gid = 999;
          };
        };
      };
      modules = [
        ./options.nix # validations for my-options attribute set

        ./nix.nix # Nix related settings

        # Input Modules
        ./modules/impermanence.nix
        ./modules/home-manager.nix
        ./modules/home-manager/impermanence.nix
        ./modules/home-manager/stylix.nix
        ./modules/hyprland.nix


        ## System Configuration ##

        ### Hardware ############

        ./hardware/filesystem.nix
        ./hardware/graphics.nix
        ./hardware/generated.nix

        ### OS ##################

        ./software/os/audio.nix
        ./software/os/boot.nix
        ./software/os/fonts.nix
        ./software/os/locale.nix
        ./software/os/networking.nix
        ./software/os/users.nix

        ### Desktop #############

        ./software/desktop/hyprland.nix
        ./software/desktop/stylix.nix

        ### Apps ################

        #### Browser
        ./software/apps/browser/firefox.nix
        ./software/apps/browser/chromium.nix

        #### Terminal
        ./software/apps/terminal/fastfetch.nix
        ./software/apps/terminal/alacritty.nix
        ./software/apps/terminal/tmux.nix
        ./software/apps/terminal/fish.nix
        ./software/apps/terminal/starship.nix
        ./software/apps/terminal/commands.nix
        ./software/apps/terminal/yazi.nix

        #### Development
        ./software/apps/development/codium.nix
        ./software/apps/development/zed.nix
        ./software/apps/development/emacs.nix

        #### Misc
        ./software/apps/gaming.nix
        ./software/apps/container.nix
        ./software/apps/virt.nix
        ./software/apps/git.nix
      ];
    };
  };
}
