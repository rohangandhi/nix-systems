{ my-options, ... }: {

  programs.fish.enable = true;

  home-manager.users.${my-options.user.name} = { pkgs, ... }: {
    xdg.desktopEntries.fish.name = "fish";
    xdg.desktopEntries.fish.exec = "fish";
    xdg.desktopEntries.fish.noDisplay = true;

    programs.fish.enable = true;
    programs.fish.package = pkgs.fish;
    programs.fish.plugins = [ ];
    programs.fish.functions = {
      fish_greeting = ''
        if test "$PWD" = "$HOME"
          date
          cal -3
          ${pkgs.fastfetch}/bin/fastfetch
          ,df / ~ /p-os/ /p-home/ /p-data/
        end
      '';
    };
  };
}
