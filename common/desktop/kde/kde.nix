{ my-options, ... }: {
  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;
  services.displayManager.defaultSession = "plasma";
  services.displayManager.sddm.wayland.enable = true;

  home-manager.users.${my-options.user.name} = { pkgs, ... }: {
    imports = [
      ./generated.nix
      ./kscreen-scaling.nix
    ];
    # nix run github:nix-community/plasma-manager
    programs.plasma = {
    #   enable = false;
      workspace = {
        # clickItemTo = "select";
        lookAndFeel = "org.kde.breezedark.desktop";
        colorScheme = "BreezeDark";
        theme = "breeze-dark";
        cursor.theme = "Bibata-Modern-Ice";
        # iconTheme = "Papirus-Dark";
        # wallpaper = "${pkgs.kdePackages.plasma-workspace-wallpapers}/share/wallpapers/Patak/contents/images/1080x1920.png";
      };
    };
  };

}
