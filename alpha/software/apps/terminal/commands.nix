{ config, ... }: {

  environment.shellAliases = {
    gs = "git status";
    gl = "git log --graph --pretty=format:'%Cred%h%Creset - %s %Cgreen(%ar) %C(bold blue)[%an]%Creset%C(yellow)%d%Creset' --abbrev-commit";
    du = "du -ahx -d 1 | sort -h -r";
  };

  home-manager.users.${config.my-options.user.name} = { pkgs, ... }: {
    programs.bat.enable = true;
    programs.bat.package = pkgs.bat;
    home.shellAliases.cat = "bat -n";

    programs.eza.enable = true;
    programs.eza.package = pkgs.eza;
    home.shellAliases.",ls" = "eza --long --all --group-directories-first --sort extension --icons --tree --level 1";
    home.shellAliases.",du" = "dust -w 80 -Bxr -d 1";

    home.packages = [
      pkgs.du-dust
    ];

  };
}
