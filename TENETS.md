# Configuration tenets

These rules guide changes to the configuration. The first rule is the most important.

1. **Keep Nix flat, explicit, and boring.** Write settings directly. Keep nesting and indirection as small as readability allows. Prefer a little repetition over a helper that hides what is configured. Avoid custom builders, loops, and generated declarations when plain declarations are readable. Normal NixOS modules are fine; extra abstraction needs a clear readability benefit. Existing helpers are exceptions, not examples to copy.

2. **Keep each feature together.** Put an application's packages, system settings, and Home Manager settings in its own module. Organize files by what they configure.

3. **Show what the system includes.** List modules, applications, and desktops explicitly. Someone reading the system configuration should see what is enabled. Do not discover or import files automatically.

4. **Give shared settings one home.** Pass genuinely shared values, such as the username, through `my-options` or a clearly named module option. Define their types. Keep feature-specific settings beside the feature.

5. **Make stored state deliberate.** Say what is temporary and what survives restarts. Declare storage paths and persistence explicitly. Preserve existing data when reorganizing configuration.

6. **Make access boundaries explicit.** Declare which files, networks, ports, and privileges a VM or service may use. Grant only the access it needs. Keep host private keys on the host, and keep VM-only permissions confined to the VM.
