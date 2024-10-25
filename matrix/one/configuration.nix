{ pkgs, ... }:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Create a new user without password
  users.users.autologin = {
    isNormalUser = true;
    description = "Auto Login User";
    extraGroups = [ "wheel" ];
    hashedPassword = ""; # Explicitly disable password
  };

  # # Enable getty auto-login
  services.getty.autologinUser = "autologin";

  # Allow sudo without password for wheel group
  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [
    cowsay
    lolcat
  ];

  system.stateVersion = "24.11";
}

# nix-build '<nixpkgs/nixos>' -A vm -I nixos-config=$HOME/n-zion/nix/systems/matrix/one/configuration.nix
# QEMU_KERNEL_PARAMS=console=ttyS0 ./result/bin/run-nixos-vm -nographic