{
  inputs.public.url = "github:rohangandhi/nix-systems";
  inputs.nixpkgs.follows = "public/nixpkgs";

  outputs = { public, nixpkgs, ... }: {
    nixosConfigurations.workstation = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        inherit public;
        inputs = public.inputs;
        my-options = {
          name = "workstation";
          display.scaling = "1";
          user = { name = "owner"; uid = 1000; };
          group = { name = "users"; gid = 100; };
        };
      };
      # Select the whole system here. Feature files contain their own settings.
      modules = [
        # Nix and shared settings
        "${public}/zion/options.nix"
        "${public}/zion/nix.nix"

        # Upstream modules
        "${public}/common/input-modules/impermanence.nix"
        "${public}/common/input-modules/disko.nix"
        "${public}/common/input-modules/home-manager.nix"
        "${public}/common/input-modules/home-manager/impermanence.nix"

        # Hardware and storage: replace the generated file before installation
        "${public}/zion/os/boot.nix"
        ./zion/hardware/generated.nix

        # Operating system
        "${public}/zion/os/fonts.nix"
        "${public}/zion/os/networking.nix"
        "${public}/zion/os/audio.nix"
        "${public}/zion/os/users.nix"
        ./zion/os/users.nix
        "${public}/zion/os/proxy.nix"
        { time.timeZone = "UTC"; }

        # Desktop
        "${public}/common/desktop/gnome.nix"

        # Browser
        "${public}/common/apps/browser/firefox.nix"
        "${public}/common/apps/browser/chromium.nix"

        # Terminal
        "${public}/common/apps/terminal/fastfetch.nix"
        "${public}/common/apps/terminal/alacritty.nix"
        "${public}/common/apps/terminal/tmux.nix"
        "${public}/common/apps/terminal/fish.nix"
        "${public}/common/apps/terminal/starship.nix"
        "${public}/common/apps/terminal/commands.nix"

        # Development
        "${public}/common/apps/development/codium.nix"
        "${public}/common/apps/development/codex.nix"
        "${public}/common/apps/development/kiro.nix"
        "${public}/common/apps/development/zed.nix"

        # VM launchers
        "${public}/matrix/one/commands.nix"

        # Miscellaneous applications
        "${public}/common/apps/container.nix"
        "${public}/common/apps/git.nix"
        "${public}/common/apps/app-image.nix"
        "${public}/common/apps/qalculate.nix"
      ];
    };
  };
}
