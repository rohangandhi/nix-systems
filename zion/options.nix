{ lib, my-options, ... }: {
  config = {
    my-options = my-options;
    home-manager.extraSpecialArgs = { my-options = my-options; };
  };

  options = {
    my-machine = {
      nasAddress = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "NAS address for the resource menu.";
      };
      routerAddress = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Router address for the resource menu.";
      };
      networkShare = lib.mkOption {
        type = lib.types.str;
        default = "//nas.example.invalid/share";
        description = "SMB source; override in the private host configuration.";
      };
      sharedDiskUuid = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Existing shared NTFS filesystem UUID; null disables the mount.";
      };
      hiddenDiskUuids = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Filesystem UUIDs to hide from Files.";
      };
    };
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
