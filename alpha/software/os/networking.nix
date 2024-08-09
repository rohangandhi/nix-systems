{ config, ... }: {
  networking.networkmanager.enable = true;
  networking.hostName = config.my-options.name;

  # Bluetooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = config.hardware.bluetooth.enable; # powers up the default Bluetooth controller on boot
  services.blueman.enable = config.hardware.bluetooth.enable;
}
