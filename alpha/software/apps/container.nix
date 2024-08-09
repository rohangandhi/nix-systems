{ pkgs, ... }: {
  # Docker
  virtualisation.containers.enable = true;
  virtualisation.podman.enable = true;
  virtualisation.podman.dockerCompat = true; # Create a `docker` alias for podman

  environment.systemPackages = [
    pkgs.dive # look into docker image layers
    pkgs.pods
    pkgs.podman-tui # status of containers in the terminal
    pkgs.podman-compose # start group of containers for dev
  ];
}
