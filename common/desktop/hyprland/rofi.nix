{ config, pkgs, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      rofi-wayland-unwrapped = prev.rofi-wayland-unwrapped.overrideAttrs (oldAttrs: {
        postInstall = (oldAttrs.postInstall or "") + ''
          rm -f $out/share/applications/rofi.desktop
          rm -f $out/share/applications/rofi-theme-selector.desktop
        '';
      });
    })
  ];

  programs.rofi.enable = config.wayland.windowManager.hyprland.enable;
  programs.rofi.package = pkgs.rofi-wayland;
  programs.rofi.plugins = [ ];
  programs.rofi.terminal = config.wayland.windowManager.hyprland.settings."$terminal";
  programs.rofi.cycle = false;
  programs.rofi.extraConfig = {
    display-drun = "Apps: ";
    modi = "drun,run,window";
    drun-display-format = "{icon} {name}";

    disable-history = true;
    hover-select = true;
    show-icons = true;
    # icon-theme = "Papirus";
    drun-show-actions = false;

    sort = true;
    sorting-method = "fzf";
    matching = "fuzzy";
  };

  stylix.targets.rofi.enable = false;
  xdg.desktopEntries.rofi-theme-selector.name = "Rofi Theme Selector";
  xdg.desktopEntries.rofi-theme-selector.exec = "rofi-theme-selector";
  xdg.desktopEntries.rofi-theme-selector.noDisplay = true;
  xdg.desktopEntries.rofi.name = "Rofi";
  xdg.desktopEntries.rofi.exec = "rofi -show";
  xdg.desktopEntries.rofi.noDisplay = true;

  programs.rofi.theme =
    let

      # Use `mkLiteral` for string-like values that should show without
      # quotes, e.g.:
      # {
      #   foo = "abc"; => foo: "abc";
      #   bar = mkLiteral "abc"; => bar: abc;
      # };
      inherit (config.lib.formats.rasi) mkLiteral;

      # https://github.com/chriskempson/base16/blob/main/styling.md

      # base00 - Default Background
      # base01 - Lighter Background (Used for status bars, line number and folding marks)
      # base02 - Selection Background
      # base03 - Comments, Invisibles, Line Highlighting

      # base04 - Dark Foreground (Used for status bars)
      # base05 - Default Foreground, Caret, Delimiters, Operators
      # base06 - Light Foreground (Not often used)
      # base07 - Light Background (Not often used)

      # base08 - Variables, XML Tags, Markup Link Text, Markup Lists, Diff Deleted
      # base09 - Integers, Boolean, Constants, XML Attributes, Markup Link Url
      # base0A - Classes, Markup Bold, Search Text Background
      # base0B - Strings, Inherited Class, Markup Code, Diff Inserted
      # base0C - Support, Regular Expressions, Escape Characters, Markup Quotes
      # base0D - Functions, Methods, Attribute IDs, Headings
      # base0E - Keywords, Storage, Selector, Markup Italic, Diff Changed
      # base0F - Deprecated, Opening/Closing Embedded Language Tags, e.g. <?php ?>

      inherit (config.lib.stylix.colors) base00 base01 base02 base03 base04 base05 base09 base0A;
    in
    {
      # Theme based on https://github.com/lr-tech/rofi-themes-collection

      "*" = {
        background-color = mkLiteral "transparent";
        text-color = mkLiteral "#${base04}";
        margin = mkLiteral "0px";
        padding = mkLiteral "0px";
        spacing = mkLiteral "0px";
      };

      window = {
        location = mkLiteral "center";
        width = mkLiteral "50%";
        background-color = mkLiteral "#${base00}ff";
        border = mkLiteral "1px";
        border-color = mkLiteral "#${base0A}aa";
      };

      mainbox = {
        padding = mkLiteral "12px";
      };

      inputbar = {
        background-color = mkLiteral "#${base02}ff";
        border-color = mkLiteral "#${base09}ff";
        border = mkLiteral "2px";
        padding = mkLiteral "8px 16px";
        spacing = mkLiteral "8px";
        children = map mkLiteral [ "prompt" "entry" ];
      };

      prompt = {
        text-color = "#${base05}aa";
      };

      entry = {
        placeholder = "Search";
        placeholder-color = mkLiteral "#${base03}aa";
      };

      message = {
        margin = mkLiteral "12px 0 0";
        border-color = mkLiteral "#${base01}aa";
        background-color = mkLiteral "#${base01}aa";
      };

      textbox = {
        padding = mkLiteral "8px 24px";
      };

      listview = {
        background-color = mkLiteral "transparent";
        margin = mkLiteral "12px 0 0";
        flow = mkLiteral "horizontal";
        lines = 3;
        columns = 4;
        fixed-height = true;
        fixed-columns = true;
        dynamic = false;
      };

      element = {
        padding = mkLiteral "8px 16px";
        spacing = mkLiteral "8px";
        orientation = mkLiteral "horizontal";
      };

      "element normal active, element-text selected" = {
        text-color = mkLiteral "#${base00}ff";
      };

      "element selected normal, element selected active" = {
        background-color = mkLiteral "#${base09}ff";
      };

      element-icon = {
        size = mkLiteral "2em";
        vertical-align = mkLiteral "0.5";
      };

      element-text = {
        text-color = mkLiteral "inherit";
        vertical-align = mkLiteral "0.5";
        horizontal-align = mkLiteral "0";
      };
    };

}
