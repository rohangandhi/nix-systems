{ inputs, pkgs, ... }: {

  imports = [ inputs.codex-desktop-linux.nixosModules.default ];

  programs.codexDesktopLinux.enable = true;

  environment.systemPackages = [
    pkgs.codex
  ];
}
