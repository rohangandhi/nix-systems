{ my-options, ... }: {

  # create desktop entry for cursor
  home-manager.users.${my-options.user.name} = { ... }: {
    xdg.desktopEntries.cursor.name = "Cursor";
    xdg.desktopEntries.cursor.genericName = "Code Editor";
    xdg.desktopEntries.cursor.comment = "AI-first code editor";
    xdg.desktopEntries.cursor.exec = "/home/ephemeral/p-data/application/cursor/Cursor.AppImage";
    xdg.desktopEntries.cursor.icon = "/home/ephemeral/p-data/application/cursor/icon.jpeg";
    xdg.desktopEntries.cursor.type = "Application";
    xdg.desktopEntries.cursor.categories = ["Development" "TextEditor" "IDE"];
    xdg.desktopEntries.cursor.mimeType = ["text/plain" "inode/directory"];
    xdg.desktopEntries.cursor.startupNotify = true;
    xdg.desktopEntries.cursor.terminal = false;
  };
}