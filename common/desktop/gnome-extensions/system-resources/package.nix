{ pkgs }:
pkgs.stdenvNoCC.mkDerivation {
  pname = "gnome-shell-extension-system-resources";
  version = "2";
  src = ./.;
  nativeCheckInputs = [ pkgs.python3 pkgs.nodejs ];
  dontBuild = true;
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    python3 -m unittest discover -s tests -p 'test_*.py' -v
    node --check extension.js
    node --test tests/format.test.js
    runHook postCheck
  '';
  installPhase = ''
    runHook preInstall
    extensionDir="$out/share/gnome-shell/extensions/system-resources@local"
    mkdir -p "$extensionDir"
    cp extension.js format.js collector.py metadata.json stylesheet.css "$extensionDir/"
    substituteInPlace "$extensionDir/extension.js" \
      --replace-fail '@python@' '${pkgs.lib.getExe pkgs.python3}'
    runHook postInstall
  '';
  passthru.extensionUuid = "system-resources@local";
  meta = {
    description = "Native GNOME menu for storage, RAM, and Radeon VRAM consumers";
    platforms = pkgs.lib.platforms.linux;
  };
}
