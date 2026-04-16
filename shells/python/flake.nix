{
  description = "Python 3.12 + uv (many ML wheels, e.g. vLLM ROCm, only publish cp312)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            python312
            python312Packages.pip
            uv
          ];

          shellHook = ''
            # Create a virtual environment if it doesn't exist (must match wheel ABI, e.g. cp312 for vLLM ROCm)
            if [ ! -d "venv" ]; then
              echo "Creating Python 3.12 virtual environment..."
              python3 -m venv venv
            fi

            # Activate the virtual environment
            source venv/bin/activate

            # Set up uv to use the virtual environment
            export VIRTUAL_ENV=$PWD/venv
            export PATH="$VIRTUAL_ENV/bin:$PATH"

            echo "Python dev environment activated (3.12). If you switched Python versions, remove ./venv and re-enter the shell."
          '';
        };
      }
    );
}