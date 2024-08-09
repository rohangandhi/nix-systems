{ config, my-options, ... }: {
  networking.networkmanager.enable = true;
  networking.hostName = my-options.name;
  networking.firewall.enable = true;
  
  # Bluetooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = config.hardware.bluetooth.enable; # powers up the default Bluetooth controller on boot
  services.blueman.enable = config.hardware.bluetooth.enable;
}
