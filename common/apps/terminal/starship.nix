{ config, lib, my-options, ... }:
let
  theme = config.my-theme;
  palette = theme.colors;
in {

  home-manager.users.${my-options.user.name} = { ... }: {
    programs.starship.enable = true;
    programs.starship.enableTransience = true;
    programs.starship.settings = {
      format = "$username$hostname$directory$git_branch$git_state$git_status$nix_shell$status$character";
      right_format = "$cmd_duration";
      add_newline = true;
      palette = lib.mkIf theme.enabled "shared";
      palettes.shared = lib.mkIf theme.enabled (builtins.mapAttrs (_: hex: "#${hex}") palette);

      directory = {
        format = "[$path]($style)[$read_only]($read_only_style) ";
        style = lib.mkIf theme.enabled "bold accent";
        truncation_length = 3;
        truncation_symbol = "…/";
        read_only = " [read only]";
        read_only_style = lib.mkIf theme.enabled "red";
      };
      git_branch = {
        symbol = " ";
        format = "[ $symbol$branch ]($style)";
        style = lib.mkIf theme.enabled "fg:cyan bg:surface";
      };
      git_status = {
        format = "([ $all_status$ahead_behind]($style)) ";
        style = lib.mkIf theme.enabled "yellow";
      };
      git_state = {
        format = "[ $state( $progress_current/$progress_total)]($style)";
        style = lib.mkIf theme.enabled "bold red";
      };
      nix_shell = {
        format = "[ nix:$state ]($style) ";
        style = lib.mkIf theme.enabled "fg:blue bg:surface";
        impure_msg = "dev";
        pure_msg = "pure";
      };

      # Show identity over SSH or as root, and the exit code after failures.
      hostname = {
        ssh_only = true;
        format = "[@$hostname]($style) ";
        style = lib.mkIf theme.enabled "bold cyan";
      };
      username = {
        show_always = false;
        format = "[$user]($style) ";
        style_user = lib.mkIf theme.enabled "cyan";
        style_root = lib.mkIf theme.enabled "bold red";
      };
      status = {
        disabled = false;
        format = "[✕ $status]($style) ";
        style = lib.mkIf theme.enabled "bold red";
      };
      character = {
        success_symbol = lib.mkIf theme.enabled "[❯](bold accent)";
        error_symbol = lib.mkIf theme.enabled "[❯](bold red)";
        vimcmd_symbol = lib.mkIf theme.enabled "[❮](bold cyan)";
      };
      cmd_duration = {
        min_time = 2000;
        format = "[$duration]($style)";
        style = lib.mkIf theme.enabled "muted";
      };
    };
  };
}
