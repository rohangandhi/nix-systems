{ config, my-options, ... }: {

  home-manager.users.${my-options.user.name} = { pkgs, ... }: {

    programs.chromium.enable = true;
    programs.chromium.package = pkgs.chromium;
    programs.chromium.extensions = [
      { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; } # Ublock Origin
    ];
    programs.chromium.commandLineArgs = [ "--ozone-platform-hint=auto" ];
  };
}
