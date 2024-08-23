{ inputs, input-modules, apps, desktop, system-name, ... }:

inputs.nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";

  specialArgs = {
    inputs = inputs;
    my-options = {
      name = "${system-name}";
      display = {
        scaling = "2";
      };
      user = {
        name = "ephemeral";
        uid = 1000;
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

    # Hardware 
    ./hardware/generated.nix
    ./hardware/filesystem.nix
    ./hardware/graphics.nix

    # OS 
    ./os/boot.nix
    ./os/locale.nix
    ./os/fonts.nix
    ./os/networking.nix
    ./os/audio.nix
    ./os/users.nix
  ]
  ++ input-modules
  ++ apps
  ++ desktop;

}
