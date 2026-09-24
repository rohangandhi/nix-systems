{ lib, my-options, ... }: {
  home-manager.users.${my-options.user.name} = { pkgs, ... }:
  let
    # Avoid GNOME's lingering busy cursor when Electron does not complete the
    # launch notification. Keep upstream launcher actions and URL handling.
    desktopEntries = pkgs.runCommandLocal "vscodium-desktop-entries" {
      nativeBuildInputs = [ pkgs.desktop-file-utils ];
    } ''
      mkdir -p "$out"
      cp ${pkgs.vscodium}/share/applications/codium{,-url-handler}.desktop "$out/"
      chmod u+w "$out/"*.desktop
      for desktop in "$out/"*.desktop; do
        desktop-file-edit --set-key=StartupNotify --set-value=false "$desktop"
        desktop-file-validate "$desktop"
      done
    '';
  in {
    xdg.dataFile."applications/codium.desktop".source = "${desktopEntries}/codium.desktop";
    xdg.dataFile."applications/codium-url-handler.desktop".source = "${desktopEntries}/codium-url-handler.desktop";

    programs.vscodium = {
      enable = true;
      package = pkgs.vscodium;
      mutableExtensionsDir = true;
      profiles.default = {
        extensions = [
          pkgs.vscode-extensions.jnoortheen.nix-ide
          pkgs.vscode-extensions.svelte.svelte-vscode
        ];
        enableUpdateCheck = false; # Nix updates the application.
        mutableUserSettings = true;
        userSettings = {
          "telemetry.telemetryLevel" = "off";
          "extensions.autoCheckUpdates" = true;
          "workbench.colorTheme" = lib.mkDefault "Dark Modern";
          "window.menuBarVisibility" = "toggle";

          "terminal.integrated.defaultProfile.linux" = "fish";
          "terminal.integrated.profiles.linux".fish.path = lib.getExe pkgs.fish;
          "terminal.integrated.fontFamily" = "NotoSansM Nerd Font Mono";
          "terminal.integrated.fontSize" = 15; # Pixels; approximately 11 pt.
          "terminal.integrated.fontWeight" = "300";
          "terminal.integrated.fontWeightBold" = "500";

          "[nix]"."editor.defaultFormatter" = "jnoortheen.nix-ide";
          "nix.enableLanguageServer" = true;
          "nix.serverPath" = lib.getExe pkgs.nil;
          "nix.serverSettings".nil = {
            formatting.command = [ (lib.getExe pkgs.nixfmt) ];
            # Editing should not fetch dependencies or evaluate a host by default.
            nix.flake = {
              autoArchive = false;
              autoEvalInputs = false;
              nixpkgsInputName = null;
            };
          };
        };
      };
    };
  };
}
