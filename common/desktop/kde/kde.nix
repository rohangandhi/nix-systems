{ my-options, ... }: {
  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;
  services.displayManager.defaultSession = "plasma";
  services.displayManager.sddm.wayland.enable = true;


  home-manager.users.${my-options.user.name} = { pkgs, ... }: {
    # nix run github:nix-community/plasma-manager

    imports = [
      ./generated.nix
    ];
    programs.plasma = {
      workspace = {
        lookAndFeel = "org.kde.breezedark.desktop";
        colorScheme = "BreezeDark";
        theme = "breeze-dark";
        cursor.theme = "Bibata-Modern-Ice";
      };
    };

    # Cannot figure out how to scale using plasma-manager. 
    # Possibly not supported, so manually scaling using kscreen-doctor.
    systemd.user.services.kscreen-scaling = {
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };

      Unit = {
        Description = "Apply kscreen scaling on login";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        Type = "oneshot";
        ExecStart = toString (pkgs.writeShellScript "kscreen-scaling" ''
          # Get all outputs
          OUTPUTS=$(${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor -o | grep 'Output' | awk '{print $3}')
          SCALE_FACTOR=2

          # Apply scaling to each output
          for OUTPUT in $OUTPUTS; do
            echo "Applying scaling factor of $SCALE_FACTOR to output $OUTPUT"
            ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output.$OUTPUT.scale.$SCALE_FACTOR
          done
        '');
      };
    };
  };

}
