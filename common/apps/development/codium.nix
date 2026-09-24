{ config, lib, my-options, ... }:
let
  theme = config.my-theme;
  palette = theme.colors;
  colors = builtins.mapAttrs (_: hex: "#${hex}") palette;
in {

  xdg.mime.defaultApplications = {
    "text/plain" = "codium.desktop";
    "text/x-c" = "codium.desktop";
    "text/x-c++" = "codium.desktop";
    "text/x-python" = "codium.desktop";
    "text/x-java" = "codium.desktop";
    "text/x-cmake" = "codium.desktop";
    "text/markdown" = "codium.desktop";
    "application/x-shellscript" = "codium.desktop";
    "application/x-docbook+xml" = "codium.desktop";
    "application/x-yaml" = "codium.desktop";
    "application/json" = "codium.desktop";
    "application/xml" = "codium.desktop";
  };

  # TODO: use vscode in docker.

  # https://nixos.org/manual/nixpkgs/stable/#sec-pkgs-dockerTools
  # https://github.com/coder/code-server
  # https://github.com/gitpod-io/openvscode-server
  # https://github.com/linuxserver/docker-vscodium

  # podman run -it --userns=keep-id --user 1001:999 --name code-server -p 127.0.0.1:8080:8080 \
  #   -v "$PWD/.local:/home/coder/.local:z" \
  #   -v "$PWD/.config:/home/coder/.config:z" \
  #   -v "$PWD/project:/home/coder/project:z" \
  #   docker.io/codercom/code-server:latest

  # podman run -it --init --userns=keep-id --user 1001:999 --name openvscode-server -p 3000:3000 \
  #   -v "$PWD:/home/workspace:z" \
  #   docker.io/gitpod/openvscode-server

  home-manager.users.${my-options.user.name} = { pkgs, ... }: {

    programs.vscodium.enable = true;
    programs.vscodium.mutableExtensionsDir = true;
    programs.vscodium.package = pkgs.vscodium;
    programs.vscodium.profiles.default.enableExtensionUpdateCheck = false;
    programs.vscodium.profiles.default.enableUpdateCheck = false;

    programs.vscodium.profiles.default.userSettings = {

      workbench.colorTheme = "Default Dark Modern";
      "workbench.colorCustomizations" = lib.mkIf theme.enabled {
        "foreground" = colors.foreground;
        "descriptionForeground" = colors.muted;
        "focusBorder" = colors.accent;
        "selection.background" = colors.selection;
        "textLink.foreground" = colors.cyan;
        "button.background" = colors.accent;
        "button.foreground" = colors.background;
        "button.hoverBackground" = colors.cyan;
        "input.background" = colors.background;
        "input.foreground" = colors.foreground;
        "input.border" = colors.black;
        "dropdown.background" = colors.surface;
        "dropdown.foreground" = colors.foreground;
        "activityBar.background" = colors.surface;
        "activityBar.foreground" = colors.accent;
        "activityBar.inactiveForeground" = colors.muted;
        "sideBar.background" = colors.surface;
        "sideBar.foreground" = colors.foreground;
        "sideBarSectionHeader.background" = colors.surface;
        "titleBar.activeBackground" = colors.surface;
        "titleBar.activeForeground" = colors.foreground;
        "titleBar.inactiveBackground" = colors.surface;
        "titleBar.inactiveForeground" = colors.muted;
        "editor.background" = colors.background;
        "editor.foreground" = colors.foreground;
        "editor.selectionBackground" = colors.selection;
        "editor.inactiveSelectionBackground" = colors.selection;
        "editor.lineHighlightBackground" = colors.surface;
        "editorCursor.foreground" = colors.accent;
        "editorLineNumber.foreground" = colors.muted;
        "editorLineNumber.activeForeground" = colors.accent;
        "editorGroupHeader.tabsBackground" = colors.surface;
        "tab.activeBackground" = colors.background;
        "tab.activeForeground" = colors.foreground;
        "tab.activeBorderTop" = colors.accent;
        "tab.inactiveBackground" = colors.surface;
        "tab.inactiveForeground" = colors.muted;
        "panel.background" = colors.background;
        "panel.border" = colors.black;
        "statusBar.background" = colors.surface;
        "statusBar.foreground" = colors.foreground;
        "statusBar.noFolderBackground" = colors.surface;
        "statusBar.debuggingBackground" = colors.yellow;
        "statusBar.debuggingForeground" = colors.background;
        "list.activeSelectionBackground" = colors.selection;
        "list.activeSelectionForeground" = colors.foreground;
        "list.inactiveSelectionBackground" = colors.surface;
        "list.hoverBackground" = colors.surface;
        "badge.background" = colors.accent;
        "badge.foreground" = colors.background;
        "progressBar.background" = colors.accent;
        "editorError.foreground" = colors.red;
        "editorWarning.foreground" = colors.yellow;
        "editorInfo.foreground" = colors.blue;
        "gitDecoration.addedResourceForeground" = colors.green;
        "gitDecoration.modifiedResourceForeground" = colors.yellow;
        "gitDecoration.deletedResourceForeground" = colors.red;
        "terminal.background" = colors.background;
        "terminal.foreground" = colors.foreground;
        "terminal.selectionBackground" = colors.selection;
        "terminalCursor.foreground" = colors.accent;
        "terminal.ansiBlack" = colors.black;
        "terminal.ansiRed" = colors.red;
        "terminal.ansiGreen" = colors.green;
        "terminal.ansiYellow" = colors.yellow;
        "terminal.ansiBlue" = colors.blue;
        "terminal.ansiMagenta" = colors.magenta;
        "terminal.ansiCyan" = colors.cyan;
        "terminal.ansiWhite" = colors.white;
        "terminal.ansiBrightBlack" = colors.brightBlack;
        "terminal.ansiBrightRed" = colors.red;
        "terminal.ansiBrightGreen" = colors.green;
        "terminal.ansiBrightYellow" = colors.yellow;
        "terminal.ansiBrightBlue" = colors.blue;
        "terminal.ansiBrightMagenta" = colors.magenta;
        "terminal.ansiBrightCyan" = colors.cyan;
        "terminal.ansiBrightWhite" = colors.brightWhite;
      };
      "editor.tokenColorCustomizations" = lib.mkIf theme.enabled {
        comments = colors.muted;
        strings = colors.yellow;
        keywords = colors.magenta;
        numbers = colors.yellow;
        types = colors.cyan;
        functions = colors.blue;
        variables = colors.foreground;
      };

      window.menuBarVisibility = "toggle";

      svelte.enable-ts-plugin = true;

      nix.enableLanguageServer = true;
      nix.serverPath = "nixd";
      nix.serverSettings = {
        nil = {
          diagnostics = {
            ignored = [ "unused_with" ];
          };
          formatting = {
            command = [ "nixpkgs-fmt" ];
          };
        };
        nixd = {
          options.nixos.expr = "(builtins.getFlake \"/home/ephemeral/n-data/nix/systems\").nixosConfigurations.zion-alpha.options";
          formatting = {
            command = [ "nixpkgs-fmt" ];
          };
        };
      };
    };
  };
}
