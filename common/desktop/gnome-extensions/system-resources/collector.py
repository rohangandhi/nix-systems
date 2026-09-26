"""Read-only, unprivileged snapshots. File I/O stays outside GNOME Shell.

No recursive filesystem scans, command lines, environment variables, or saved state.
Application detail uses PSS (shared pages divided among the processes using them).
"""

import argparse
import json
import os
from pathlib import Path
import re


PERSISTENT = ("/p-os", "/p-home", "/p-data", "/p-shared")


def read(path):
    try:
        return Path(path).read_text()
    except (OSError, UnicodeError):
        return ""


def integer(path):
    try:
        return int(read(path).strip())
    except ValueError:
        return None


def kilobytes(text):
    return {key: int(value) * 1024 for key, value in
            re.findall(r"^(\w+):\s+(\d+) kB", text, re.MULTILINE)}


def cpu_snapshot(text):
    line = next((line for line in text.splitlines() if line.startswith("cpu ")), "")
    values = [int(value) for value in line.split()[1:9]]
    if len(values) < 5:
        return None
    # Guest/guest_nice are already included in user/nice; do not count twice.
    return {"total": sum(values), "idle": values[3] + values[4]}


def memory_snapshot(text):
    values = kilobytes(text)
    total, available = values.get("MemTotal"), values.get("MemAvailable")
    if total is None or available is None:
        return None
    return {"total": total, "used": max(0, total - available),
            "available": available,
            "swapTotal": values.get("SwapTotal", 0),
            "swapUsed": values.get("SwapTotal", 0) - values.get("SwapFree", 0)}


def unescape_mount(value):
    return re.sub(r"\\([0-7]{3})", lambda m: chr(int(m[1], 8)), value)


def mounts_snapshot(text):
    mounts = {}
    for line in text.splitlines():
        before, separator, after = line.partition(" - ")
        fields, fs = before.split(), after.split()
        if separator and len(fields) >= 6 and fs:
            mounts[unescape_mount(fields[4])] = {
                "device": fields[2], "root": unescape_mount(fields[3]), "type": fs[0]}
    return mounts


def filesystem(path, mounts, statvfs=os.statvfs):
    # A missing drive must not silently report the parent tmpfs as its disk.
    if path not in mounts:
        return {"path": path, "status": "unmounted"}
    try:
        stat = statvfs(path)
        total = stat.f_blocks * stat.f_frsize
        used = (stat.f_blocks - stat.f_bfree) * stat.f_frsize
        available = stat.f_bavail * stat.f_frsize
        return {"path": path, "status": "ok", "total": total,
                "used": used, "available": available,
                # Like df, reserved blocks aren't available to the user.
                "fraction": used / (used + available) if used + available else 0}
    except OSError:
        return {"path": path, "status": "unavailable"}


def storage_snapshot(mount_text, home, statvfs=os.statvfs):
    mounts = mounts_snapshot(mount_text)
    persistent = [filesystem(path, mounts, statvfs) for path in PERSISTENT]
    candidates = [(home, "Home"), ("/", "Root")]
    volatile, seen = [], set()
    for path, name in candidates:
        mount = mounts.get(path)
        if not mount or mount["type"] != "tmpfs" or mount["device"] in seen:
            continue
        seen.add(mount["device"])
        volatile.append({**filesystem(path, mounts, statvfs), "name": name})
    return {"persistent": persistent, "volatile": volatile}


def gpu_snapshot(drm=Path("/sys/class/drm")):
    cards = []
    for card in drm.glob("card[0-9]*"):
        if not re.fullmatch(r"card\d+", card.name):
            continue
        device = card / "device"
        if read(device / "vendor").strip() != "0x1002":
            continue
        total = integer(device / "mem_info_vram_total")
        if total:
            cards.append((total, device))
    if not cards:
        return None
    # This host has both an integrated AMD GPU and a discrete Radeon.
    total, device = max(cards, key=lambda pair: pair[0])
    pci = re.search(r"^PCI_SLOT_NAME=(.+)$", read(device / "uevent"), re.MULTILINE)
    return {"card": device.parent.name, "busy": integer(device / "gpu_busy_percent"),
            "total": total, "used": integer(device / "mem_info_vram_used"),
            "pci": pci[1] if pci else None}


def drm_memory(value):
    match = re.fullmatch(r"(\d+)\s*(B|KiB|MiB)?", value.strip())
    if not match:
        return None
    return int(match[1]) * {None: 1, "B": 1, "KiB": 1024, "MiB": 1024 ** 2}[match[2]]


def vram_clients(directory, pci):
    """Resident VRAM, deduplicated by DRM client rather than file descriptor."""
    if not pci:
        return {}
    clients = {}
    try:
        for fd in (directory / "fdinfo").iterdir():
            fields = dict(line.split(":", 1) for line in read(fd).splitlines() if ":" in line)
            fields = {key: value.strip() for key, value in fields.items()}
            if fields.get("drm-driver") != "amdgpu" or fields.get("drm-pdev") != pci:
                continue
            client = fields.get("drm-client-id", "")
            # drm-memory-vram is an AMD alias, not another allocation to add.
            used = drm_memory(fields.get("drm-resident-vram", fields.get("drm-memory-vram", "")))
            if client.isdigit() and used is not None:
                clients[client] = max(clients.get(client, 0), used)
    except OSError:
        pass  # Protected/exited processes do not grant access to their GPU FDs.
    return clients


def application_group(cgroup, comm):
    # GNOME/systemd app scopes contain all child processes, including renderers.
    path = next((line[3:] for line in cgroup.splitlines() if line.startswith("0::")), "")
    units = path.split("/")
    app = next((unit for unit in units if unit.startswith("app-") and
                unit.endswith((".scope", ".service"))), None)
    if app:
        name = re.sub(r"\.(scope|service)$", "", app)[4:]
        name = re.sub(r"^(gnome|gnome-shell)-", "", name)
        name = re.sub(r"(?:-[0-9]+|@[a-zA-Z0-9_-]+)$", "", name)
        name = re.sub(r"\\x([0-9a-fA-F]{2})", lambda m: chr(int(m[1], 16)), name)
        return f"app:{name}", name, f"{name}.desktop"
    service = next((unit for unit in reversed(units) if unit.endswith(".service")), None)
    if service:
        name = service.removesuffix(".service")
        return f"service:{name}", name, None
    return f"process:{comm}", comm, None


def applications_snapshot(proc=Path("/proc"), uid=None, gpu_pci=None):
    uid = os.getuid() if uid is None else uid
    groups, gpu_groups, clients = {}, {}, {}
    omitted = 0
    for directory in proc.iterdir():
        if not directory.name.isdigit() or int(directory.name) == os.getpid():
            continue
        try:
            if directory.stat().st_uid != uid:
                continue
            comm = read(directory / "comm").strip()
            if not comm:
                continue
            key, name, desktop = application_group(read(directory / "cgroup"), comm)
            for client, used in vram_clients(directory, gpu_pci).items():
                gpu_groups.setdefault(key, {"name": name, "desktop": desktop, "bytes": 0})
                entry = clients.setdefault(client, {"bytes": 0, "groups": set()})
                entry["bytes"] = max(entry["bytes"], used)
                entry["groups"].add(key)
            values = kilobytes(read(directory / "smaps_rollup"))
            pss = values.get("Pss")
            approximate = pss is None
            if approximate:
                pss = kilobytes(read(directory / "status")).get("VmRSS")
            if pss is None:
                omitted += 1
                continue
            group = groups.setdefault(key, {"name": name, "desktop": desktop,
                                           "bytes": 0, "approximate": False})
            group["bytes"] += pss
            group["approximate"] |= approximate
        except OSError:
            # Processes can exit between discovery and reading their counters.
            continue
    # A shared DRM file may be visible from several processes or app groups.
    # Count once, dividing across groups if necessary. Distinct clients can still
    # reference shared buffers; these figures are not an additive card-wide total.
    for client in clients.values():
        share = client["bytes"] / len(client["groups"])
        for key in client["groups"]:
            gpu_groups[key]["bytes"] += share
    top = lambda items: sorted(items, key=lambda item: item["bytes"], reverse=True)[:5]
    return {"items": top(groups.values()), "omitted": omitted,
            "vramItems": top(item for item in gpu_groups.values() if item["bytes"] > 0),
            "vramStatus": "ok" if clients else "unavailable"}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--storage", action="store_true")
    parser.add_argument("--applications", action="store_true")
    args = parser.parse_args()
    result = {"cpu": cpu_snapshot(read("/proc/stat")),
              "memory": memory_snapshot(read("/proc/meminfo")), "gpu": gpu_snapshot()}
    if args.storage:
        result["storage"] = storage_snapshot(read("/proc/self/mountinfo"),
                                             str(Path.home()))
    if args.applications:
        result["applications"] = applications_snapshot(gpu_pci=result["gpu"]["pci"] if result["gpu"] else None)
    print(json.dumps(result, allow_nan=False, separators=(",", ":")))


if __name__ == "__main__":
    main()
