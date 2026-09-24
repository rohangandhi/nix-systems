{ config, lib, my-options, ... }:
let
  theme = config.my-theme;
  palette = theme.colors;
  colors = builtins.mapAttrs (_: hex: "#${hex}") palette;
in {

  home-manager.users.${my-options.user.name} = { pkgs, ... }: {
    programs.zed-editor.enable = true;
    programs.zed-editor.package = pkgs.zed-editor;
    programs.zed-editor.extensions = [
      "nix"
    ];
    # Home Manager merges mutable settings, so omission would retain our old theme.
    programs.zed-editor.userSettings.theme = if theme.enabled then {
      mode = "dark";
      dark = theme.name;
      light = theme.name;
    } else {
      mode = "system";
      dark = "One Dark";
      light = "One Light";
    };
    programs.zed-editor.themes.shared-palette = lib.mkIf theme.enabled {
      "$schema" = "https://zed.dev/schema/themes/v0.2.0.json";
      name = theme.name;
      author = "Local configuration";
      themes = [{
        name = theme.name;
        appearance = "dark";
        style = {
          "background" = colors.background;
          "surface.background" = colors.surface;
          "elevated_surface.background" = colors.surface;
          "border" = colors.black;
          "border.variant" = colors.black;
          "border.focused" = colors.accent;
          "border.selected" = colors.accent;
          "text" = colors.foreground;
          "text.muted" = colors.muted;
          "text.placeholder" = colors.muted;
          "text.accent" = colors.accent;
          "icon" = colors.foreground;
          "icon.muted" = colors.muted;
          "icon.accent" = colors.accent;
          "element.background" = colors.surface;
          "element.hover" = colors.selection;
          "element.active" = colors.selection;
          "element.selected" = colors.selection;
          "ghost_element.hover" = colors.surface;
          "ghost_element.active" = colors.selection;
          "ghost_element.selected" = colors.selection;
          "title_bar.background" = colors.surface;
          "title_bar.inactive_background" = colors.surface;
          "toolbar.background" = colors.background;
          "status_bar.background" = colors.surface;
          "tab_bar.background" = colors.surface;
          "tab.active_background" = colors.background;
          "tab.inactive_background" = colors.surface;
          "panel.background" = colors.surface;
          "panel.focused_border" = colors.accent;
          "pane.focused_border" = colors.accent;
          "editor.background" = colors.background;
          "editor.foreground" = colors.foreground;
          "editor.gutter.background" = colors.background;
          "editor.line_number" = colors.muted;
          "editor.active_line_number" = colors.accent;
          "editor.active_line.background" = colors.surface;
          "editor.highlighted_line.background" = colors.selection;
          "editor.indent_guide" = colors.black;
          "editor.indent_guide_active" = colors.muted;
          "search.match_background" = "${colors.yellow}40";
          "link_text.hover" = colors.cyan;
          "error" = colors.red;
          "warning" = colors.yellow;
          "info" = colors.blue;
          "success" = colors.green;
          "created" = colors.green;
          "modified" = colors.yellow;
          "deleted" = colors.red;
          "conflict" = colors.magenta;
          "ignored" = colors.muted;
          "terminal.background" = colors.background;
          "terminal.foreground" = colors.foreground;
          "terminal.dim_foreground" = colors.muted;
          "terminal.bright_foreground" = colors.brightWhite;
          "terminal.ansi.black" = colors.black;
          "terminal.ansi.red" = colors.red;
          "terminal.ansi.green" = colors.green;
          "terminal.ansi.yellow" = colors.yellow;
          "terminal.ansi.blue" = colors.blue;
          "terminal.ansi.magenta" = colors.magenta;
          "terminal.ansi.cyan" = colors.cyan;
          "terminal.ansi.white" = colors.white;
          "terminal.ansi.bright_black" = colors.brightBlack;
          "terminal.ansi.bright_red" = colors.red;
          "terminal.ansi.bright_green" = colors.green;
          "terminal.ansi.bright_yellow" = colors.yellow;
          "terminal.ansi.bright_blue" = colors.blue;
          "terminal.ansi.bright_magenta" = colors.magenta;
          "terminal.ansi.bright_cyan" = colors.cyan;
          "terminal.ansi.bright_white" = colors.brightWhite;
          players = [{
            cursor = colors.accent;
            background = colors.accent;
            selection = "${colors.selection}cc";
          }];
          syntax = {
            "comment".color = colors.muted;
            "comment.doc".color = colors.muted;
            "string".color = colors.yellow;
            "string.escape".color = colors.cyan;
            "keyword".color = colors.magenta;
            "number".color = colors.yellow;
            "boolean".color = colors.yellow;
            "type".color = colors.cyan;
            "function".color = colors.blue;
            "variable".color = colors.foreground;
            "property".color = colors.foreground;
            "operator".color = colors.magenta;
            "punctuation".color = colors.muted;
          };
        };
      }];
    };
  };
}
