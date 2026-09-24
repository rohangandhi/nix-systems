{ config, lib, my-options, ... }:
let
  theme = config.my-theme;
  palette = theme.colors;
in {
  programs.tmux.enable = true;

  home-manager.users.${my-options.user.name} = { pkgs, ... }: {
    programs.tmux = {
      enable = true;
      shell = "${pkgs.fish}/bin/fish";
      terminal = "tmux-256color";
      mouse = true;
      baseIndex = 1;
      escapeTime = 10;
      focusEvents = true;
      historyLimit = 50000;
      extraConfig = lib.optionalString theme.enabled ''
        set -g status-style 'bg=#${palette.surface},fg=#${palette.muted}'
        set -g status-left '#[fg=#${palette.accent},bold] #S #[default]│ '
        set -g status-left-length 24
        set -g status-right '#[fg=#${palette.muted}]#H · %H:%M '
        set -g status-right-length 40
        set -g status-justify left
        setw -g window-status-format ' #I:#W '
        setw -g window-status-current-format '#[bg=#${palette.selection},fg=#${palette.accent},bold] #I:#W #[default]'
        setw -g window-status-separator ' '
        set -g pane-border-style 'fg=#${palette.black}'
        set -g pane-active-border-style 'fg=#${palette.accent}'
        set -g message-style 'bg=#${palette.selection},fg=#${palette.foreground}'
        setw -g mode-style 'bg=#${palette.selection},fg=#${palette.foreground}'
      '';
    };
    programs.fish.shellAbbrs.",tmux" = "tmux new-session -A -s main";
  };
}
