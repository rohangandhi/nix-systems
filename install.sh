# Run this from a Nixos live installer
# Disk ID and system name are hard coded. TODO.

# Use disko to format disk.
sudo nix run --experimental-features 'nix-command flakes' github:nix-community/disko -- --mode disko --flake .#zion-alpha

# Could not figure out how to bind mount using disko. So manually mounting for the unusual "p-os" setup for now. TODO.
sudo mkdir /mnt/nix
sudo mkdir /mnt/p-os/nix
sudo mount --bind /mnt/p-os/nix /mnt/nix

# Home directory does not get created since root is mounted on tempfs. So manually creating home. TODO
sudo mkdir /mnt/p-home/ephemeral
sudo mkdir -p /mnt/home/ephemeral
sudo chown 1001:999 /mnt/p-home/ephemeral
sudo mount --bind /mnt/p-home/ephemeral /mnt/home/ephemeral

# Install Nixos
NIX_CONFIG="experimental-features = nix-command flakes" sudo nixos-install --flake .#zion-alpha --no-root-passwd
