{ config, my-options, ... }: {
  # Replace ! with the output of mkpasswd -m yescrypt. Keep real hashes private.
  users.users.${my-options.user.name}.hashedPassword = "!";
  assertions = [ {
    assertion = config.users.users.${my-options.user.name}.hashedPassword != "!";
    message = "Set the workstation login hash in zion/os/users.nix before installation.";
  } ];
}
