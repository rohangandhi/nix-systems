{ lib, pkgs, ... }:
{
  # Guest identity inside the VM. Keeping a dedicated hostname helps prevent
  # confusion when running commands across host and guest terminals.
  networking.hostName = "matrix-one";

  # Route supported client traffic through the forwarded host proxy rather than
  # giving the guest direct routed access to the host or LAN.
  networking.proxy.default = "http://10.0.2.10:3128";

  # Keep user accounts declarative. This avoids agent/user drift in `/etc/passwd`
  # across VM runs and makes behavior reproducible.
  users.mutableUsers = false;

  # Convenience login account for rapid loop iterations.
  # Security tradeoff: no password + wheel is intentionally permissive *inside*
  # this disposable VM, so isolation must come from VM boundaries and reset flow.
  users.users.autologin = {
    isNormalUser = true;
    description = "Auto Login User";
    extraGroups = [ "wheel" ];
    hashedPassword = ""; # Explicitly disable password
  };

  # Auto-login to remove friction when repeatedly booting short-lived agents.
  services.getty.autologinUser = "autologin";

  # Allow passwordless sudo in guest for agent workflows requiring root actions.
  # This should not be used on the host, but is acceptable in a throwaway VM.
  security.sudo.wheelNeedsPassword = false;

  # Enable modern Nix CLI commands expected by current workflows and tooling.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # VM-only runtime settings. These are applied when using `system.build.vm`
  # (run-matrix-one-vm), not to a physical machine install.
  virtualisation.vmVariant = {
    virtualisation = {
      # Mount host `/nix/store` into guest as `/nix/.ro-store`.
      # This lets the VM reuse already-downloaded host dependencies with zero
      # duplication and prevents direct writes to host store paths.
      mountHostNixStore = true;

      # IMPORTANT: enable guest-side Nix installs while preserving host safety.
      # This creates an overlay guest `/nix/store`:
      # - lowerdir: host read-only store (`/nix/.ro-store`)
      # - upperdir/workdir: guest writable layer (`/nix/.rw-store`)
      # Net effect: guest can install/build; host store remains unchanged.
      writableStore = true;

      # Keep overlay writes in tmpfs to maximize isolation and disposability.
      # Guest-installed store paths disappear when VM stops unless intentionally
      # persisted via disk config.
      writableStoreUseTmpfs = true;

      # Do not inherit host CA bundle through shared temp mount. This removes one
      # host->guest sharing path and keeps trust roots guest-local.
      useHostCerts = false;

      # Remove default exchange mounts (`/tmp/shared`, `/tmp/xchg`) so agent code
      # cannot casually read/write host temp directories.
      # We keep only the Nix store share needed for dependency reuse.
      sharedDirectories = lib.mkForce {
        nix-store = {
          source = builtins.storeDir;
          target = "/nix/.ro-store";
          securityModel = "none";
        };
        host-ssh = {
          # The host launcher populates this directory with an ephemeral
          # per-user SSH keypair and an `authorized_keys` file. Keeping the
          # source path runtime-configurable avoids baking host paths or key
          # material into the flake.
          source = ''"''${MATRIX_ONE_SSH_DIR:-$TMPDIR/matrix-one-ssh}"'';
          target = "/mnt/host-ssh";
          securityModel = "none";
        };
      };

      # Keep networking available so guest can fetch dependencies not already in
      # the host store. The guest regains selected outbound access only through
      # explicit forwarding rules like the proxy tunnel below.
      restrictNetwork = true;

      forwardPorts = [
        {
          # Expose guest SSH only on host loopback so the VM can be reached
          # from the host terminal without opening it to the LAN.
          from = "host";
          host.address = "127.0.0.1";
          host.port = 2222;
          guest.port = 22;
        }
        {
          from = "guest";
          guest.address = "10.0.2.10";
          guest.port = 3128;
          host.address = "127.0.0.1";
          host.port = 3128;
        }
      ];
    };
  };

  # Small baseline toolset in the guest for setup and diagnostics.
  environment.systemPackages = [
    pkgs.git
    pkgs.curl
    pkgs.openssh
    pkgs.nodejs_22
    pkgs.bun
    pkgs.tmux
    pkgs.neovim
    pkgs.fish
    pkgs.eza
    pkgs.duf
    pkgs.dust
    pkgs.fd
    pkgs.jq
    pkgs.bat
  ];

  # Keep npm globals user-writable with the standard NixOS npm module config.
  programs.npm.enable = true;

  # Allow host terminals to attach to the guest over a localhost-only
  # forwarded port using a host-managed development key.
  networking.firewall.allowedTCPPorts = [ 22 ];

  services.openssh = {
    enable = true;
    authorizedKeysInHomedir = lib.mkForce false;
    authorizedKeysFiles = lib.mkForce [ "/mnt/host-ssh/authorized_keys" ];
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  environment.sessionVariables = {
    PATH = [
      "$HOME/.npm/bin"
      "$HOME/.bun/bin"
    ];
  };

  # Guest state schema version. Keep fixed after first deployment unless you
  # intentionally migrate related state semantics.
  system.stateVersion = "24.11";
}
