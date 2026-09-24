{ ... }: {
  imports = [
    ./system.nix
    ./os/proxy.nix
    ../common/desktop/gnome.nix
    # Browser
    ../common/apps/browser/firefox.nix
    ../common/apps/browser/chromium.nix
    # Terminal
    ../common/apps/terminal/fastfetch.nix
    ../common/apps/terminal/alacritty.nix
    ../common/apps/terminal/tmux.nix
    ../common/apps/terminal/fish.nix
    ../common/apps/terminal/starship.nix
    ../common/apps/terminal/commands.nix
    # ../common/apps/terminal/yazi.nix
    # Development
    ../common/apps/development/codium.nix
    ../common/apps/development/codex.nix
    # ../common/apps/development/vscode.nix
    # ../common/apps/development/cursor.nix
    # ../common/apps/development/antigravity.nix
    ../common/apps/development/kiro.nix
    ../common/apps/development/zed.nix
    #../common/apps/development/emacs.nix
    # VM runners
    ../matrix/systems.nix
    # Misc
    ../common/apps/container.nix
    # ../common/apps/virt.nix
    ../common/apps/git.nix
    # ../common/apps/slack.nix
    # ../common/apps/zoom.nix
    # ../common/apps/mpv.nix
    # ../common/apps/ticktick.nix
    ../common/apps/app-image.nix
    # ../common/apps/distrobox.nix
    ../common/apps/qalculate.nix
  ];
}
