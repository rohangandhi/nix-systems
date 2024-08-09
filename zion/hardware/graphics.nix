{ pkgs, ... }: {
  services.xserver.videoDrivers = [ "amdgpu" ];

  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
  hardware.graphics.extraPackages = [
    pkgs.vaapiVdpau
    pkgs.libvdpau-va-gl
  ];
  hardware.graphics.extraPackages32 = [
    pkgs.pkgsi686Linux.vaapiVdpau
    pkgs.pkgsi686Linux.libvdpau-va-gl
  ];
}
