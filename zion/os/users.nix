{ pkgs, my-options, ... }: {
  users.mutableUsers = false;
  users.groups.${my-options.group.name} = {
    gid = my-options.group.gid;
  };
  users.users.${my-options.user.name} = {
    uid = my-options.user.uid;
    group = my-options.group.name;
    hashedPassword = "$y$j9T$2VcEzSMw3HPEsVj2Mz26N.$l0NnWMz7UOk06b0FdxAZkItn9mscH1mjvFkQ16NOpG3"; # generated usin mkpasswd
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    isNormalUser = true;
    createHome = true;
    shell = pkgs.fish;
  };
}
