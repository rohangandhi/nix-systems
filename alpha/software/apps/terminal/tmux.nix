{ my-options, ... }: {
  programs.tmux.enable = true;

  home-manager.users.${my-options.user.name} = { pkgs, ... }: {
    programs.tmux.enable = true;
    programs.tmux.package = pkgs.tmux;

    programs.tmux = {
      plugins = [
        pkgs.tmuxPlugins.better-mouse-mode
        pkgs.tmuxPlugins.catppuccin
        pkgs.tmuxPlugins.sensible
      ];
      shell = "${pkgs.fish}/bin/fish";
      extraConfig = ''
        set -g @catppuccin_flavour 'mocha'
        set -g mouse on
        set -g base-index 1
        setw -g pane-base-index 1

        set -g allow-passthrough on
        set -ga update-environment TERM
        set -ga update-environment TERM_PROGRAM
      '';
    };
  };
}
