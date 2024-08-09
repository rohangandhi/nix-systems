{ config, pkgs, my-options, ... }: 

{
  # Display Manager / Login
  services.greetd.enable = true;
  services.greetd.settings.initial_session = {
    command = "Hyprland";
    user = "ephemeral";
  };
  services.greetd.settings.default_session = {
    command = ''
      ${pkgs.greetd.tuigreet}/bin/tuigreet \
      --time \
      --user-menu \
      --window-padding 25 \
      --container-padding 1 \
      --prompt-padding 1 \
      --asterisks --asterisks-char "-" \
      --greeting "NixOS ${config.system.nixos.codeName} ${config.system.nixos.release}" \
      --theme "border=green;container=black;text=cyan;prompt=green;input=yellow;time=yellow;action=yellow;button=yellow" \
      --cmd Hyprland 
    '';
  };

  # Desktop Environment
  programs.hyprland.enable = true;
  programs.hyprland.xwayland.enable = true;

  home-manager.users.${my-options.user.name} = { config, my-options, ... }: {
    imports = [
      ./hyprland/hyprpaper.nix
      ./hyprland/hyprlock.nix
      ./hyprland/waybar.nix
      ./hyprland/rofi.nix
    ];

    wayland.windowManager.hyprland.enable = true;
    wayland.windowManager.hyprland.systemd.enable = config.wayland.windowManager.hyprland.enable;
    wayland.windowManager.hyprland.xwayland.enable = config.wayland.windowManager.hyprland.enable;
    wayland.windowManager.hyprland.settings = {

      monitor = ",preferred,auto,${my-options.display.scaling}";
      xwayland.force_zero_scaling = true;

      "$terminal" = "alacritty";
      "$fileManager" = "lf";
      "$menu" = "rofi -show drun -show-icons";
      "$lock" = "hyprlock";

      # env = [ "GDK_SCALE,${host.options.display.scaling}" "XCURSOR_SIZE,32" "HYPRCURSOR_SIZE,32" ];
      env = [ "GDK_SCALE,2" "XCURSOR_SIZE,32" "HYPRCURSOR_SIZE,32" ];
      misc = {
        force_default_wallpaper = 1; # Set to 0 or 1 to disable the anime mascot wallpapers
        disable_hyprland_logo = true; # If true disables the random hyprland logo / anime girl background. :(
      };
      input = {
        kb_layout = "us";
        numlock_by_default = 1;
      };

      "$mod" = "SUPER";
      bind = [
        # Example binds, see https://wiki.hyprland.org/Configuring/Binds/ for more
        "$mod, Q, exec, $terminal"
        "$mod, C, killactive,"
        "$mod, L, exec, $lock"
        "$mod, M, exit,"
        "$mod, E, exec, $fileManager"
        "$mod, V, togglefloating,"
        #bind  = $mod, R, exec, $menu
        "$mod, space, exec, $menu"
        "$mod, P, pseudo, # dwindle"
        "$mod, J, togglesplit, # dwindle"

        # Audio control
        ", XF86AudioLowerVolume, exec, pamixer -d 5"
        ", XF86AudioRaiseVolume, exec, pamixer -i 5"
        ", XF86AudioMute, exec, pamixer -t"

        # Move focus with mod + arrow keys
        "$mod, left, movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up, movefocus, u"
        "$mod, down, movefocus, d"

        # Switch workspaces with mod + [0-9]
        "$mod, KP_End, workspace, 1"
        "$mod, KP_Down, workspace, 2"
        "$mod, KP_Next, workspace, 3"
        "$mod, KP_Left, workspace, 4"
        "$mod, KP_Begin, workspace, 5"
        "$mod, KP_Right, workspace, 6"
        "$mod, KP_Home, workspace, 7"
        "$mod, KP_Up, workspace, 8"
        "$mod, KP_Prior, workspace, 9"
        "$mod, KP_Insert, workspace, 10"

        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"
        "$mod, 0, workspace, 10"

        # Move active window to a workspace with mod + SHIFT + [0-9]
        "$mod SHIFT, KP_End, movetoworkspace, 1"
        "$mod SHIFT, KP_Down, movetoworkspace, 2"
        "$mod SHIFT, KP_Next, movetoworkspace, 3"
        "$mod SHIFT, KP_Left, movetoworkspace, 4"
        "$mod SHIFT, KP_Begin, movetoworkspace, 5"
        "$mod SHIFT, KP_Right, movetoworkspace, 6"
        "$mod SHIFT, KP_Home, movetoworkspace, 7"
        "$mod SHIFT, KP_Up, movetoworkspace, 8"
        "$mod SHIFT, KP_Prior, movetoworkspace, 9"
        "$mod SHIFT, KP_Insert, movetoworkspace, 10"

        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"
        "$mod SHIFT, 0, movetoworkspace, 10"

        # special workspace (terminal)
        "$mod, T, togglespecialworkspace, term"
        "$mod SHIFT, T, movetoworkspace, special:term"
        "$mod, H, togglespecialworkspace, code"
        "$mod SHIFT, H, movetoworkspace, special:code"

        # Scroll through existing workspaces with mod + scroll
        # "$mod, mouse_down, workspace, e+1"
        # "$mod, mouse_up, workspace, e-1"

        # scroll_event_delay
        "$mod SHIFT, right, workspace, +1"
        "$mod SHIFT, left, workspace, -1"
      ];

      bindm = [
        # mouse movements
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];
    };

  };
}
