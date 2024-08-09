{ config, ... }: {

  home-manager.users.${config.my-options.user.name} = { pkgs, ... }: {
    programs.starship.enable = true;
    programs.starship.package = pkgs.starship;
    programs.starship.enableTransience = true;
    programs.starship.settings = {

      format = "$all$shlvl$character";

      shlvl = {
        disabled = false;
        format = "[$symbol]($style)";
        repeat = true;
        symbol = "❯";
        repeat_offset = 1;
        threshold = 0;
      };

      shell = {
        disabled = false;
        format = "[$indicator]($style) ";
      };

      os = {
        disabled = false;
      };

      directory = {
        disabled = false;
        format = "[$path]($style) [$read_only]($read_only_style) ";
        read_only = "[read only]";
        read_only_style = "red";
      };

      hostname = {
        disabled = false;
        ssh_only = false;
      };

      username = {
        disabled = false;
        show_always = true;
      };
    };
  };
}
