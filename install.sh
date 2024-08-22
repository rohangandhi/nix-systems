# Run this from a Nixos live installer
# Disk ID and system name are hard coded. TODO.

# setup nix flags to allow using commands and flakes
NIX_CONFIG="experimental-features = nix-command flakes"

# Use disko to format disk.
sudo nix run github:nix-community/disko -- --mode disko --flake .#zion-alpha

# Could not figure out how to bind mount using disko. So manually mounting for the unusual "p-os" setup for now. TODO.
sudo mkdir /mnt/nix
sudo mkdir /mnt/p-os/nix
sudo mount --bind /mnt/p-os/nix /mnt/nix

# Home directory does not get created since root is mounted on tempfs. So manually creating home. TODO
sudo mkdir /mnt/p-home/ephemeral
sudo chown ephemeral:devs /mnt/p-home/ephemeral

# Install Nixos
sudo nixos-install --flake .#zion-alpha --no-root-passwd
