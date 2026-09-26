{ inputs }:
let
  host = inputs.self.nixosConfigurations.zion-alpha.config;
in
inputs.nixpkgs.legacyPackages.x86_64-linux.testers.runNixOSTest {
  name = "keyring-autologin";
  requiredFeatures.kvm = false;
  globalTimeout = 180;

  nodes.machine = { pkgs, ... }: {
    system.stateVersion = "24.05";
    virtualisation.memorySize = 1024;
    users.users.alice = {
      isNormalUser = true;
      uid = 1000;
      linger = true;
    };
    services.dbus.enable = true;
    services.gnome.gnome-keyring.enable = true;
    environment.systemPackages = with pkgs; [ gnome-keyring keyutils libsecret pamtester ];

    # Exercise the workstation's generated PAM stack without a graphical session.
    security.pam.services.gdm-autologin.text = host.security.pam.services.gdm-autologin.text;
    systemd.services.keyring-login = {
      serviceConfig = {
        Type = "oneshot";
        KeyringMode = host.systemd.services.display-manager.serviceConfig.KeyringMode;
        ExecStart = "${pkgs.pamtester}/bin/pamtester gdm-autologin alice authenticate open_session";
      };
    };
  };

  testScript = ''
    import shlex

    def user(command):
        return machine.succeed(
            "runuser -u alice -- env XDG_RUNTIME_DIR=/run/user/1000 "
            "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus "
            "sh -c " + shlex.quote(command)
        )

    def locked():
        return user(
            "busctl --user get-property org.freedesktop.secrets "
            "/org/freedesktop/secrets/collection/login org.freedesktop.Secret.Collection Locked"
        ).strip() == "b true"

    def lock():
        user(
            "busctl --user call org.freedesktop.secrets /org/freedesktop/secrets "
            "org.freedesktop.Secret.Service Lock ao 1 /org/freedesktop/secrets/collection/login"
        )
        assert locked()

    def login():
        machine.succeed("systemctl start keyring-login.service")

    machine.start()
    machine.wait_for_unit("user@1000.service")
    machine.wait_for_file("/run/user/1000/bus")

    # All credentials here are disposable test fixtures, never host credentials.
    user("printf fixture-password | gnome-keyring-daemon --unlock --components=secrets")
    user("printf fixture-secret | secret-tool store --label=fixture purpose autologin-test")
    lock()

    with subtest("Missing cache preserves automatic login with a locked keyring"):
        login()
        assert locked()

    with subtest("Wrong cached password does not unlock the keyring"):
        machine.succeed("printf wrong-password | keyctl padd user cryptsetup @u")
        login()
        assert locked()

    with subtest("Reuse the disk password without a trailing NUL byte"):
        # This is systemd-cryptsetup's kernel cache format, which pam_gdm 50.2 rejects.
        machine.succeed("printf fixture-password | keyctl padd user cryptsetup @u")
        login()
        assert not locked()
        assert user("secret-tool lookup purpose autologin-test").strip() == "fixture-secret"

    with subtest("Use the last cached password after a failed disk-unlock attempt"):
        lock()
        machine.succeed("printf 'wrong-password\\0fixture-password' | keyctl padd user cryptsetup @u")
        login()
        assert not locked()
  '';
}
