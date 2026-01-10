# Impermanence Home Directory Persistence Issue

## Problem Summary

After upgrading `nix-community/impermanence` to the latest version (post-September 2025), the home directory persistence broke with permission errors:

```
mkdir: cannot create directory '/completions': Permission denied
mkdir: cannot create directory '/conf.d': Permission denied
mkdir: cannot create directory '/functions': Permission denied
warning: An error occurred while redirecting file '/config.fish'
```

### Root Cause

The impermanence module underwent a **breaking API change** in September 2025:

1. **Old behavior**: The persistence path was used as-is
   - Config: `home.persistence."/p-home/ephemeral"`
   - Result: Files stored at `/p-home/ephemeral/.config/Code`

2. **New behavior**: The module automatically appends the user's home directory path
   - Config: `home.persistence."/p-home/ephemeral"`
   - Result: Files expected at `/p-home/ephemeral/home/ephemeral/.config/Code` ❌

This caused bind mounts to look for files in the wrong location, breaking the home directory setup.

### Key Commits (September 20, 2025)

- [`1b02741`](https://github.com/nix-community/impermanence/commit/1b02741e3d154a4bc59af55989ea66528e84b371) - "home-manager: Replace module with an interface to the NixOS module"
- [`2b99fef`](https://github.com/nix-community/impermanence/commit/2b99fefbfdbbc1f9423b7695b04b194064ccb260) - "nixos: Use systemd.mounts instead of fileSystems for bind mounts"

### Auto-Inclusion of Home-Manager Module (January 4, 2026)

As of commit [`f868c97`](https://github.com/nix-community/impermanence/commit/f868c97f9e7f62879a97b4ad0e00b64782a845db) (January 4, 2026), the home-manager impermanence module is **automatically imported** when you import the NixOS persistence module alongside the Home Manager NixOS module. Manual imports are no longer needed and will trigger a deprecation error.

The module now includes an assertion in [`home-manager.nix` (lines 53-60)](https://github.com/nix-community/impermanence/blob/82e5bc4508cab9e8d5a136626276eb5bbce5e9c5/home-manager.nix#L53-L60) that explicitly states:

> "The API has changed - the persistent storage path should no longer contain the path to the user's home directory, as it will be added automatically."

---

## Current Solution: Pin to `home-manager-v1` Branch

The impermanence module explicitly suggests using the `home-manager-v1` branch for users who depend on the old path behavior. This is documented in [`submodule-options.nix` (lines 74-79)](https://github.com/nix-community/impermanence/blob/82e5bc4508cab9e8d5a136626276eb5bbce5e9c5/submodule-options.nix#L74-L79):

> "The use of prefix directories is deprecated and the functionality has been removed. If you depend on this functionality, use the `home-manager-v1` branch."

We pinned impermanence to the [`home-manager-v1` branch](https://github.com/nix-community/impermanence/tree/home-manager-v1) which maintains the old path behavior:

```nix
# flake.nix
impermanence.url = "github:nix-community/impermanence/4b3e914cdf97a5b536a889e939fb2fd2b043a170";
```

This allows keeping the existing configuration and data structure without migration:

```nix
# filesystem.nix
home.persistence."/p-home/${my-options.user.name}" = {
  directories = [ ... ];
  allowOther = true;
};
```

### Required Module Import

The `home-manager-v1` branch requires manually importing the home-manager impermanence module:

```nix
# common/input-modules/home-manager/impermanence.nix
{ inputs, ... }: {
  programs.fuse.userAllowOther = true;
  home-manager.sharedModules = [
    inputs.impermanence.nixosModules.home-manager.impermanence
  ];
}
```

---

## Long-Term Fix: Migrate to New API (Option A)

To use the latest impermanence module (master branch), migrate your data and update the config:

### Step 1: Update flake.nix

```nix
impermanence.url = "github:nix-community/impermanence";  # Use master branch
```

### Step 2: Remove manual home-manager import

Comment out or remove `./common/input-modules/home-manager/impermanence.nix` from `input-modules` - it's now auto-imported.

### Step 3: Change persistence path

> ⚠️ **Warning**: This change can be tricky as other scripts (e.g., disko's `postMountHook` in `filesystem.nix`) may hardcode paths like `/p-home/ephemeral`. Review all references to the persistence path before proceeding.

```nix
# OLD (with home-manager-v1)
home.persistence."/p-home/${my-options.user.name}" = { ... };

# NEW (with master)
home.persistence."/p-home" = { ... };
```

The module will automatically compute: `/p-home` + `/home/ephemeral` = `/p-home/home/ephemeral`

### Step 4: Migrate data

```bash
# Create new directory structure and move existing data
sudo mkdir -p /p-home/home
sudo mv /p-home/ephemeral /p-home/home/ephemeral

# Verify ownership (should already be correct)
ls -la /p-home/home/ephemeral
```

### Step 5: Rebuild and reboot

```bash
sudo nixos-rebuild boot --flake .#zion-alpha
sudo reboot
```

---

## References

- [Impermanence GitHub](https://github.com/nix-community/impermanence)
- [home-manager-v1 branch](https://github.com/nix-community/impermanence/tree/home-manager-v1)
- [Breaking change commit](https://github.com/nix-community/impermanence/commit/1b02741e3d154a4bc59af55989ea66528e84b371)
- [Issue #285 - Migration notes](https://github.com/nix-community/impermanence/issues/285)
