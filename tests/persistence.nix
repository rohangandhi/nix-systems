{ inputs }:
let
  networkShare = inputs.self.nixosConfigurations.zion-alpha.config.fileSystems."/home/ephemeral/n-data";
  wallpaper = "wallpapers/lightning-abstract-2560x1440-v0-no9zyx3wnnwf1.webp";
in
inputs.nixpkgs.legacyPackages.x86_64-linux.testers.runNixOSTest {
  name = "persistence-layout";
  # This also runs on machines without /dev/kvm, using QEMU emulation.
  requiredFeatures.kvm = false;
  globalTimeout = 600;

  node.specialArgs = {
    inherit inputs;
    my-options = {
      name = "persistence-test";
      display.scaling = "1";
      user = { name = "ephemeral"; uid = 1000; };
      group = { name = "devs"; gid = 999; };
    };
  };

  nodes.machine = { lib, pkgs, ... }: {
    imports = [
      ../zion/options.nix
      ../common/input-modules/disko.nix
      ../common/input-modules/impermanence.nix
      ../common/input-modules/home-manager.nix
      ../zion/hardware/filesystem.nix
    ];
    system.stateVersion = "24.05";
    boot.initrd.systemd.enable = true;
    users.groups.devs.gid = 999;
    users.users.ephemeral = {
      isNormalUser = true;
      uid = 1000;
      group = "devs";
    };
    home-manager.users.ephemeral.home.stateVersion = "24.11";

    # Use only disposable VM filesystems; the host's Disko devices are never run.
    virtualisation = {
      memorySize = 1536;
      fileSystems = {
        "/" = lib.mkForce { device = "none"; fsType = "tmpfs"; };
        "/p-home" = { device = "/dev/vda"; fsType = "ext4"; neededForBoot = true; };
        "/p-os" = { device = "none"; fsType = "tmpfs"; neededForBoot = true; };
        "/p-data" = { device = "none"; fsType = "tmpfs"; };
        "/home/ephemeral" = {
          device = "none";
          fsType = "tmpfs";
          options = [ "uid=1000" "gid=999" ];
          neededForBoot = true;
        };
        "/home/ephemeral/n-data" = {
          inherit (networkShare) fsType options;
          device = "//server/zion";
        };
      };
    };

    # Seed an old-layout home on the first boot, before the real migration unit.
    boot.initrd.systemd.services.seed-legacy-home = {
      requiredBy = [ "migrate-persistent-home.service" ];
      before = [ "migrate-persistent-home.service" ];
      unitConfig = {
        DefaultDependencies = false;
        RequiresMountsFor = [ "/sysroot/p-home" ];
      };
      serviceConfig.Type = "oneshot";
      script = ''
        export PATH=${lib.makeBinPath [ pkgs.coreutils ]}
        if [ ! -e /sysroot/p-home/test-seeded ]; then
          mkdir -p /sysroot/p-home/ephemeral/.mozilla /sysroot/p-home/ephemeral/.config/fish
          echo retained-profile > /sysroot/p-home/ephemeral/.mozilla/probe
          echo retained-fish > /sysroot/p-home/ephemeral/.config/fish/fish_variables
          chmod 700 /sysroot/p-home/ephemeral/.mozilla
          chown -R 1000:999 /sysroot/p-home/ephemeral
          touch /sysroot/p-home/test-seeded
        fi
      '';
    };
  };

  nodes.server = { ... }: {
    system.stateVersion = "24.05";
    services.samba = {
      enable = true;
      openFirewall = true;
      settings = {
        global."map to guest" = "Bad User";
        zion = {
          path = "/srv/zion";
          "read only" = true;
          "guest ok" = "yes";
        };
      };
    };
  };

  testScript = { nodes, ... }:
    let
      migration = builtins.head (inputs.nixpkgs.lib.splitString " "
        nodes.machine.boot.initrd.systemd.services.migrate-persistent-home.serviceConfig.ExecStart);
    in ''
      server.start()
      server.wait_for_unit("samba.target")
      server.succeed("mkdir -p /srv/zion/wallpapers; echo fixture-wallpaper > /srv/zion/${wallpaper}")
      machine.start(allow_reboot=True)
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("home-manager-ephemeral.service")
      machine.succeed("grep -qx retained-profile /home/ephemeral/.mozilla/probe")
      machine.succeed("test $(stat -c %a /p-home/home/ephemeral/.mozilla) = 700")
      machine.succeed("test $(stat -c %u:%g /p-home/home/ephemeral/.mozilla) = 1000:999")
      machine.succeed("test $(readlink /p-home/ephemeral) = home/ephemeral")
      machine.succeed("test $(readlink /persist/os) = /p-os")
      machine.succeed("test $(readlink /persist/home) = /p-home")
      machine.succeed("test $(readlink /persist/data) = /p-data")
      machine.succeed("grep -qx retained-profile /persist/home/home/ephemeral/.mozilla/probe")
      machine.succeed("test $(readlink /home/ephemeral/.config/fish/fish_variables) = /p-home/home/ephemeral/.config/fish/fish_variables")
      machine.succeed("runuser -u ephemeral -- grep -qx fixture-wallpaper /home/ephemeral/n-data/${wallpaper}")
      machine.succeed("findmnt --mountpoint /home/ephemeral/n-data --types cifs")

      # A changed profile reaches the backing store and the legacy rollback path.
      machine.succeed("runuser -u ephemeral -- sh -c 'echo changed-profile > /home/ephemeral/.mozilla/probe; echo temporary > /home/ephemeral/disposable'")
      machine.succeed("grep -qx changed-profile /p-home/ephemeral/.mozilla/probe")
      machine.reboot()
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("home-manager-ephemeral.service")
      machine.succeed("grep -qx changed-profile /home/ephemeral/.mozilla/probe")
      machine.succeed("grep -qx retained-fish /home/ephemeral/.config/fish/fish_variables")
      machine.fail("test -e /home/ephemeral/disposable")
      machine.succeed("test $(readlink /persist/home) = /p-home")
      machine.succeed("runuser -u ephemeral -- grep -qx fixture-wallpaper /home/ephemeral/n-data/${wallpaper}")
      machine.succeed("findmnt --mountpoint /home/ephemeral/n-data --types cifs")

      # Fresh installs, interrupted migrations, and conflicting destinations.
      machine.succeed("mkdir -p /tmp/fresh; ${migration} /tmp/fresh; test ! -e /tmp/fresh/ephemeral")
      machine.succeed("mkdir -p /tmp/interrupted/home/ephemeral; ${migration} /tmp/interrupted; test -L /tmp/interrupted/ephemeral")
      machine.succeed("mkdir -p /tmp/conflict/ephemeral /tmp/conflict/home/ephemeral; echo old > /tmp/conflict/ephemeral/probe; echo new > /tmp/conflict/home/ephemeral/probe")
      machine.fail("${migration} /tmp/conflict")
      machine.succeed("grep -qx old /tmp/conflict/ephemeral/probe; grep -qx new /tmp/conflict/home/ephemeral/probe")
    '';
}
