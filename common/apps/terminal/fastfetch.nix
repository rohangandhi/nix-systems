{ my-options, ... }: {

  home-manager.users.${my-options.user.name} = { pkgs, ... }: {
    programs.fastfetch.enable = true;
    programs.fastfetch.settings.modules = [
      "os"
      "kernel"
      "packages"
      "terminal"
      "shell"
      "cpu"
      "memory"
      "display"
      "gpu"
    ];

    programs.fish.functions.",info" = {
      description = "Show the calendar, system information, and disk usage";
      body = ''
        ${pkgs.coreutils}/bin/date
        ${pkgs.util-linux.bin}/bin/cal -3
        ${pkgs.fastfetch}/bin/fastfetch
        ${pkgs.duf}/bin/duf / "$HOME" /p-os/ /p-home/ /p-data/
      '';
    };
  };
}
