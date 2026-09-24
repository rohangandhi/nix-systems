{ my-options, ... }: {

  home-manager.users.${my-options.user.name} = { pkgs, ... }: {
    programs.bat.enable = true;

    programs.eza.enable = true;
    programs.eza.enableBashIntegration = false;
    programs.eza.enableFishIntegration = false;
    programs.eza.enableZshIntegration = false;

    # Expand shortcuts visibly while leaving cat, ls, and du unchanged.
    programs.fish.shellAbbrs = {
      gs = "git status";
      gl = "git log --graph --pretty=format:'%Cred%h%Creset - %s %Cgreen(%ar) %C(bold blue)[%an]%Creset%C(yellow)%d%Creset' --abbrev-commit";
      ",cat" = "bat -n";
      ",ls" = "eza --long --all --group-directories-first --sort extension --icons";
      ",du" = "dust -w 80 -Bxr -d 1";
      ",df" = "duf";
    };

    home.packages = [
      pkgs.dust
      pkgs.duf
      pkgs.fd
      pkgs.jq
    ];
  };
}
