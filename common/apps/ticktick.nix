{ pkgs,  ... }: {
  environment.systemPackages = [
    pkgs.ticktick
  ];
}
