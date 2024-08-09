{ pkgs, my-options, ... }: {
  fileSystems = {
    "/" = {
      device = "none";
      fsType = "tmpfs";
      options = [ "defaults" "size=4G" "mode=755" ];
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/7822-E0D1";
      fsType = "vfat";
      options = [ "umask=0077" ];
    };

    "/p-os" = {
      device = "/dev/disk/by-uuid/87015a73-78f0-44c9-9029-8e818a096a8a";
      fsType = "ext4";
      neededForBoot = true;
    };
    "/nix" = {
      device = "/p-os/nix";
      fsType = "none";
      options = [ "bind" ];
      depends = [ "/p-os" ];
      neededForBoot = true;
    };

    "/p-home" = {
      device = "/dev/disk/by-uuid/f33685db-6c45-4549-9659-09b3668a90bf";
      fsType = "ext4";
      options = [ "user" "exec" "suid" "dev" ];
      neededForBoot = true;
    };
    "/home/${my-options.user.name}" =
      let
        uid = "${builtins.toString my-options.user.uid}";
        gid = "${builtins.toString my-options.group.gid}";
      in
      {
        device = "none";
        fsType = "tmpfs";
        options = [ "size=4G" "mode=1755" "uid=${uid}" "gid=${gid}" ];
      };

    "/home/${my-options.user.name}/n-zion" =
      let
        automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
        uid = "${builtins.toString my-options.user.uid}";
        gid = "${builtins.toString my-options.group.gid}";
      in
      {
        device = "//192.168.0.108/zion";
        fsType = "cifs";
        options = [ "${automount_opts},uid=${uid},gid=${gid}" ];
      };

    "/p-games" = {
      device = "/dev/disk/by-uuid/29e3b270-b6cb-40bb-9f1a-d4fa489bc765";
      fsType = "ext4";
      options = [ "user" "exec" "suid" "dev" ];
      neededForBoot = true;
    };

  };

  environment.systemPackages = [
    pkgs.cifs-utils
    pkgs.nfs-utils
  ];


  environment.persistence."/p-os" = {
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/etc/NetworkManager/system-connections"
    ];
  };


  home-manager.users.${my-options.user.name} = { my-options, ... }: {
    home.persistence."/p-home/${my-options.user.name}" = {
      directories = [
        ".cache/nix-index"
        ".local/share/fish"
        ".config/VSCodium"
        ".mozilla"
        ".ssh"
        "projects"
      ];
      files = [ ];
      allowOther = true;
    };

    home.persistence."/p-games/${my-options.user.name}" = {
      directories = [
        ".local/share/Steam"
      ];
      files = [ ];
      allowOther = true;
    };
  };

}
