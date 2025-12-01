{ pkgs, ... }: {
  services.xserver.videoDrivers = [ "amdgpu" ];

  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
  hardware.graphics.extraPackages = [
    pkgs.libva-vdpau-driver
    pkgs.libvdpau-va-gl
  ];
  hardware.graphics.extraPackages32 = [
    pkgs.pkgsi686Linux.libva-vdpau-driver
    pkgs.pkgsi686Linux.libvdpau-va-gl
  ];
}
