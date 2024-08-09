{ config, ... }: {

  home-manager.users.${config.my-options.user.name} = { pkgs, ... }: {
    programs.emacs.enable = true;
    programs.emacs.package = pkgs.emacs;
  };
}
