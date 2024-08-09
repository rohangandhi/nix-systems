{ lib, my-options, ... }: {
  config = {
    my-options = my-options;
    home-manager.extraSpecialArgs = { my-options = my-options; };
  };

  options = {
    my-options = {
      name = lib.mkOption { type = lib.types.str; };
      display = {
        scaling = lib.mkOption { type = lib.types.str; };
      };
      user = {
        name = lib.mkOption { type = lib.types.str; };
        uid = lib.mkOption { type = lib.types.int; };
      };
      group = {
        name = lib.mkOption { type = lib.types.str; };
        gid = lib.mkOption { type = lib.types.int; };
      };
    };
  };
}
