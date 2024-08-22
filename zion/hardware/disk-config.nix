{
  disko.devices = {
    nodev."/" = {
      fsType = "tmpfs";
      mountOptions = [
        "size=4G"
        "defaults"
        "mode=755"
      ];
    };
    nodev."/home/ephemeral" = {
      fsType = "tmpfs";
      mountOptions = [
        "size=4G"
        "mode=1777"
      ];
    };
    disk = {
      main = {
        device = "/dev/disk/by-id/nvme-Samsung_SSD_990_EVO_1TB_S7M3NS0X118132L_1";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            luks = {
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
      };
    };
    lvm_vg = {
      zion = {
        type = "lvm_vg";
        lvs = {
          os = {
            size = "250G";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/p-os";
              mountOptions = [ "defaults" ];
            };
          };
          home = {
            size = "50G";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/p-home";
              mountOptions = [ "user" "exec" "suid" "dev" ];
            };
          };
        };
      };
    };
#    nodev."/nix" = {
#      fsType = "none";
#      device = "/p-os/nix";
#      mountOptions = [ "bind" ];
#    };
  };
}
