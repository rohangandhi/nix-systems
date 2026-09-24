{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    impermanence.url = "github:nix-community/impermanence/4b3e914cdf97a5b536a889e939fb2fd2b043a170";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    codex-desktop-linux = {
      url = "github:ilysenko/codex-desktop-linux";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs: {
    nixosConfigurations.zion-alpha = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        inherit inputs;
        my-options = {
          name = "zion-alpha";
          display.scaling = "2";
          user = { name = "ephemeral"; uid = 1000; };
          group = { name = "devs"; gid = 999; };
        };
      };
      # The complete public host declaration. Add credentials and private
      # services through the small extension in the private checkout.
      modules = [
        # Nix and shared settings
        ./zion/options.nix
        ./zion/nix.nix

        # Upstream modules
        ./common/input-modules/impermanence.nix
        ./common/input-modules/disko.nix
        ./common/input-modules/home-manager.nix
        ./common/input-modules/home-manager/impermanence.nix

        # Hardware and storage
        ./zion/os/boot.nix
        ./zion/hardware/graphics.nix
        ./zion/hardware/generated.nix
        ./zion/hardware/filesystem.nix

        # Operating system
        ./zion/os/fonts.nix
        ./zion/os/networking.nix
        ./zion/os/audio.nix
        ./zion/os/users.nix
        ./zion/os/locale.nix
        ./zion/os/proxy.nix

        # Desktop
        ./common/theme/options.nix
        # Set to null for native colors, or "nord" for the alternative palette.
        { my-theme.palette = "midnight-jade"; }
        ./common/desktop/gnome.nix

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

        # Development
        ./common/apps/development/codium.nix
        ./common/theme/codium.nix
        ./common/apps/development/codex.nix
        ./common/apps/development/kiro.nix
        ./common/apps/development/zed.nix

        # VM launchers
        ./matrix/one/commands.nix

        # Miscellaneous applications
        ./common/apps/container.nix
        ./common/apps/git.nix
        ./common/apps/app-image.nix
        ./common/apps/qalculate.nix
      ];
    };

    # Existing module exports for external consumers. The host declaration
    # lists its modules directly above.
    nixosModules.default = {
      imports = [
        ./zion/options.nix
        ./common/theme/options.nix
        ./zion/nix.nix
        ./zion/os/fonts.nix
        ./zion/os/networking.nix
        ./zion/os/audio.nix
        ./zion/os/users.nix
        ./common/input-modules/impermanence.nix
        ./common/input-modules/disko.nix
        ./common/input-modules/home-manager.nix
        ./common/input-modules/home-manager/impermanence.nix
      ];
    };
    nixosModules.workstation = {
      imports = [
        ./zion/options.nix
        ./common/theme/options.nix
        ./zion/nix.nix
        ./zion/os/fonts.nix
        ./zion/os/networking.nix
        ./zion/os/audio.nix
        ./zion/os/users.nix
        ./common/input-modules/impermanence.nix
        ./common/input-modules/disko.nix
        ./common/input-modules/home-manager.nix
        ./common/input-modules/home-manager/impermanence.nix
        ./zion/os/proxy.nix
        ./common/desktop/gnome.nix
        ./common/apps/browser/firefox.nix
        ./common/apps/browser/chromium.nix
        ./common/apps/terminal/fastfetch.nix
        ./common/apps/terminal/alacritty.nix
        ./common/apps/terminal/tmux.nix
        ./common/apps/terminal/fish.nix
        ./common/apps/terminal/starship.nix
        ./common/apps/terminal/commands.nix
        ./common/apps/development/codium.nix
        ./common/theme/codium.nix
        ./common/apps/development/codex.nix
        ./common/apps/development/kiro.nix
        ./common/apps/development/zed.nix
        ./matrix/one/commands.nix
        ./common/apps/container.nix
        ./common/apps/git.nix
        ./common/apps/app-image.nix
        ./common/apps/qalculate.nix
      ];
    };
    nixosModules.gnome = {
      imports = [ ./common/theme/options.nix ./common/desktop/gnome.nix ];
    };
    nixosModules.proxy = ./zion/os/proxy.nix;
    nixosModules.matrix-one = ./matrix/one/configuration.nix;
    nixosModules.matrix-commands = ./matrix/one/commands.nix;
  };
}
