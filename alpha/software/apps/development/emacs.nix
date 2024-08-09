{ my-options, ... }: {

  home-manager.users.${my-options.user.name} = { pkgs, ... }: {
    programs.emacs.enable = true;
    programs.emacs.package = pkgs.emacs;
  };
}
