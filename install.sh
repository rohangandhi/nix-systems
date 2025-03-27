set -e
# Run this from a Nixos live installer
# Disk ID and system name are hard coded. TODO.

# Use disko to re-partition disk and mount the partitions.
# sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko/latest -- --mode destroy,format,mount --flake .#zion-alpha

# OR

# Use disko to just mount the partitions.
sudo cryptsetup luksOpen /dev/disk/by-partlabel/disk-main-system decrypted
sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko/latest -- --mode format,mount --flake .#zion-alpha

# Install Nixos
NIX_CONFIG="experimental-features = nix-command flakes" sudo nixos-install --flake .#zion-alpha --no-root-passwd
