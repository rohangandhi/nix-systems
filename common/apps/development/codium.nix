{ config, inputs, lib, my-options, ... }:
let
  theme = config.my-theme;
  palette = theme.colors;
  colors = builtins.mapAttrs (_: hex: "#${hex}") palette;
  # Use the public configuration from this build, independent of checkout location.
  # A project's .vscode/settings.json can override this to inspect its own flake.
  hostOptions = ''(builtins.getFlake "${inputs.self}").nixosConfigurations.${my-options.name}.options'';
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

  home-manager.users.${my-options.user.name} = { pkgs, ... }:
  let
    # A theme keeps colors out of mutable settings.json. Switching palettes or
    # turning them off then needs only a change to workbench.colorTheme.
    paletteTheme = pkgs.writeText "vscodium-shared-palette.json" (builtins.toJSON {
      name = theme.name;
      include = "./dark_modern.json";
      colors = {
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
      # Match VSCodium's scopes for the former tokenColorCustomizations groups.
      tokenColors = [
        { scope = [ "comment" "punctuation.definition.comment" ]; settings.foreground = colors.muted; }
        { scope = [ "string" "meta.embedded.assembly" ]; settings.foreground = colors.yellow; }
        { scope = [ "keyword - keyword.operator" "keyword.control" "storage" "storage.type" ]; settings.foreground = colors.magenta; }
        { scope = [ "constant.numeric" ]; settings.foreground = colors.yellow; }
        { scope = [ "entity.name.type" "entity.name.class" "support.type" "support.class" ]; settings.foreground = colors.cyan; }
        { scope = [ "entity.name.function" "support.function" ]; settings.foreground = colors.blue; }
        { scope = [ "variable" "entity.name.variable" ]; settings.foreground = colors.foreground; }
      ];
    });
    paletteManifest = pkgs.writeText "vscodium-shared-palette-package.json" (builtins.toJSON {
      name = "shared-palette";
      publisher = "local";
      version = "1.0.0";
      engines.vscode = "^1.90.0";
      displayName = "Shared Palette";
      contributes.themes = [{
        id = "Shared Palette";
        label = theme.name;
        uiTheme = "vs-dark";
        path = "./themes/shared-palette.json";
      }];
    });
    paletteExtension = pkgs.runCommandLocal "vscode-extension-local-shared-palette" {
      version = "1.0.0";
      passthru = {
        vscodeExtPublisher = "local";
        vscodeExtName = "shared-palette";
        vscodeExtUniqueId = "local.shared-palette";
      };
    } ''
      extension="$out/share/vscode/extensions/local.shared-palette"
      mkdir -p "$extension"
      cp -r ${pkgs.vscodium}/lib/vscode/resources/app/extensions/theme-defaults/themes "$extension/themes"
      chmod u+w "$extension/themes"
      cp ${paletteTheme} "$extension/themes/shared-palette.json"
      cp ${paletteManifest} "$extension/package.json"
    '';
  in {

    programs.vscodium.enable = true;
    programs.vscodium.mutableExtensionsDir = true;
    programs.vscodium.package = pkgs.vscodium;
    # The flake supplies the application and these baseline extensions.
    # Additional extensions and extension updates remain available in the UI.
    programs.vscodium.profiles.default.extensions = [
      pkgs.vscode-extensions.jnoortheen.nix-ide
      pkgs.vscode-extensions.svelte.svelte-vscode
    ] ++ lib.optional theme.enabled paletteExtension;
    programs.vscodium.profiles.default.enableExtensionUpdateCheck = true;
    programs.vscodium.profiles.default.enableUpdateCheck = false;

    # Home Manager reapplies these settings on rebuild; other UI preferences survive.
    # Its link cleanup removes the old read-only settings symlink during migration.
    programs.vscodium.profiles.default.mutableUserSettings = true;
    programs.vscodium.profiles.default.userSettings = {

      "telemetry.telemetryLevel" = "off";
      "workbench.colorTheme" = if theme.enabled then "Shared Palette" else "Dark Modern";

      "window.menuBarVisibility" = "toggle";

      "terminal.integrated.defaultProfile.linux" = "fish";
      "terminal.integrated.profiles.linux".fish.path = lib.getExe pkgs.fish;
      "terminal.integrated.fontFamily" = "NotoSansM Nerd Font Mono";
      # VSCodium uses pixels; Alacritty's 11 pt is approximately 15 px.
      "terminal.integrated.fontSize" = 15;
      "terminal.integrated.fontWeight" = "300";
      "terminal.integrated.fontWeightBold" = "500";

      "svelte.enable-ts-plugin" = true;

      "[nix]"."editor.defaultFormatter" = "jnoortheen.nix-ide";
      "nix.enableLanguageServer" = true;
      "nix.serverPath" = lib.getExe pkgs.nixd;
      "nix.serverSettings" = {
        nixd = {
          nixpkgs.expr = ''import ${inputs.nixpkgs} { system = "${pkgs.stdenv.hostPlatform.system}"; }'';
          options.nixos.expr = hostOptions;
          options.home-manager.expr = "(${hostOptions}).home-manager.users.type.getSubOptions []";
          formatting.command = [ (lib.getExe pkgs.nixfmt) ];
        };
      };
    };
  };
}
