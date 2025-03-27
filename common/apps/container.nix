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

  users.users.${my-options.user.name} = {
    extraGroups = [ "podman" ];
  };
  home-manager.users.${my-options.user.name} = { my-options, ... }: {
    # hard coding persistent storage path because 
    # home manager persistence module's fuse mount seems to not work.
    home.file.".config/containers/storage.conf".text = ''
      [storage]
      driver = "overlay"
      graphroot = "/p-home/${my-options.user.name}/.local/share/containers/storage"
    '';
  };
}
