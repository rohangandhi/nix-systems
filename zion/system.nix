{ ... }: {
  imports = [
    ./options.nix
    ./nix.nix
    ./os/fonts.nix
    ./os/networking.nix
    ./os/audio.nix
    ./os/users.nix
    ../common/input-modules/impermanence.nix
    ../common/input-modules/disko.nix
    ../common/input-modules/home-manager.nix
    ../common/input-modules/home-manager/impermanence.nix
  ];
}
