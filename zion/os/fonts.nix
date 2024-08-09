{ pkgs, ... }: {

  fonts.packages = [
    pkgs.terminus-nerdfont
    pkgs.jetbrains-mono
    (pkgs.nerdfonts.override { fonts = [ "FiraCode" "DroidSansMono" "JetBrainsMono" "SourceCodePro" "Terminus" ]; })
  ];
}
