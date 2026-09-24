# Configuration tenets

These rules guide changes to the configuration. The first rule is the most important.

1. **The whole system must be understandable from `flake.nix`.** Treat the system declaration as configuration, not code. Keep the main declaration in the public `flake.nix`: identity, inputs, and every selected public module. A private flake may extend that host with a short, explicit list of private additions. Do not split the main list into assembly files or hide it behind a preset, helper, loop, or generated import. Keep Nix flat, explicit, and boring. Repeating a declaration is better than hiding it.

2. **Keep each feature together.** A feature file holds that feature's packages, system settings, and Home Manager settings. `flake.nix` selects the features; feature files hold their details. Do not create extra files just to group imports.

3. **Show what is enabled.** Keep the desktop, applications, hardware, services, and VM launchers visible in `flake.nix`. Commented entries may show disabled choices. Do not discover or import files automatically. Templates and examples follow the same rule.

4. **Give shared settings one home.** Pass genuinely shared values, such as the username, through `my-options` or a clearly named module option. Define their types. Keep feature-specific settings beside the feature.

5. **Make stored state deliberate.** Say what is temporary and what survives restarts. Declare storage paths and persistence explicitly. Preserve existing data when reorganizing configuration.

6. **Make access boundaries explicit.** Declare which files, networks, ports, and privileges a VM or service may use. Grant only the access it needs. Keep host private keys on the host, and keep VM-only permissions confined to the VM.
