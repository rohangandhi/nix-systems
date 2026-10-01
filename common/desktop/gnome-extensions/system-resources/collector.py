"""Read-only, unprivileged snapshots. File I/O stays outside GNOME Shell.

No recursive filesystem scans, command lines, environment variables, or saved state.
Application detail uses PSS (shared pages divided among the processes using them).
"""

import argparse
from concurrent.futures import ThreadPoolExecutor
import ipaddress
import json
import os
from pathlib import Path
import re
import struct
import socket
import subprocess
import time


PERSISTENT = ("/p-home", "/p-data", "/p-shared", "/p-os")


def network_config():
    try:
        data = json.loads(read("/etc/system-resources-network.json"))
        return {key: data.get(key) if isinstance(data.get(key), str) else None
                for key in ("nas", "router")}
    except (ValueError, AttributeError):
        return {"nas": None, "router": None}


def command(argv):
    try:
        return subprocess.run(argv, capture_output=True, text=True, check=True,
                              timeout=0.8, env={**os.environ, "LC_ALL": "C"}).stdout
    except (OSError, subprocess.SubprocessError):
        return ""


def default_route(text):
    try:
        routes = json.loads(text)
    except (ValueError, TypeError):
        return {}
    candidates = [route for route in routes if route.get("dst") == "default"
                  and route.get("dev") and route.get("type", "unicast") == "unicast"]
    return min(candidates, key=lambda route: route.get("metric", 0), default={})


def network_devices(text):
    """nmcli terse output, with escaping disabled so IPv6 stays intact."""
    devices, current = {}, None
    for line in text.splitlines():
        key, separator, value = line.partition(":")
        if not separator:
            continue
        if key == "GENERAL.DEVICE":
            current = devices.setdefault(value, {})
        elif current is not None and value:
            current.setdefault(key.split("[")[0], []).append(value)
    return devices


def dns_servers(text):
    servers = []
    for line in text.splitlines():
        fields = line.split("#", 1)[0].split(";", 1)[0].split()
        if len(fields) >= 2 and fields[0] == "nameserver":
            try:
                ipaddress.ip_address(fields[1])
            except ValueError:
                continue
            if fields[1] not in servers:
                servers.append(fields[1])
    return servers


def nas_mounts(text, host):
    """Inspect the mount table only; never touch/automount an offline share."""
    shares = []
    for line in text.splitlines():
        before, separator, after = line.partition(" - ")
        fields, fs = before.split(), after.split()
        if not separator or len(fields) < 6 or len(fs) < 2 or fs[0] != "cifs":
            continue
        source = unescape_mount(fs[1])
        if source.startswith(f"//{host}/") and fields[3] == "/":
            shares.append({"path": unescape_mount(fields[4]), "share": source.split("/", 3)[3]})
    return shares


def web_port(host):
    """A bounded TCP handshake, not a ping, TLS check, or device health check."""
    if not host:
        return {"reachable": None, "connectMs": None}
    start = time.monotonic()
    try:
        with socket.create_connection((host, 443), timeout=0.6):
            return {"reachable": True, "connectMs": round((time.monotonic() - start) * 1000, 1)}
    except OSError:
        return {"reachable": False, "connectMs": None}


def network_snapshot():
    route = default_route(command(["@ip@", "-j", "route", "show", "default"]))
    if not route:
        route = default_route(command(["@ip@", "-j", "-6", "route", "show", "default"]))
    devices = network_devices(command(["@nmcli@", "--terse", "--escape", "no", "--fields",
        "GENERAL.DEVICE,GENERAL.STATE,IP4.ADDRESS,IP4.DNS,IP6.ADDRESS,IP6.DNS", "device", "show"]))
    interface = route.get("dev")
    device = devices.get(interface, {})
    addresses = device.get("IP4.ADDRESS", []) + device.get("IP6.ADDRESS", [])
    servers = dns_servers(read("/etc/resolv.conf"))
    # With a local stub, expose NM's configured upstreams in the tooltip only.
    # Split DNS/VPN routing can select a different server for each query.
    upstream = list(dict.fromkeys(server for config in devices.values()
        if any(state.startswith("100 ") for state in config.get("GENERAL.STATE", []))
        for server in config.get("IP4.DNS", []) + config.get("IP6.DNS", [])))
    targets = network_config()
    NAS, ROUTER = targets["nas"], targets["router"]
    with ThreadPoolExecutor(max_workers=2) as pool:
        nas, router = list(pool.map(web_port, [NAS, ROUTER]))
    return {"interface": interface, "address": addresses[0] if addresses else route.get("prefsrc"),
            "gateway": route.get("gateway"), "dns": servers, "upstreamDns": upstream,
            "nas": {"address": NAS, "url": f"https://{NAS}" if NAS else None, **nas,
                    "mounts": nas_mounts(read("/proc/self/mountinfo"), NAS) if NAS else []},
            "router": {"address": ROUTER, "url": f"https://{ROUTER}/" if ROUTER else None, **router}}


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


def cpu_threads_snapshot(text, cpus=Path("/sys/devices/system/cpu")):
    threads = []
    for line in text.splitlines():
        match = re.match(r"cpu(\d+)\s", line)
        if not match:
            continue
        cpu = int(match[1])
        topology = cpus / f"cpu{cpu}" / "topology"
        core = integer(topology / "core_id")
        package = integer(topology / "physical_package_id")
        counters = cpu_snapshot(re.sub(r"^cpu\d+", "cpu", line))
        if counters:
            # Missing topology must not incorrectly combine unrelated CPUs.
            threads.append({"id": cpu, "core": core if core is not None else cpu,
                            "package": package if package is not None else 0, **counters})
    return sorted(threads, key=lambda item: (item["package"], item["core"], item["id"]))


def scaled(path, divisor):
    value = integer(path)
    return value / divisor if value is not None and value >= 0 else None


def cpu_sensors(hwmon=Path("/sys/class/hwmon"), cpuinfo=None):
    result = {"temperature": None, "temperatureLimit": None, "power": None,
              "powerScale": None}
    cpuinfo = read("/proc/cpuinfo") if cpuinfo is None else cpuinfo
    # This host's documented Tjmax; powerScale is a visual reference, NOT a cap.
    if re.search(r"AMD Ryzen 9 7900(?:\s|$)", cpuinfo):
        result.update(temperatureLimit=95, powerScale=100)
    for sensor in sorted(hwmon.glob("hwmon*")):
        name = read(sensor / "name").strip()
        if name == "k10temp" and result["temperature"] is None:
            result["temperature"] = scaled(sensor / "temp1_input", 1000)
            result["temperatureLimit"] = scaled(sensor / "temp1_crit", 1000) or result["temperatureLimit"]
        # Raphael's integrated GPU exports package/SoC PPT, including CPU power.
        # Do not mistake an arbitrary AMD discrete GPU's power for CPU power.
        if name == "amdgpu" and read(sensor / "device/device").strip() == "0x164e":
            result["power"] = scaled(sensor / "power1_input", 1_000_000)
    return result


def gpu_metrics(data):
    """The documented common prefix of AMD gpu_metrics v1.1–v1.3 only."""
    if len(data) < 22:
        return {}
    size, major, minor = struct.unpack_from("<HBB", data)
    if size > len(data) or size < 22 or major != 1 or minor not in (1, 2, 3):
        return {}
    values = struct.unpack_from("<3H", data, 16)
    # 0xffff is unsupported. Never present it (or other invalid data) as 100%.
    return {key: value if 0 <= value <= 100 else None
            for key, value in zip(("busy", "memoryBusy", "videoBusy"), values)}


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
    candidates = [("/", "Root"), (home, "Home")]
    volatile, seen = [], set()
    for path, name in candidates:
        mount = mounts.get(path)
        if not mount or mount["type"] != "tmpfs" or mount["device"] in seen:
            continue
        seen.add(mount["device"])
        volatile.append({**filesystem(path, mounts, statvfs), "name": name})
    return {"persistent": persistent, "volatile": volatile}


def gpu_snapshot(drm=Path("/sys/class/drm"), details=False):
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
    result = {"card": device.parent.name, "busy": integer(device / "gpu_busy_percent"),
              "total": total, "used": integer(device / "mem_info_vram_used"),
              "pci": pci[1] if pci else None}
    if details:
        try:
            metrics = gpu_metrics((device / "gpu_metrics").read_bytes())
        except OSError:
            metrics = {}
        memory_busy = integer(device / "mem_busy_percent")
        result.update(memoryBusy=memory_busy if memory_busy is not None else metrics.get("memoryBusy"),
                      videoBusy=metrics.get("videoBusy"), temperature=None,
                      temperatureLimit=None, power=None, powerLimit=None, name="Radeon")
        if result["busy"] is None:
            result["busy"] = metrics.get("busy")
        if read(device / "device").strip() == "0x744c" and 19 * 1024 ** 3 < total < 21 * 1024 ** 3:
            result["name"] = "RX 7900 XT"
        for sensor in sorted((device / "hwmon").glob("hwmon*")):
            if read(sensor / "name").strip() != "amdgpu":
                continue
            result.update(temperature=scaled(sensor / "temp1_input", 1000),
                          temperatureLimit=scaled(sensor / "temp1_crit", 1000),
                          power=scaled(sensor / "power1_average", 1_000_000),
                          powerLimit=scaled(sensor / "power1_cap", 1_000_000))
            break
    return result


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
    top = lambda items: sorted(items, key=lambda item: item["bytes"], reverse=True)[:3]
    return {"items": top(groups.values()), "omitted": omitted,
            "vramItems": top(item for item in gpu_groups.values() if item["bytes"] > 0),
            "vramStatus": "ok" if clients else "unavailable"}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--storage", action="store_true")
    parser.add_argument("--applications", action="store_true")
    parser.add_argument("--network", action="store_true")
    args = parser.parse_args()
    if args.network:
        print(json.dumps(network_snapshot(), allow_nan=False, separators=(",", ":")))
        return
    cpu_text = read("/proc/stat")
    result = {"cpu": cpu_snapshot(cpu_text),
              "memory": memory_snapshot(read("/proc/meminfo")),
              "gpu": gpu_snapshot(details=args.applications)}
    if args.storage:
        result["storage"] = storage_snapshot(read("/proc/self/mountinfo"),
                                             str(Path.home()))
    if args.applications:
        result["threads"] = cpu_threads_snapshot(cpu_text)
        result["cpuSensors"] = cpu_sensors()
        result["applications"] = applications_snapshot(gpu_pci=result["gpu"]["pci"] if result["gpu"] else None)
    print(json.dumps(result, allow_nan=False, separators=(",", ":")))


if __name__ == "__main__":
    main()
