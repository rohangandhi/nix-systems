{ config, ... }: {

  home-manager.users.${config.my-options.user.name} = { pkgs, ... }: {
    programs.fastfetch.enable = true;
    programs.fastfetch.package = pkgs.fastfetch;
    programs.fastfetch.settings = {
      logo = {
        padding = {
          right = 1;
        };
      };
      display = {
        separator = "";
        percent = {
          type = "3";
        };
      };
      modules = [
        {
          type = "custom";
          format = "┌───";
          outputColor = "32";
        }
        {
          type = "os";
          key = "├ ⏻   OS: ";
          format = "{3}";
          keyColor = "32";
          outputColor = "32";
        }
        {
          type = "kernel";
          key = "├    Kernel: ";
          format = "{1}  {2}";
          keyColor = "32";
          outputColor = "32";
        }
        {
          type = "packages";
          key = "├ 󰏖   Packages: ";
          keyColor = "32";
          outputColor = "32";
        }
        {
          type = "terminal";
          key = "├    Terminal: ";
          format = "{5}  {6}";
          keyColor = "32";
          outputColor = "32";
        }
        {
          type = "shell";
          key = "├    Shell: ";
          format = "{3}  {4}";
          keyColor = "32";
          outputColor = "32";
        }
        {
          type = "custom";
          format = "└───";
          outputColor = "32";
        }
        "break"
        {
          type = "custom";
          format = "┌───";
          outputColor = "33";
        }
        {
          type = "cpu";
          key = "├    CPU: ";
          format = "{1}  Cores: {3}  Threads: {5}/{4}  {6} - {7} GHZ";
          keyColor = "33";
          outputColor = "33";
        }
        {
          type = "memory";
          key = "├    Memory: ";
          format = "{1}  {2}";
          keyColor = "33";
          outputColor = "33";
        }
        {
          type = "custom";
          format = "└───";
          outputColor = "33";
        }
        "break"
        {
          type = "custom";
          format = "┌───";
          outputColor = "34";
        }
        {
          type = "display";
          key = "├    Display: ";
          format = "{1}x{2} @ {3}Hz  primary = {9}";
          keyColor = "34";
          outputColor = "34";
        }
        {
          type = "gpu";
          key = "├ 󰢮   GPU: ";
          format = "{6} {2}  {12} GHz  Driver: {3}";
          keyColor = "34";
          outputColor = "34";
        }
        {
          type = "custom";
          format = "└───";
          outputColor = "34";
        }
        "break"
        {
          type = "custom";
          format = "┌───";
          outputColor = "35";
        }
        {
          type = "disk";
          key = "├ 󰋊   Disk: ";
          format = "{10} {9}  {1}  {2}";
          keyColor = "35";
          outputColor = "35";
        }
        {
          type = "custom";
          format = "└───";
          outputColor = "35";
        }
        "break"
      ];
    };
  };
}
