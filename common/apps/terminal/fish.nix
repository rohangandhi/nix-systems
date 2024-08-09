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
        end
      '';
      lfcd.wraps = "lf";
      lfcd.description = "lf - Terminal file manager (changing directory on exit)";

      # `command` is needed when `lfcd` is aliased to `lf`.
      # Quotes will cause `cd` to not change directory if `lf` prints nothing to stdout due to an error.
      lfcd.body = ''cd "$(command lf -print-last-dir $argv)"'';
    };
  };
}
