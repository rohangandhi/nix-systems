{ pkgs, my-options, ... }: {

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  documentation.nixos.enable = false;

  environment.systemPackages = [
    pkgs.nixpkgs-fmt
    pkgs.nixfmt-rfc-style
    pkgs.nil
    pkgs.nixd

    pkgs.nix-index
  ];


  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your home accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.05"; # Did you read the comment?

  home-manager.users.${my-options.user.name} = { ... }: {
    # The state version is required and should stay at the version you
    # originally installed.
    home.stateVersion = "24.11";
  };
}
