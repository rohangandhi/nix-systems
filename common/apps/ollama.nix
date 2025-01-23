{ pkgs,  ... }: {
  environment.systemPackages = [
    pkgs.ollama-rocm
  ];
}
