{ pkgs, my-options, ... }: {
  fileSystems = {
    "/" = {
      device = "none";
      fsType = "tmpfs";
      options = [ "defaults" "size=4G" "mode=755" ];
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/BFE4-67CD";
      fsType = "vfat";
      options = [ "umask=0077" ];
    };

    "/p-os" = {
      device = "/dev/disk/by-uuid/99c7cd9b-d176-4601-ba5c-3fc697372082";
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
      device = "/dev/disk/by-uuid/f23bd0f5-b290-41e2-9ffa-6dcf07095e0e";
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

  };


  boot.initrd.luks.devices."decrypted" = 
    {
      device = "/dev/disk/by-uuid/0d2f2be9-1440-4558-8536-162d3e0c548c";
      preLVM = true;
      allowDiscards = true;
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
  };
}
