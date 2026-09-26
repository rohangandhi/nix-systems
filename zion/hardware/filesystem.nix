{ config, lib, pkgs, my-options, ... }:
let
  # Run before activation on boot, while no user processes or home bind mounts
  # exist. Keep the old path as a link so older generations use the same data.
  migrateHome = pkgs.writeShellScript "migrate-persistent-home" ''
    set -euo pipefail
    export PATH=${lib.makeBinPath [ pkgs.coreutils ]}
    persistent_root="$1"
    old_home="$persistent_root/${my-options.user.name}"
    new_home="$persistent_root/home/${my-options.user.name}"

    if [[ -L "$persistent_root/home" ]]; then
      echo "Refusing migration: $persistent_root/home is a symbolic link." >&2
      exit 1
    fi
    if [[ -L "$old_home" ]]; then
      if [[ "$(readlink "$old_home")" != "home/${my-options.user.name}" || ! -d "$new_home" || -L "$new_home" ]]; then
        echo "Refusing migration: unexpected legacy home link at $old_home." >&2
        exit 1
      fi
    elif [[ -e "$old_home" ]]; then
      if [[ ! -d "$old_home" || -e "$new_home" || -L "$new_home" ]]; then
        echo "Refusing to merge or overwrite persistent homes: $old_home and $new_home." >&2
        exit 1
      fi
      install -d -m 0755 "$persistent_root/home"
      mv -T -- "$old_home" "$new_home"
      ln -s -- "home/${my-options.user.name}" "$old_home"
    elif [[ -d "$new_home" && ! -L "$new_home" ]]; then
      # Also recover an interrupted migration between the rename and symlink.
      ln -s -- "home/${my-options.user.name}" "$old_home"
    elif [[ -e "$new_home" || -L "$new_home" ]]; then
      echo "Refusing migration: $new_home is not a regular directory." >&2
      exit 1
    fi
  '';
  installRoot = config.disko.rootMountPoint;
in {

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
              chown "${toString my-options.user.uid}:${toString my-options.group.gid}" ${lib.escapeShellArg "${installRoot}/p-data"}
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
            # The persistent filesystem is mounted now; put the target store
            # on it before nixos-install writes anything into the tmpfs root.
            mkdir -p ${lib.escapeShellArg "${installRoot}/nix"} ${lib.escapeShellArg "${installRoot}/p-os/nix"}
            if ! findmnt --mountpoint ${lib.escapeShellArg "${installRoot}/nix"} >/dev/null; then
              mount --bind ${lib.escapeShellArg "${installRoot}/p-os/nix"} ${lib.escapeShellArg "${installRoot}/nix"}
            fi
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
        uid = "${toString my-options.user.uid}";
        gid = "${toString my-options.group.gid}";
      in
      {
        device = "none";
        fsType = "tmpfs";
        options = [ "size=8G" "mode=1755" "uid=${uid}" "gid=${gid}" ];
        neededForBoot = true;
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
        uid = "${toString my-options.user.uid}";
        gid = "${toString my-options.group.gid}";
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

  # A browsing hub only: these links do not add filesystems or duplicate data.
  systemd.tmpfiles.rules = [
    "d /persist 0755 root root -"
    "L /persist/os - - - - /p-os"
    "L /persist/home - - - - /p-home"
    "L /persist/data - - - - /p-data"
  ];

  boot.initrd.systemd.storePaths = [
    migrateHome
    "${pkgs.util-linux}/bin/mountpoint"
  ];
  boot.initrd.systemd.services.migrate-persistent-home = {
    description = "Migrate the legacy persistent home layout";
    requiredBy = [ "initrd-nixos-activation.service" ];
    before = [ "initrd-nixos-activation.service" ];
    unitConfig = {
      DefaultDependencies = false;
      RequiresMountsFor = [ "/sysroot/p-home" ];
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStartPre = "${pkgs.util-linux}/bin/mountpoint -q /sysroot/p-home";
      ExecStart = "${migrateHome} /sysroot/p-home";
    };
  };

  # A live switch cannot replace the old per-user bindfs mounts safely. Boot
  # the new generation instead; its initrd migrates before persistence starts.
  system.activationScripts.createPersistentStorageDirs.text = lib.mkBefore ''
    if [ -d /p-home/${my-options.user.name} ] && [ ! -L /p-home/${my-options.user.name} ]; then
      echo "Home persistence needs migration. Use nixos-rebuild boot and reboot, not switch." >&2
      exit 1
    fi
  '';


  environment.persistence."/p-os" = {
    hideMounts = true;
    directories = [
      # "/var/tmp"
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
  # --exclude "{.local/share,.mozilla,.config/VSCodium,.lmstudio,.cache}"

  home-manager.users.${my-options.user.name} = { lib, my-options, ... }: {
    # Fish needs an existing target for its atomic universal-variable writes.
    # Preserve any current settings before Home Manager replaces the local file.
    home.activation.persistFishVariables = lib.hm.dag.entryBetween
      [ "linkGeneration" ] [ "writeBoundary" ] ''
        fish_state_path="/p-home/home/${my-options.user.name}/.config/fish/fish_variables"
        if [[ ! -e "$fish_state_path" ]]; then
          if [[ -f "$HOME/.config/fish/fish_variables" ]]; then
            run ${pkgs.coreutils}/bin/install -D -m 600 "$HOME/.config/fish/fish_variables" "$fish_state_path"
          else
            run ${pkgs.coreutils}/bin/install -D -m 600 /dev/null "$fish_state_path"
          fi
        fi
      '';

    home.persistence."/p-home" = {
      directories = [
        # ".cache" # find a better way to allocate storage for this (frequently used by apps running into limites of storage on RAM disk)
        ".cache/uv"
        ".cache/nix-index"
        ".local/share/fish"
        ".mozilla"
        ".ssh"

        # Online Accounts needs both account definitions and keyring credentials.
        ".config/goa-1.0"
        ".local/share/keyrings"

        ".codex"

        ".lmstudio"
        ".config/LM Studio"

        # VSCodium: extensions/launcher, workspace trust, and writable profile.
        # Persist all three; settings alone do not include trust decisions.
        ".vscode-oss"
        ".vscode-oss-shared"
        ".config/VSCodium"
      ];
      # Fish atomically replaces this file; a bind-mounted file cannot be renamed.
      files = [{ file = ".config/fish/fish_variables"; method = "symlink"; }];
    };
  };
}
