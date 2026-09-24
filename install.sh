#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || "$1" != *#* ]]; then
  echo "usage: $0 <flake-path#host>" >&2
  echo "Mount the target root at /mnt and its boot/data filesystems first." >&2
  exit 2
fi
if ! mountpoint -q /mnt; then
  echo "The target root must be mounted at /mnt before installation." >&2
  exit 1
fi

# Storage preparation is a separate, explicit operation. This script never formats disks.
# nixos-install prompts for a root password; the host configuration supplies its login user.
sudo env NIX_CONFIG="experimental-features = nix-command flakes" \
  nixos-install --flake "$1" --no-channel-copy
