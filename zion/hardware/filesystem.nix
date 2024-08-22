{ pkgs, my-options, ... }: {

  disko.devices = {
    disk.main = {
        device = "/dev/disk/by-id/nvme-Samsung_SSD_990_EVO_1TB_S7M3NS0X118132L_1";
        type = "disk";
        
        content = {
          type = "gpt";
          partitions.ESP = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          partitions.luks = {
            size = "100%";
            content = {
              type = "luks";
              name = "decrypted";
              askPassword = true;
              settings = {
                allowDiscards = true;
              };
              content = {
                type = "lvm_pv";
                vg = "zion";
              };
            };
          };
        };

    };
    lvm_vg.zion = {
        type = "lvm_vg";
        lvs.os = {
          size = "250G";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/p-os";
            mountOptions = [ "defaults" ];
          };
        };
        lvs.home = {
          size = "50G";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/p-home";
            mountOptions = [ "user" "exec" "suid" "dev" ];
          };
        };
    };
    nodev."/" = {
      fsType = "tmpfs";
      mountOptions = [
        "size=4G"
        "defaults"
        "mode=755"
      ];
    };
  };


  fileSystems = {
    "/p-home" = {
      neededForBoot = true;
    };
    "/p-os" = {
      neededForBoot = true;
    };
    "/nix" = {
      device = "/p-os/nix";
      fsType = "none";
      options = [ "bind" ];
      depends = [ "/p-os" ];
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
