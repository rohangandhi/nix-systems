{ ... }: {
  services.xserver.videoDrivers = [ "amdgpu" ];

  # Mesa includes the native Radeon VA-API driver; no VDPAU bridges are needed.
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
}
