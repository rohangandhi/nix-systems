{ config, ... }: {

  home-manager.users.${config.my-options.user.name} = { pkgs, ... }: {
    programs.yazi.enable = true;
    programs.yazi.settings = {
      log = {
        enabled = false;
      };
      manager = {
        ratio = [ 1 2 2 ];
        show_hidden = true;
        sort_by = "extension";
        sort_dir_first = true;
        sort_reverse = true;
      };
      preview = {
        ueberzug_scale = 1;
        ueberzug_offset = [ 4 1 (-0.5) (-0.5) ];
      };
    };

    home.packages = [
      pkgs.ueberzugpp
    ];
  };
}
