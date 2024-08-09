{ config, pkgs, ... }: {
  services.hyprpaper.enable = config.wayland.windowManager.hyprland.enable;
  services.hyprpaper.package = pkgs.hyprpaper;
  services.hyprpaper.settings = {
    ipc = true;
    splash = false;
    # preload = "~/.config/wallpapers/wallpaper.png";
    # wallpaper = ",~/.config/wallpapers/wallpaper.png";
  };
}
