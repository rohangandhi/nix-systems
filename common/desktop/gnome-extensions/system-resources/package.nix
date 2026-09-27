{ pkgs }:
pkgs.stdenvNoCC.mkDerivation {
  pname = "gnome-shell-extension-system-resources";
  version = "3";
  src = ./.;
  nativeCheckInputs = [ pkgs.python3 pkgs.nodejs ];
  dontBuild = true;
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    python3 -m unittest discover -s tests -p 'test_*.py' -v
    node --check extension.js
    node --check widgets.js
    node --test tests/format.test.js
    runHook postCheck
  '';
  installPhase = ''
    runHook preInstall
    extensionDir="$out/share/gnome-shell/extensions/system-resources@local"
    mkdir -p "$extensionDir"
    cp extension.js widgets.js format.js collector.py metadata.json stylesheet.css "$extensionDir/"
    cp -r icons "$extensionDir/"
    substituteInPlace "$extensionDir/extension.js" \
      --replace-fail '@python@' '${pkgs.lib.getExe pkgs.python3}'
    substituteInPlace "$extensionDir/collector.py" \
      --replace-fail '@ip@' '${pkgs.iproute2}/bin/ip' \
      --replace-fail '@nmcli@' '${pkgs.networkmanager}/bin/nmcli'
    runHook postInstall
  '';
  passthru.extensionUuid = "system-resources@local";
  meta = {
    description = "Native GNOME menu for storage, RAM, and Radeon VRAM consumers";
    platforms = pkgs.lib.platforms.linux;
  };
}
