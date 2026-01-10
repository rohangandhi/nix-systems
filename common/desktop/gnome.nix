{ my-options, lib, pkgs, ... }: {

  services.displayManager.gdm.enable = true;
  services.displayManager.gdm.wayland = true;
  services.desktopManager.gnome.enable = true;

  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "${my-options.user.name}";
  
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  # For a minimal / barebones Gnome DE
  services.gnome.core-apps.enable = false;
  services.gnome.core-developer-tools.enable = false;
  services.gnome.games.enable = false;
  environment.systemPackages = [ pkgs.gnome-console pkgs.nautilus ];
  environment.gnome.excludePackages = [ pkgs.gnome-tour pkgs.gnome-user-docs ];
  
  programs.dconf.profiles.gdm.databases = [{
    settings."org/gnome/desktop/interface".scaling-factor = lib.gvariant.mkUint32 2;
  }];

  environment.sessionVariables.NIXOS_OZONE_WL = "1"; # force vs code and other electron stuff to use xwayland native scaling

  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/gnome/mutter" = {
          experimental-features = [
            "scale-monitor-framebuffer" # Enables fractional scaling (125% 150% 175%)
            "variable-refresh-rate" # Enables Variable Refresh Rate (VRR) on compatible displays
            "xwayland-native-scaling" # Scales Xwayland applications to look crisp on HiDPI screens
          ];
        };
        "org/gnome/settings-daemon/plugins/housekeeping" = {
          donation-reminder-enabled = false;
        };
      };
    }
  ];
  home-manager.users.${my-options.user.name} = { pkgs, ... }: {
    dconf.enable = true;
    dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
    dconf.settings."org/gnome/desktop/interface".accent-color = "green";

    # Wallpaper from persistent directory
    dconf.settings."org/gnome/desktop/background".picture-uri = "file:///home/${my-options.user.name}/n-data/wallpapers/lightning-abstract-2560x1440-v0-no9zyx3wnnwf1.webp";
    dconf.settings."org/gnome/desktop/background".picture-uri-dark = "file:///home/${my-options.user.name}/n-data/wallpapers/lightning-abstract-2560x1440-v0-no9zyx3wnnwf1.webp";

    # Power management settings
    dconf.settings."org/gnome/settings-daemon/plugins/power".sleep-inactive-ac-timeout = 1800;  # 30 minutes suspend on AC power
    dconf.settings."org/gnome/settings-daemon/plugins/power".sleep-inactive-ac-type = "suspend";  # Suspend when inactive on AC

    # Night light settings
    dconf.settings."org/gnome/settings-daemon/plugins/color".night-light-enabled = true;
    dconf.settings."org/gnome/settings-daemon/plugins/color".night-light-temperature = 3500;  # Color temperature in Kelvin (warmer = lower number)
    dconf.settings."org/gnome/settings-daemon/plugins/color".night-light-schedule-automatic = true;  # Use automatic sunrise/sunset schedule

    # Pin favorite apps to the GNOME dock
    dconf.settings."org/gnome/shell".favorite-apps = [
      "firefox.desktop"
      "org.gnome.Nautilus.desktop"
      "Alacritty.desktop"
      "cursor.desktop"
      "codium.desktop"
      "code.desktop"
      "antigravity.desktop"
    ];

    dconf.settings."org/gnome/shell/app-switcher" = {
      current-workspace-only = true;
    };

    # Scale display to 200% on login
    systemd.user.services.gnome-scaling = {
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };

      Unit = {
        Description = "Apply gnome scaling on login";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };

      # The following script is AI generated.
      Service = {
        Type = "oneshot";
        ExecStart = let
          scalingScript = pkgs.writeShellApplication {
            name = "gnome-scaling";
            runtimeInputs = [ pkgs.jq pkgs.systemd pkgs.glib ];
            text = ''
              set -euo pipefail

              # Only run on GNOME Wayland sessions
              if [[ "''${XDG_CURRENT_DESKTOP:-}" != "GNOME" ]]; then
                exit 0
              fi
              if [[ "''${XDG_SESSION_TYPE:-}" != "wayland" ]]; then
                exit 0
              fi

              SCALE_FACTOR=2

              NAMESPACE="org.gnome.Mutter.DisplayConfig"
              OBJECT="/org/gnome/Mutter/DisplayConfig"
              METHOD_APPLY="org.gnome.Mutter.DisplayConfig.ApplyMonitorsConfig"

              # Wait for the DisplayConfig interface to be ready on the user bus
              attempts=10
              while (( attempts > 0 )); do
                if busctl --user --timeout=1 introspect "$NAMESPACE" "$OBJECT" >/dev/null 2>&1; then
                  break
                fi
                sleep 0.5
                attempts=$((attempts - 1))
              done
              if (( attempts == 0 )); then
                # GNOME/mutter D-Bus not ready; skip
                exit 0
              fi

              # Fetch and parse current state using busctl JSON to avoid fragile text parsing
              read -r serial x y scale transform primary connector mode_id < <(
                busctl --user --json=short call "$NAMESPACE" "$OBJECT" "$NAMESPACE" GetCurrentState |
                jq -r '
                  def first_current_mode_label:
                    .data[1][0][1]
                    | map(select(.[6]["is-current"]?.data == true) | .[0])
                    | (.[0] // empty);
                  [
                    .data[0],                 # serial
                    .data[2][0][0],           # x
                    .data[2][0][1],           # y
                    .data[2][0][2],           # scale
                    .data[2][0][3],           # transform
                    .data[2][0][4],           # primary
                    .data[2][0][5][0][0],     # connector
                    (first_current_mode_label // .data[1][0][1][0][0])
                  ] | @tsv'
              )

              if [[ -z "$serial" || -z "$connector" || -z "$x" || -z "$y" || -z "$scale" || -z "$transform" || -z "$primary" || -z "$mode_id" ]]; then
                echo "Failed to parse current display state from Mutter D-Bus output." >&2
                exit 1
              fi

              new_scale="$SCALE_FACTOR"

              # Build logical monitors argument for ApplyMonitorsConfig
              logical_monitors_arg="@a(iiduba(ssa{sv})) [(''${x}, ''${y}, ''${new_scale}, uint32 ''${transform}, ''${primary}, [(\"''${connector}\", \"''${mode_id}\", @a{sv} {})])]"

              # Apply configuration
              # method=1 applies without a revert/keep dialog (use 2 to show that dialog)
              gdbus call --session \
                --dest "$NAMESPACE" \
                --object-path "$OBJECT" \
                --method "$METHOD_APPLY" \
                "uint32 $serial" "uint32 1" "$logical_monitors_arg" "@a{sv} {}" >/dev/null
            '';
          };
        in "${scalingScript}/bin/gnome-scaling";
      };
    };
  };
}
