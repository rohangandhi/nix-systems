{ config, lib, ... }:
let
  cfg = config.my-theme;
  palettes = {
    midnight-jade = import ./palettes/midnight-jade.nix;
    nord = import ./palettes/nord.nix;
  };
  selected = if cfg.enabled then palettes.${cfg.palette} else null;
  colorNames = [
    "background" "surface" "selection" "foreground" "muted" "accent"
    "black" "red" "green" "yellow" "blue" "magenta" "cyan" "white"
    "brightBlack" "brightWhite"
  ];
in {
  options.my-theme = {
    palette = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum (builtins.attrNames palettes));
      default = null;
      description = "Shared application palette, or null for native application colors.";
    };
    enabled = lib.mkOption {
      type = lib.types.bool;
      readOnly = true;
      internal = true;
      default = cfg.palette != null;
    };
    name = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      internal = true;
      default = if cfg.enabled then selected.name else "System default";
    };
    gnomeAccent = lib.mkOption {
      type = lib.types.enum [ "blue" "teal" "green" "yellow" "orange" "red" "pink" "purple" "slate" ];
      readOnly = true;
      internal = true;
      default = if cfg.enabled then selected.gnomeAccent else "blue";
    };
    colors = lib.mkOption {
      type = lib.types.nullOr (lib.types.submodule {
        options = lib.genAttrs colorNames (_: lib.mkOption {
          type = lib.types.strMatching "[0-9a-fA-F]{6}";
        });
      });
      readOnly = true;
      internal = true;
      default = if cfg.enabled then selected.colors else null;
    };
  };
}
