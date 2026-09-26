{ ... }: {
  # Steam manages Valve's Proton versions and per-game compatibility settings.
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = false;
    dedicatedServer.openFirewall = false;
    localNetworkGameTransfers.openFirewall = false;
  };
}
