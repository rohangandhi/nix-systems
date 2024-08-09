{ my-options, ... }: {

  home-manager.users.${my-options.user.name} = { pkgs, ... }: {
    xdg.configFile."wallpapers/wallpaper.png".source = ./wallpaper.png;
    stylix.image = ./wallpaper.png;

    # https://tinted-theming.github.io/base16-gallery/
    # stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/default-dark.yaml";
    stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
    stylix.enable = true;
    stylix.autoEnable = true;
    stylix.polarity = "dark";

    stylix.opacity.terminal = 0.9;

    stylix.cursor.package = pkgs.bibata-cursors;
    stylix.cursor.name = "Bibata-Modern-Ice";
    stylix.cursor.size = 32;

    stylix.fonts.monospace = {
      package = pkgs.nerdfonts.override { fonts = [ "JetBrainsMono" ]; };
      name = "JetBrainsMono Nerd Font";
    };
    stylix.fonts.emoji = {
      package = pkgs.noto-fonts-emoji;
      name = "Noto Color Emoji";
    };
  };
}
