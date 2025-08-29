{ my-options, ... }: {
  # services.xserver.enable = true;
  # services.xserver.displayManager.gdm.enable = true;
  # services.xserver.desktopManager.gnome.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  home-manager.users.${my-options.user.name} = { pkgs, ... }: {
    dconf.enable = true;
    dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
    dconf.settings."org/gnome/desktop/interface".accent-color = "green";

  };
}
