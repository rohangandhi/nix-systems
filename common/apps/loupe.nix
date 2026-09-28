{ lib, pkgs, my-options, ... }:
let
  # Image formats advertised by Loupe's desktop entry.
  imageTypes = [
    "image/apng"
    "image/avif"
    "image/bmp"
    "image/gif"
    "image/heic"
    "image/jp2"
    "image/jpeg"
    "image/jxl"
    "image/png"
    "image/qoi"
    "image/svg+xml"
    "image/svg+xml-compressed"
    "image/tiff"
    "image/vnd.microsoft.icon"
    "image/webp"
    "image/x-dds"
    "image/x-exr"
    "image/x-portable-anymap"
    "image/x-portable-bitmap"
    "image/x-portable-graymap"
    "image/x-portable-pixmap"
    "image/x-qoi"
    "image/x-tga"
    "image/x-win-bitmap"
    "image/x-xbitmap"
    "image/x-xpixmap"
  ];
  defaults = lib.genAttrs imageTypes (_: "org.gnome.Loupe.desktop");
in {
  environment.systemPackages = [ pkgs.loupe ];
  xdg.mime.defaultApplications = defaults;

  # User associations take precedence over system-wide defaults.
  home-manager.users.${my-options.user.name}.xdg.mimeApps = {
    enable = true;
    defaultApplications = defaults;
  };
}
