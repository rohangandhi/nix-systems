{ pkgs, ... }: {
  programs.appimage.enable = true;
  programs.appimage.binfmt = true;
  programs.appimage.package = pkgs.appimage-run.override {
    # LM Studio bundles ROCm, but its runtime also needs these host libraries.
    # Keep them in the AppImage environment instead of adding a second ROCm stack.
    extraPkgs = pkgs: [ pkgs.elfutils pkgs.zstd ];
  };
}
