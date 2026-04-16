{
  description = "Secure Jailed-Pi environment configured for local LM Studio with injected tools";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    jailed-agents.url = "github:andersonjoseph/jailed-agents";
  };

  outputs = { self, nixpkgs, jailed-agents }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          # 1. Build a custom jailed agent that mounts NPM INSIDE the sandbox
          customJailedPi = jailed-agents.lib.${system}.makeJailedPi {
            extraPkgs = [ pkgs.nodejs ];
          };

          # Define the model configuration as a Nix attribute set
          modelsConfig = {
            providers = {
              lm-studio = {
                baseUrl = "http://127.0.0.1:1234/v1";
                api = "openai-completions";
                apiKey = "lm-studio";
                models = [
                  {
                    id = "local-model";
                    name = "LM Studio Model";
                  }
                ];
              };
            };
          };

          modelsJson = builtins.toJSON modelsConfig;

        in
        {
          default = pkgs.mkShell {
            # 2. Use our custom agent instead of the default one
            packages = [
              customJailedPi
              # (Optional) Keep these here if you also want them available on your host terminal
              pkgs.nodejs 
            ];

            shellHook = ''
              export OPENAI_API_BASE="http://127.0.0.1:1234/v1"
              export OPENAI_BASE_URL="http://127.0.0.1:1234/v1"
              export OPENAI_API_KEY="lm-studio"
              
              mkdir -p .pi/agent
              echo '${modelsJson}' > ~/.pi/agent/models.json
              
              echo "====================================================="
              echo " 🤖 Custom Jailed-Pi Sandbox is active!"
              echo " 🔌 LM Studio Endpoint: $OPENAI_BASE_URL"
              echo " 📦 Sandboxed tools: nodejs, bun"
              echo " 🛡️  Run 'jailed-pi' to start the agent."
              echo "====================================================="
            '';
          };
        }
      );
    };
}