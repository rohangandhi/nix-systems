{ config, lib, my-options, ... }: {
  options.local.cursor.executable = lib.mkOption { type = lib.types.str; default = "Cursor.AppImage"; description = "Cursor executable path."; };
  options.local.cursor.icon = lib.mkOption { type = lib.types.str; default = "cursor"; description = "Cursor desktop icon name or path."; };
  config = {

  # create desktop entry for cursor
  home-manager.users.${my-options.user.name} = { ... }: {
    xdg.desktopEntries.cursor.name = "Cursor";
    xdg.desktopEntries.cursor.genericName = "Code Editor";
    xdg.desktopEntries.cursor.comment = "AI-first code editor";
    xdg.desktopEntries.cursor.exec = "${config.local.cursor.executable} --ozone-platform=wayland --enable-features=UseOzonePlatform,WaylandWindowDecorations";
    xdg.desktopEntries.cursor.icon = "${config.local.cursor.icon}";
    xdg.desktopEntries.cursor.type = "Application";
    xdg.desktopEntries.cursor.categories = ["Development" "TextEditor" "IDE"];
    xdg.desktopEntries.cursor.mimeType = ["text/plain" "inode/directory"];
    xdg.desktopEntries.cursor.startupNotify = true;
    xdg.desktopEntries.cursor.terminal = false;
  };
  };
}
