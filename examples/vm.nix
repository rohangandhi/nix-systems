{ lib, ... }: {
  # Demonstration credentials and automatic login are confined to this VM.
  users.users.demo.hashedPassword = "";
  services.getty.autologinUser = "demo";
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "demo";
  systemd.services."getty@tty1".enable = lib.mkForce true;
  security.sudo.wheelNeedsPassword = false;
  virtualisation.memorySize = 4096;
  virtualisation.cores = 2;
  virtualisation.diskSize = 16384;
  virtualisation.graphics = false;
  virtualisation.useHostCerts = false;
  virtualisation.sharedDirectories = lib.mkForce {
    nix-store = { source = builtins.storeDir; target = "/nix/.ro-store"; writable = false; };
  };
  time.timeZone = "UTC";
}
