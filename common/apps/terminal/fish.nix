{ my-options, ... }: {

  programs.fish.enable = true;

  home-manager.users.${my-options.user.name} = { pkgs, ... }: {
    stylix.targets.fish.enable = false;
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

      # cd using yazi
      y = ''
        set tmp (mktemp -t "yazi-cwd.XXXXXX")
        yazi $argv --cwd-file="$tmp"
        if set cwd (command cat -- "$tmp"); and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
          builtin cd -- "$cwd"
        end
        rm -f -- "$tmp"
      '';
    };
  };
}
