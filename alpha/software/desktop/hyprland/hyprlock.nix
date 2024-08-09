{ config, pkgs, ... }: {

  programs.hyprlock.enable = config.wayland.windowManager.hyprland.enable;
  programs.hyprlock.package = pkgs.hyprlock;
  programs.hyprlock.settings = {
    background = [{
      path = "~/.config/wallpapers/wallpaper.png";
      blur_passes = 3;
      blur_size = 8;
    }];

    label = [
      {
        # USER
        text = "$USER";
        color = "rgba(255, 255, 255, 0.6)";
        font_size = 25;
        position = "0, -40";
        halign = "center";
        valign = "center";
      }

      {
        # TIME
        text = ''cmd[update:1000] echo "$(date +"%-I:%M%p")"'';
        color = "rgba(255, 255, 255, 0.6)";
        font_size = "120";
        # font_family = JetBrains Mono Nerd Font Mono ExtraBold
        position = "0, -300";
        halign = "center";
        valign = "top";
      }
    ];

    # INPUT FIELD
    input-field = {
      size = "250, 60";
      outline_thickness = 2;
      dots_size = "0.2"; # Scale of input-field height, 0.2 - 0.8
      dots_spacing = "0.2"; # Scale of dots' absolute size, 0.0 - 1.0
      dots_center = true;
      outer_color = "rgba(0, 0, 0, 0)";
      inner_color = "rgba(0, 0, 0, 0.5)";
      font_color = "rgb(200, 200, 200)";
      fade_on_empty = false;
      placeholder_text = ''<i><span foreground="##cdd6f4">Input Password...</span></i>"'';
      hide_input = false;
      position = "0, -120";
      halign = "center";
      valign = "center";
    };
  };
}
