{ pkgs, ... }: {

  fonts.packages = [
    pkgs.jetbrains-mono
    pkgs.source-code-pro
    pkgs.nerd-fonts.fira-code
    pkgs.nerd-fonts.droid-sans-mono
    pkgs.nerd-fonts.terminess-ttf
  ];
}
