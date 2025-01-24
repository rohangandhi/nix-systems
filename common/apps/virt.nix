{ pkgs, my-options, ... }: {

  environment.systemPackages = [
    pkgs.quickemu
  ];

  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  users.users.${my-options.user.name}.extraGroups = [ "libvirtd" ];
}
