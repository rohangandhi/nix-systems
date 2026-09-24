{ pkgs, my-options, ... }: {
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

  # Rootless Podman needs subordinate IDs on native Linux for user namespace
  # mapping. Keep this scoped to the managed login user instead of granting
  # broader podman socket access via the `podman` group.
  users.users.${my-options.user.name}.autoSubUidGidRange = true;

  home-manager.users.${my-options.user.name} = { ... }: {
    # Use the exec-capable data filesystem for rootless containers and volumes.
    home.file.".config/containers/storage.conf".text = ''
      [storage]
      driver = "overlay"
      graphroot = "/p-data/containers/storage"
    '';
    home.file.".config/containers/containers.conf".text = ''
      [engine]
      volume_path = "/p-data/containers/storage/volumes"
    '';
  };
}
