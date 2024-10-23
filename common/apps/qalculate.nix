{ pkgs, ... }: {

  environment.systemPackages = [
    pkgs.qalculate-qt
    pkgs.libqalculate
  ];
}
