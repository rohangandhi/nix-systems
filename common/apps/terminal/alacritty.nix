{ config, lib, my-options, ... }:
let
  theme = config.my-theme;
  palette = theme.colors;
  colors = builtins.mapAttrs (_: hex: "#${hex}") palette;
in {

  home-manager.users.${my-options.user.name} = { pkgs, ... }: {
    programs.alacritty.enable = true;
    programs.alacritty.settings = {
      window = {
        padding = { x = 18; y = 14; };
        dynamic_padding = true;
        decorations_theme_variant = lib.mkIf theme.enabled "Dark";
      };
      font = {
        normal.family = "NotoSansM Nerd Font Mono";
        normal.style = "Light";
        bold.style = "Medium";
        size = 11.0;
        offset.y = 1;
      };
      cursor.style = { shape = "Beam"; blinking = "Off"; };
      colors = lib.mkIf theme.enabled {
        primary = {
          inherit (colors) background foreground;
          dim_foreground = colors.muted;
        };
        normal = {
          inherit (colors) black red green yellow blue magenta cyan white;
        };
        bright = {
          inherit (colors) red green yellow blue magenta cyan;
          black = colors.brightBlack;
          white = colors.brightWhite;
        };
        cursor = { text = colors.background; cursor = colors.accent; };
        selection = { text = colors.foreground; background = colors.selection; };
        search = {
          matches = { foreground = colors.background; background = colors.yellow; };
          focused_match = { foreground = colors.background; background = colors.green; };
        };
      };
      terminal.shell.program = "${pkgs.fish}/bin/fish";
    };
  };
}
