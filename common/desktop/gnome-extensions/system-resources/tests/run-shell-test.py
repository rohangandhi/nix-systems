"""Smoke-test a built package in a separate bus, compositor, and settings."""

import argparse
import os
from pathlib import Path
import signal
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", type=Path)
    parser.add_argument("--scale", choices=[1, 2], type=int, default=2)
    parser.add_argument("--output", type=Path, default=Path("/tmp/system-resources-ui-test"))
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    extension = args.package.resolve() / "share/gnome-shell/extensions/system-resources@local"
    if not (extension / "metadata.json").exists():
        parser.error("package does not contain the built extension")

    with tempfile.TemporaryDirectory(prefix="system-resources-shell-") as temporary:
        root = Path(temporary)
        for name in ["config/glib-2.0/settings", "data/gnome-shell/extensions", "cache", "state", "runtime"]:
            (root / name).mkdir(parents=True, exist_ok=True)
        (root / "runtime").chmod(0o700)
        (root / "data/gnome-shell/extensions/system-resources@local").symlink_to(extension)
        (root / "config/glib-2.0/settings/keyfile").write_text(f"""[org/gnome/shell]
enabled-extensions=['system-resources@local']
disable-user-extensions=false
welcome-dialog-last-shown-version='50.4'
[org/gnome/desktop/interface]
enable-animations=false
color-scheme='prefer-dark'
scaling-factor=uint32 {args.scale}
""")
        env = os.environ.copy()
        env.update(XDG_CONFIG_HOME=str(root / "config"), XDG_DATA_HOME=str(root / "data"),
                   XDG_CACHE_HOME=str(root / "cache"), XDG_STATE_HOME=str(root / "state"),
                   XDG_RUNTIME_DIR=str(root / "runtime"), GSETTINGS_BACKEND="keyfile",
                   LIBGL_ALWAYS_SOFTWARE="1", GDK_BACKEND="wayland",
                   SYSTEM_RESOURCES_TEST_OUTPUT=str(args.output.resolve()))
        env.pop("DISPLAY", None)
        env.pop("WAYLAND_DISPLAY", None)
        command = ["dbus-run-session", "--", "gnome-shell", "--headless", "--wayland", "--no-x11",
                   "--virtual-monitor", "2560x1440" if args.scale == 2 else "1280x720",
                   "--automation-script", str(Path(__file__).with_name("shell-smoke.js").resolve())]
        log_path = args.output / "session.log"
        with log_path.open("w") as log:
            process = subprocess.Popen(command, env=env, stdout=log, stderr=log, start_new_session=True)
            try:
                process.wait(timeout=45)
            finally:
                # Includes only processes in this disposable test's process group.
                try:
                    os.killpg(process.pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass
                process.wait()
        output = log_path.read_text()
        expected = f"SYSTEM RESOURCES TEST PASSED (scale {args.scale})"
        if process.returncode or expected not in output or "Did not find color property" in output:
            raise SystemExit(f"GNOME smoke test failed; inspect {log_path}")
        print(f"{expected}; screenshots and log: {args.output}")


if __name__ == "__main__":
    main()
