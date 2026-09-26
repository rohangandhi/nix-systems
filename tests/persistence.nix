{ inputs }:
let
  hostFileSystems = inputs.self.nixosConfigurations.zion-alpha.config.fileSystems;
  networkShare = hostFileSystems."/home/ephemeral/n-data";
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
    environment.systemPackages = [ pkgs.fish ];

    # Use only disposable VM filesystems; the host's Disko devices are never run.
    virtualisation = {
      memorySize = 1536;
      fileSystems = {
        "/" = lib.mkForce { device = "none"; fsType = "tmpfs"; };
        "/p-home" = {
          device = "/dev/vda";
          fsType = "ext4";
          neededForBoot = true;
          # Exercise the workstation's real flags, including exec/nosuid/nodev.
          inherit (hostFileSystems."/p-home") options;
        };
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

  testScript = ''
      import json

      def check_home_mounts():
          for path in ["/p-home", "/home/ephemeral/.vscode-oss"]:
              mount = json.loads(machine.succeed(f"findmnt --json --mountpoint {path} --output OPTIONS"))
              options = set(mount["filesystems"][0]["options"].split(","))
              assert "noexec" not in options, (path, options)
              assert {"nosuid", "nodev"} <= options, (path, options)
          machine.succeed("runuser -u ephemeral -- /home/ephemeral/.vscode-oss/test-bin/true")

      server.start()
      server.wait_for_unit("samba.target")
      server.succeed("mkdir -p /srv/zion/wallpapers; echo fixture-wallpaper > /srv/zion/${wallpaper}")
      machine.start(allow_reboot=True)
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("home-manager-ephemeral.service")
      # Start with an empty persistent disk, as on a fresh installation.
      machine.succeed("test -d /p-home/home/ephemeral/.mozilla; test ! -e /p-home/ephemeral")
      machine.succeed("test $(stat -c %u:%g /p-home/home/ephemeral/.mozilla) = 1000:999")
      machine.succeed("test $(readlink /persist/os) = /p-os")
      machine.succeed("test $(readlink /persist/home) = /p-home")
      machine.succeed("test $(readlink /persist/data) = /p-data")
      machine.succeed("test $(readlink /home/ephemeral/.config/fish/fish_variables) = /p-home/home/ephemeral/.config/fish/fish_variables")
      machine.succeed("test -f /p-home/home/ephemeral/.config/fish/fish_variables")
      machine.succeed("runuser -u ephemeral -- grep -qx fixture-wallpaper /home/ephemeral/n-data/${wallpaper}")
      machine.succeed("findmnt --mountpoint /home/ephemeral/n-data --types cifs")

      # Ordinary user writes, private file modes and executable extension tools.
      machine.succeed("runuser -u ephemeral -- sh -c 'umask 077; echo changed-profile > /home/ephemeral/.mozilla/probe; echo temporary > /home/ephemeral/disposable'")
      # Preserve the basename: coreutils may dispatch its applets by argv[0].
      machine.succeed("runuser -u ephemeral -- install -Dm755 /run/current-system/sw/bin/true /home/ephemeral/.vscode-oss/test-bin/true")
      machine.succeed("runuser -u ephemeral -- fish -c 'set -U persistence_probe retained-fish'")
      machine.succeed("grep -qx changed-profile /persist/home/home/ephemeral/.mozilla/probe")
      machine.succeed("test $(stat -c %a /p-home/home/ephemeral/.mozilla/probe) = 600")
      check_home_mounts()

      # Reject an unmigrated directory, preserving both it and the current home.
      machine.succeed("mkdir /p-home/ephemeral; echo legacy-profile > /p-home/ephemeral/probe")
      machine.fail("/run/current-system/activate > /tmp/legacy-activation.log 2>&1")
      machine.succeed("grep -F 'Legacy persistent home at /p-home/ephemeral' /tmp/legacy-activation.log")
      machine.succeed("grep -qx legacy-profile /p-home/ephemeral/probe")
      machine.succeed("grep -qx changed-profile /p-home/home/ephemeral/.mozilla/probe")
      machine.succeed("rm /p-home/ephemeral/probe; rmdir /p-home/ephemeral")

      # A compatibility link left by the completed migration survives updates.
      machine.succeed("ln -s home/ephemeral /p-home/ephemeral")
      machine.succeed("/run/current-system/activate")
      machine.succeed("grep -qx changed-profile /p-home/ephemeral/.mozilla/probe")
      machine.reboot()
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("home-manager-ephemeral.service")
      machine.succeed("grep -qx changed-profile /home/ephemeral/.mozilla/probe")
      machine.succeed("runuser -u ephemeral -- fish -c 'test $persistence_probe = retained-fish'")
      machine.succeed("test $(readlink /home/ephemeral/.config/fish/fish_variables) = /p-home/home/ephemeral/.config/fish/fish_variables")
      machine.succeed("test $(stat -c %a /p-home/home/ephemeral/.mozilla/probe) = 600")
      machine.succeed("test $(stat -c %u:%g /p-home/home/ephemeral/.mozilla/probe) = 1000:999")
      machine.succeed("test $(readlink /p-home/ephemeral) = home/ephemeral")
      machine.fail("test -e /home/ephemeral/disposable")
      machine.succeed("test $(readlink /persist/home) = /p-home")
      check_home_mounts()
      machine.succeed("runuser -u ephemeral -- grep -qx fixture-wallpaper /home/ephemeral/n-data/${wallpaper}")
      machine.succeed("findmnt --mountpoint /home/ephemeral/n-data --types cifs")
    '';
}
