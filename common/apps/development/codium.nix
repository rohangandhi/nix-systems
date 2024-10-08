{ my-options, ... }: {

  xdg.mime.defaultApplications = {
    "text/plain" = "codium.desktop";
    "text/x-c" = "codium.desktop";
    "text/x-c++" = "codium.desktop";
    "text/x-python" = "codium.desktop";
    "text/x-java" = "codium.desktop";
    "text/x-cmake" = "codium.desktop";
    "text/markdown" = "codium.desktop";
    "application/x-shellscript" = "codium.desktop";
    "application/x-docbook+xml" = "codium.desktop";
    "application/x-yaml" = "codium.desktop";
    "application/json" = "codium.desktop";
    "application/xml" = "codium.desktop";
  };

  # TODO: use vscode in docker.

  # https://nixos.org/manual/nixpkgs/stable/#sec-pkgs-dockerTools
  # https://github.com/coder/code-server
  # https://github.com/gitpod-io/openvscode-server
  # https://github.com/linuxserver/docker-vscodium

  # podman run -it --userns=keep-id --user 1001:999 --name code-server -p 127.0.0.1:8080:8080 \
  #   -v "$PWD/.local:/home/coder/.local:z" \
  #   -v "$PWD/.config:/home/coder/.config:z" \
  #   -v "$PWD/project:/home/coder/project:z" \
  #   docker.io/codercom/code-server:latest

  # podman run -it --init --userns=keep-id --user 1001:999 --name openvscode-server -p 3000:3000 \
  #   -v "$PWD:/home/workspace:z" \
  #   docker.io/gitpod/openvscode-server

  home-manager.users.${my-options.user.name} = { pkgs, ... }: {

    # stylix.targets.vscode.enable = false;
    programs.vscode.enable = true;
    programs.vscode.enableExtensionUpdateCheck = false;
    programs.vscode.enableUpdateCheck = false;
    programs.vscode.mutableExtensionsDir = true;
    programs.vscode.package = pkgs.vscodium;
    programs.vscode.extensions = [
      pkgs.vscode-extensions.jnoortheen.nix-ide
    ];

    programs.vscode.userSettings = {

      workbench.colorTheme = "Default Dark Modern";

      window.menuBarVisibility = "toggle";

      nix.enableLanguageServer = true;
      nix.serverPath = "nixd";
      nix.serverSettings = {
        nil = {
          diagnostics = {
            ignored = [ "unused_with" ];
          };
          formatting = {
            command = [ "nixpkgs-fmt" ];
          };
        };
        nixd = {
          formatting = {
            command = [ "nixpkgs-fmt" ];
          };
          options = {
            # By default, this entry will be read from `import { }`.
            # You can write arbitrary Nix expressions here, to produce valid "options" declaration result.
            # Tip: for flake-based configuration, utilize `builtins.getFlake`
            nixos = {
              expr = "(builtins.getFlake \"/home/ephemeral/n-zion/nix/systems/zion/alpha\").nixosConfigurations..options";
            };
          };
        };
      };
    };
  };
}
