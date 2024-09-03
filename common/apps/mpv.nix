# https://iamscum.wordpress.com/guides/videoplayback-guide/mpv-conf/
{ pkgs,  ... }: {

  # For better configurations: https://iamscum.wordpress.com/guides/videoplayback-guide/#linux
  environment.systemPackages = [
    pkgs.celluloid
  ];
}
