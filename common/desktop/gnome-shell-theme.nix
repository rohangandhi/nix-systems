{ pkgs, colors, name }:
pkgs.stdenvNoCC.mkDerivation {
  pname = "gnome-shell-theme-${name}";
  version = pkgs.gnome-shell.version;
  src = pkgs.gnome-shell.src;
  nativeBuildInputs = [ pkgs.sassc ];
  dontConfigure = true;

  # Keep the pinned Shell's geometry, assets and interaction states. Override
  # its color seeds before it derives borders, hover/disabled states, etc.
  postPatch = ''
    substituteInPlace data/theme/gnome-shell-sass/_colors.scss \
      --replace-fail '// Derived Colors' '
    $base_color: ${colors.background};
    $bg_color: ${colors.surface};
    $fg_color: ${colors.foreground};
    $osd_bg_color: ${colors.surface};
    $osd_fg_color: ${colors.foreground};
    $system_base_color: ${colors.background};
    $system_fg_color: ${colors.foreground};
    $panel_bg_color: ${colors.background};
    $panel_fg_color: ${colors.foreground};
    $card_bg_color: ${colors.selection};
    $accent_color: ${colors.accent};
    $destructive_bg_color: ${colors.red};
    $destructive_fg_color: ${colors.background};
    $destructive_color: ${colors.red};
    $success_bg_color: ${colors.green};
    $success_fg_color: ${colors.background};
    $success_color: ${colors.green};
    $warning_bg_color: ${colors.yellow};
    $warning_fg_color: ${colors.background};
    $warning_color: ${colors.yellow};
    $error_bg_color: ${colors.red};
    $error_fg_color: ${colors.background};
    $error_color: ${colors.red};
    $link_color: ${colors.accent};
    $link_visited_color: ${colors.magenta};
    // Derived Colors'
  '';
  buildPhase = ''
    runHook preBuild
    cd data/theme
    sassc -a gnome-shell-dark.scss gnome-shell.css
    # St's named accent is limited to GNOME's built-in palette. Replace it in
    # the generated theme so sliders, switches and focus rings use exact RGB.
    substituteInPlace gnome-shell.css \
      --replace-fail '-st-accent-fg-color' '${colors.background}' \
      --replace-fail '-st-accent-color' '${colors.accent}'
    cat >> gnome-shell.css <<'CSS'
    .slider { -barlevel-active-foreground-color: ${colors.background}; }
    CSS
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    install -Dm644 gnome-shell.css "$out/share/themes/${name}/gnome-shell/gnome-shell.css"
    runHook postInstall
  '';
}
