{ pkgs, ... }: {

  environment.systemPackages = [
    pkgs.kiro
  ];
}