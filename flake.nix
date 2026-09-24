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

  outputs = { self, ... }@inputs: {
    nixosModules.default = ./zion/system.nix;
    nixosModules.workstation = ./zion/workstation.nix;
    nixosModules.gnome = ./common/desktop/gnome.nix;
    nixosModules.proxy = ./zion/os/proxy.nix;
    nixosModules.matrix-one = ./matrix/one/configuration.nix;
    nixosModules.matrix-commands = ./matrix/systems.nix;

    nixosConfigurations.example = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        inherit inputs;
        my-options = {
          name = "example";
          display.scaling = "1";
          user = { name = "demo"; uid = 1000; };
          group = { name = "users"; gid = 100; };
        };
      };
      modules = [ ./examples/vm.nix ];
    };

    packages.x86_64-linux.example-vm = self.nixosConfigurations.example.config.system.build.vm;
    templates.workstation = {
      path = ./templates/workstation;
      description = "Standalone workstation with explicit user, storage, and hardware settings";
    };
  };
}
