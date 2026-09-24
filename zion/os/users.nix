{ lib, pkgs, my-options, ... }: {
  programs.fish.enable = true;
  users.mutableUsers = false;
  users.groups.${my-options.group.name} = {
    gid = my-options.group.gid;
  };
  users.users.${my-options.user.name} = {
    uid = my-options.user.uid;
    group = my-options.group.name;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    isNormalUser = true;
    # The actual login hash is supplied by the host's credential module.
    hashedPassword = lib.mkDefault "!";
    shell = pkgs.fish;
  };
}
