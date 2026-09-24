{ config, lib, my-options, ... }:
let
  theme = config.my-theme;
  palette = theme.colors;
in {

  programs.fish.enable = true;

  home-manager.users.${my-options.user.name} = { ... }: {
    xdg.desktopEntries.fish.name = "fish";
    xdg.desktopEntries.fish.exec = "fish";
    xdg.desktopEntries.fish.noDisplay = true;

    programs.fish.enable = true;
    programs.fish.functions.fish_greeting = "";
    # Global colors override saved universal colors without rewriting user state.
    programs.fish.interactiveShellInit = lib.optionalString theme.enabled ''
      set -g fish_color_normal ${palette.foreground}
      set -g fish_color_command ${palette.green}
      set -g fish_color_param ${palette.foreground}
      set -g fish_color_option ${palette.cyan}
      set -g fish_color_quote ${palette.yellow}
      set -g fish_color_redirection ${palette.magenta}
      set -g fish_color_end ${palette.cyan}
      set -g fish_color_error ${palette.red}
      set -g fish_color_comment ${palette.muted} --italics
      set -g fish_color_autosuggestion ${palette.muted}
      set -g fish_color_operator ${palette.magenta}
      set -g fish_color_escape ${palette.cyan}
      set -g fish_color_valid_path --underline
      set -g fish_color_search_match --background=${palette.selection}
      set -g fish_color_selection --background=${palette.selection}
      set -g fish_pager_color_prefix ${palette.green} --bold
      set -g fish_pager_color_completion ${palette.foreground}
      set -g fish_pager_color_description ${palette.muted}
      set -g fish_pager_color_progress ${palette.cyan}
      set -g fish_pager_color_selected_background --background=${palette.selection}
    '';
  };
}
