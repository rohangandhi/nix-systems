{
  inputs.public.url = "github:rohangandhi/nix-systems";
  inputs.nixpkgs.follows = "public/nixpkgs";

  outputs = { public, nixpkgs, ... }: {
    nixosConfigurations.workstation = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        inherit public;
        inputs = public.inputs;
        my-options = {
          name = "workstation";
          display.scaling = "1";
          user = { name = "owner"; uid = 1000; };
          group = { name = "users"; gid = 100; };
        };
      };
      modules = [ ./zion/system.nix ];
    };
  };
}
