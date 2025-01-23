{ pkgs,  ... }: {
  environment.systemPackages = [
    pkgs.jan
    pkgs.lmstudio
  ];
}
