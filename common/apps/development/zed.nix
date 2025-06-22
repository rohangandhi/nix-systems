{ my-options, ... }: {

  home-manager.users.${my-options.user.name} = { pkgs, ... }: {
    programs.zed-editor.enable = true;
    programs.zed-editor.package = pkgs.zed-editor;
    programs.zed-editor.extensions = [
      "nix"
    ];
  };
}
