{ pkgs, my-options, ... }: {

  disko.devices = {
    disk.main = {
      #ls -l /dev/disk/by-id/
      #lsblk -d -r|awk 'NR==1{print $0" DEVICE-ID(S)"}NR>1{dev=$1;printf $0" ";system("find /dev/disk/by-id -lname \"*"dev"\" -printf \" %p\"");print "";}'
      device = "/dev/disk/by-id/nvme-Samsung_SSD_990_EVO_1TB_S7M3NS0X118132L_1"; # basement
      #device = "/dev/disk/by-id/nvme-Samsung_SSD_990_EVO_1TB_S7M3NS0X118118W_1"; # living
      type = "disk";

      content = {
        type = "gpt";
        partitions.ESP = {
          name = "ESP";
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        partitions.system = {
          name = "system";
          size = "300G";
          content = {
            type = "luks";
            name = "decrypted";
            askPassword = true;
            settings = {
              allowDiscards = true;
            };
            postMountHook = ''
              # Prepare for installation. Execute on installer/live OS:
              sudo mkdir -p /mnt/nix
              sudo mkdir -p /mnt/p-os/nix
              sudo mount --bind /mnt/p-os/nix /mnt/nix

              # Home directory does not get created since root is mounted on tempfs. So manually creating home.
              sudo mkdir -p /mnt/p-home/ephemeral
              sudo mkdir -p /mnt/home/ephemeral
              sudo chown "${toString my-options.user.uid}:${toString my-options.group.gid}" /mnt/p-home/ephemeral
              sudo mount --bind /mnt/p-home/ephemeral /mnt/home/ephemeral
            '';
            content = {
              type = "lvm_pv";
              vg = "zion";
            };
          };
        };
        partitions.data = {
          name = "data";
          size = "500G";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/p-data";
            postMountHook = ''
              sudo chown "${toString my-options.user.uid}:${toString my-options.group.gid}" /mnt/p-data
            '';
          };
        };
      };
    };
    lvm_vg.zion = {
      type = "lvm_vg";
      lvs.os = {
        size = "199G";
        content = {
          type = "filesystem";
          format = "ext4";
          mountpoint = "/p-os";
          mountOptions = [ "defaults" ]; #Use the default options: rw, suid, dev, exec, auto, nouser, and async.
          postMountHook = ''
            # Prepare for installation. Execute on installer/live OS:
            sudo mkdir -p /mnt/nix
            sudo mkdir -p /mnt/p-os/nix
            sudo mount --bind /mnt/p-os/nix /mnt/nix
          '';
        };
      };
      lvs.home = {
        size = "100G";
        content = {
          type = "filesystem";
          format = "ext4";
          mountpoint = "/p-home";
          mountOptions = [ "suid" "dev" "exec" "user" ];
          postMountHook = ''
            # Prepare for installation. Execute on installer/live OS:
            # Home directory does not get created since root is mounted on tempfs. So manually creating home.
            sudo mkdir -p /mnt/p-home/ephemeral
            sudo mkdir -p /mnt/home/ephemeral
            sudo chown "${toString my-options.user.uid}:${toString my-options.group.gid}" /mnt/p-home/ephemeral
            sudo mount --bind /mnt/p-home/ephemeral /mnt/home/ephemeral
          '';
        };
      };
    };
    nodev."/" = {
      fsType = "tmpfs";
      mountOptions = [
        "size=8G"
        "defaults"
        "mode=755"
      ];
    };
  };


  fileSystems = {
    # OS Setup
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

    # Home Setup
    "/p-home" = {
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
        options = [ "size=8G" "mode=1755" "uid=${uid}" "gid=${gid}" ];
      };

    # Data Setup
    "/p-data" = {
      neededForBoot = false;
    };

    # Data - Local
    "/home/${my-options.user.name}/p-data" = {
      device = "/p-data";
      fsType = "none";
      options = [ "bind" ];
      depends = [ "/p-data" ];
    };

    # Data - Network
    "/home/${my-options.user.name}/n-data" =
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

  # sudo fd \
  # --one-file-system --base-directory /home/ephemeral \
  # --changed-after 1h \
  # --type f --hidden \
  # --exclude "{.local/share,.mozilla,.cursor,.config/VSCodium,silly,.lmstudio,.cache}"

  home-manager.users.${my-options.user.name} = { my-options, ... }: {
    home.persistence."/p-home/${my-options.user.name}" = {
      directories = [
        ".cache/nix-index"
        ".local/share/fish"
        ".local/share/containers" # also see container.nix
        ".config/Code"
        ".config/VSCodium"
        ".config/LM Studio"
        ".config/Cursor"
        ".config/zed"
        ".config/Antigravity"
        ".antigravity"
        ".gemini"
        ".lmstudio"
        ".cursor"
        ".mozilla"
        ".ssh"
        ".vscode"
      ];
      files = [ ];
    };
  };
}
