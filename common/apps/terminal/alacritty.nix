{ my-options, ... }: {

  home-manager.users.${my-options.user.name} = { pkgs, ... }: {
    programs.alacritty.enable = true;
    programs.alacritty.package = pkgs.alacritty;
    programs.alacritty.settings = {
      window.padding = { 
        x = 20;
        y = 10;
      };
      shell.program = "${pkgs.tmux}/bin/tmux";
    };
  };
}
