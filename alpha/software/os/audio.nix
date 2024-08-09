{ pkgs, ... }: {

  security.rtkit.enable = true; # realtime-kit for audio
  services.pipewire.enable = true;
  services.pipewire.alsa.enable = true;
  services.pipewire.alsa.support32Bit = true;
  services.pipewire.pulse.enable = true;
  services.pipewire.jack.enable = true;

  environment.systemPackages = [
    pkgs.pamixer
  ];
}
