{ config, pkgs, ... }: {

  programs.waybar.enable = config.wayland.windowManager.hyprland.enable;
  programs.waybar.package = pkgs.waybar;
  programs.waybar.systemd.enable = true;
  programs.waybar.settings = {
    mainBar = {
      layer = "top";
      position = "top";
      height = 30;
      spacing = 10;
      modules-left = [ "hyprland/workspaces" ];
      modules-center = [ "hyprland/window" ];
      modules-right = [
        "pulseaudio"
        "clock"
      ];

      # Left
      "hyprland/workspaces" = {
        format = " {icon} ";
        format-icons = {
          "special" = "";
          "empty" = "";
          "persistent" = "";
          "active" = "";
        };
        show-special = true;
        special-visible-only = true;
        on-scroll-up = "hyprctl dispatch workspace e+1";
        on-scroll-down = "hyprctl dispatch workspace e-1";
        persistent-workspaces = {
          "*" = 3;
        };
      };

      # Right
      pulseaudio = {
        format = "{volume}% {icon}";
        format-muted = " ";
        format-icons = {
          default = [ "" "" "" ];
        };
        on-click = "pavucontrol";
      };
      clock = {
        interval = 1;
        format = "{:%H:%M} 󰥔 ";
        format-alt = "{:%a, %d %b, %Y - %R} 󰥔";
        tooltip-format = "<tt><small>{calendar}</small></tt>";
      };
    };
  };
}
