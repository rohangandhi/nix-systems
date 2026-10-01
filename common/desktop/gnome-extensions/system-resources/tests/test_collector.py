import os
from pathlib import Path
from types import SimpleNamespace
import tempfile
import struct
import unittest
from unittest.mock import patch

import collector


def mount(path, device="0:1", fs="tmpfs", root="/"):
    return f"1 0 {device} {root} {path} rw - {fs} none rw\n"


class CollectorTests(unittest.TestCase):
    def test_network_route_prefers_low_metric_and_ignores_unusable_routes(self):
        self.assertEqual(collector.default_route('invalid'), {})
        self.assertEqual(collector.default_route('[]'), {})
        result = collector.default_route('[{"dst":"default","dev":"eno1","metric":100},'
            '{"dst":"default","dev":"wlan0","metric":600},'
            '{"dst":"default","dev":"bad","type":"blackhole"},'
            '{"dst":"192.0.2.0/24","dev":"other"}]')
        self.assertEqual(result["dev"], "eno1")

    def test_network_dns_and_ipv6_parsing(self):
        self.assertEqual(collector.dns_servers('# nameserver 9.9.9.9\nnameserver 1.1.1.1 # test\n'
            'nameserver ::1\nnameserver invalid\nnameserver 1.1.1.1\n'), ['1.1.1.1', '::1'])
        result = collector.network_devices('GENERAL.DEVICE:eno1\nGENERAL.STATE:100 (connected)\n'
            'IP4.DNS[1]:1.1.1.1\nIP4.DNS[2]:8.8.8.8\nIP6.ADDRESS[1]:fe80::1234/64\n'
            '\nGENERAL.DEVICE:lo\nIP4.ADDRESS[1]:127.0.0.1/8\n')
        self.assertEqual(result['eno1']['IP4.DNS'], ['1.1.1.1', '8.8.8.8'])
        self.assertEqual(result['eno1']['IP6.ADDRESS'], ['fe80::1234/64'])
        self.assertNotIn('IP4.DNS', result['lo'])

    def test_nas_mount_status_does_not_trigger_automount_or_count_bind_alias(self):
        text = ('1 0 0:1 / /home/alice/n-data rw - cifs //192.0.2.10/fixture-share rw\n'
                '2 0 0:1 /nix /workspace rw - cifs //192.0.2.10/fixture-share rw\n'
                '3 0 0:2 / /other rw - cifs //192.0.2.11/other rw\n'
                '4 0 0:3 / /auto rw - autofs systemd-1 rw\n')
        self.assertEqual(collector.nas_mounts(text, "192.0.2.10"), [{'path': '/home/alice/n-data', 'share': 'fixture-share'}])
        self.assertEqual(collector.nas_mounts('', '192.0.2.10'), [])

    def test_network_timeout_and_absent_tools_degrade_independently(self):
        with patch('collector.socket.create_connection', side_effect=TimeoutError):
            self.assertEqual(collector.web_port('198.51.100.20'), {'reachable': False, 'connectMs': None})
        with patch('collector.subprocess.run', side_effect=FileNotFoundError):
            self.assertEqual(collector.command(['missing']), '')
        with patch('collector.command', return_value=''), patch('collector.read', return_value=''), \
             patch('collector.web_port', return_value={'reachable': False, 'connectMs': None}), \
             patch('collector.network_config', return_value={'nas': '192.0.2.10', 'router': '198.51.100.20'}):
            result = collector.network_snapshot()
        self.assertIsNone(result['gateway'])
        self.assertEqual(result['dns'], [])
        self.assertFalse(result['nas']['reachable'])

    def test_unconfigured_network_devices_are_not_probed(self):
        with patch('collector.socket.create_connection') as connect:
            self.assertEqual(collector.web_port(None), {'reachable': None, 'connectMs': None})
            connect.assert_not_called()
        with patch('collector.read', return_value='invalid'):
            self.assertEqual(collector.network_config(), {'nas': None, 'router': None})
        with patch('collector.read', return_value='{"nas":"192.0.2.10","router":null}'):
            self.assertEqual(collector.network_config(), {'nas': '192.0.2.10', 'router': None})

    def test_cpu_does_not_double_count_guest(self):
        self.assertEqual(collector.cpu_snapshot("cpu 10 2 3 50 5 1 2 7 8 1\n"),
                         {"total": 80, "idle": 55})
        self.assertIsNone(collector.cpu_snapshot(""))

    def test_memory_uses_available_not_free(self):
        result = collector.memory_snapshot("MemTotal: 1000 kB\nMemFree: 10 kB\n"
                                           "MemAvailable: 600 kB\nSwapTotal: 20 kB\nSwapFree: 15 kB\n")
        self.assertEqual(result["used"], 400 * 1024)
        self.assertEqual(result["swapUsed"], 5 * 1024)
        self.assertIsNone(collector.memory_snapshot(""))

    def test_unmounted_disk_does_not_read_parent(self):
        def forbidden(_path):
            self.fail("statvfs must not be called for an unmounted persistent filesystem")
        self.assertEqual(collector.filesystem("/p-shared", {}, forbidden)["status"], "unmounted")

    def test_reserved_blocks_and_unavailable_mount(self):
        stat = SimpleNamespace(f_blocks=100, f_bfree=30, f_bavail=20, f_frsize=1024)
        result = collector.filesystem("/p-os", {"/p-os": {}}, lambda _path: stat)
        self.assertEqual(result["used"], 70 * 1024)
        self.assertEqual(result["available"], 20 * 1024)
        self.assertAlmostEqual(result["fraction"], 70 / 90)
        with patch("os.statvfs", side_effect=PermissionError):
            self.assertEqual(collector.filesystem("/p-os", {"/p-os": {}}, os.statvfs)["status"],
                             "unavailable")

    def test_mount_escapes_and_volatile_storage_selection(self):
        text = mount("/") + mount("/tmp", root="/tmp") + mount("/home/alice", "0:2")
        text += mount("/p-home", "253:1", "ext4") + mount("/dev/shm", "0:3")
        text += mount(r"/a\040b", "0:4")
        self.assertIn("/a b", collector.mounts_snapshot(text))
        stat = SimpleNamespace(f_blocks=100, f_bfree=30, f_bavail=30, f_frsize=1024)
        result = collector.storage_snapshot(text, "/home/alice", lambda _path: stat)
        self.assertEqual([item["name"] for item in result["volatile"]], ["Root", "Home"])
        self.assertEqual([item["path"] for item in result["persistent"]],
                         ["/p-home", "/p-data", "/p-shared", "/p-os"])
        self.assertEqual(result["persistent"][2]["status"], "unmounted")

    def test_threads_follow_physical_topology_not_cpu_number(self):
        with tempfile.TemporaryDirectory() as directory:
            cpus = Path(directory)
            text = ""
            for cpu, core in [(0, 0), (1, 8), (12, 0), (13, 8)]:
                topology = cpus / f"cpu{cpu}" / "topology"
                topology.mkdir(parents=True)
                (topology / "core_id").write_text(str(core))
                (topology / "physical_package_id").write_text("0")
                text += f"cpu{cpu} 10 2 3 50 5 1 2 7 8 1\n"
            result = collector.cpu_threads_snapshot(text, cpus)
            self.assertEqual([t["id"] for t in result], [0, 12, 1, 13])
            self.assertTrue(all(t["total"] == 80 and t["idle"] == 55 for t in result))

    def test_gpu_metrics_validate_version_size_and_unavailable_counters(self):
        data = bytearray(120)
        struct.pack_into("<HBB", data, 0, 120, 1, 3)
        struct.pack_into("<3H", data, 16, 25, 0, 65535)
        self.assertEqual(collector.gpu_metrics(data), {"busy": 25, "memoryBusy": 0, "videoBusy": None})
        self.assertEqual(collector.gpu_metrics(data[:21]), {})
        self.assertEqual(collector.gpu_metrics(data[:22]), {})
        data[3] = 4  # Later layouts have different offsets; do not guess.
        self.assertEqual(collector.gpu_metrics(data), {})
        data[2:4] = bytes([2, 1])
        self.assertEqual(collector.gpu_metrics(data), {})

    def test_cpu_power_uses_raphael_soc_not_discrete_gpu(self):
        with tempfile.TemporaryDirectory() as directory:
            hwmon = Path(directory)
            for number, name, device, power in [(2, "k10temp", "", None),
                                               (8, "amdgpu", "0x744c", 250000000),
                                               (9, "amdgpu", "0x164e", 35000000)]:
                sensor = hwmon / f"hwmon{number}"
                (sensor / "device").mkdir(parents=True)
                (sensor / "name").write_text(name)
                (sensor / "device/device").write_text(device)
                (sensor / "temp1_input").write_text("47000")
                if power is not None:
                    (sensor / "power1_input").write_text(str(power))
            result = collector.cpu_sensors(hwmon, "AMD Ryzen 9 7900 12-Core Processor")
            self.assertEqual(result["power"], 35)
            self.assertEqual(result["temperature"], 47)
            self.assertEqual(result["temperatureLimit"], 95)
            self.assertEqual(result["powerScale"], 100)
            (hwmon / "hwmon9/power1_input").unlink()
            self.assertIsNone(collector.cpu_sensors(hwmon, "AMD Ryzen 9 7900X")["power"])
            self.assertIsNone(collector.cpu_sensors(hwmon, "AMD Ryzen 9 7900X")["temperatureLimit"])

    def test_gpu_prefers_discrete_card_not_card_zero(self):
        with tempfile.TemporaryDirectory() as directory:
            drm = Path(directory)
            for card, total, used, busy in [("card0", 512, 20, 2), ("card1", 20000, 1000, 35)]:
                device = drm / card / "device"
                device.mkdir(parents=True)
                for name, value in {"vendor": "0x1002", "mem_info_vram_total": total,
                                    "mem_info_vram_used": used, "gpu_busy_percent": busy,
                                    "uevent": f"PCI_SLOT_NAME=0000:{'03' if card == 'card1' else '0f'}:00.0"}.items():
                    (device / name).write_text(str(value))
            self.assertEqual(collector.gpu_snapshot(drm),
                             {"card": "card1", "busy": 35, "total": 20000, "used": 1000,
                              "pci": "0000:03:00.0"})

    def test_grouping_merges_launches_and_unescapes_desktop_id(self):
        for scope in ["app-gnome-codium-123.scope", "app-codium-456.scope"]:
            self.assertEqual(collector.application_group(f"0::/user.slice/{scope}", "renderer"),
                             ("app:codium", "codium", "codium.desktop"))
        self.assertEqual(collector.application_group(r"0::/app-gnome-codex\x2ddesktop-123.scope", "x")[2],
                         "codex-desktop.desktop")
        self.assertEqual(collector.application_group("0::/app-org.example.App@abc.service", "x")[2],
                         "org.example.App.desktop")

    def test_pss_groups_children_and_marks_rss_fallback(self):
        with tempfile.TemporaryDirectory() as directory:
            proc = Path(directory)
            for pid, scope, pss, rss in [(100001, "app-gnome-firefox-12.scope", 100, 500),
                                         (100002, "app-gnome-firefox-12.scope", 50, 400),
                                         (100003, "app-codium-13.scope", None, 200),
                                         (100004, "app-missing-14.scope", None, None)]:
                process = proc / str(pid)
                process.mkdir()
                (process / "comm").write_text("renderer")
                (process / "cgroup").write_text(f"0::/user.slice/{scope}")
                if pss is not None:
                    (process / "smaps_rollup").write_text(f"Pss: {pss} kB\nRss: {rss} kB\n")
                if rss is not None:
                    (process / "status").write_text(f"VmRSS: {rss} kB\n")
            result = collector.applications_snapshot(proc)
            self.assertEqual(result["omitted"], 1)
            codium, firefox = result["items"]
            self.assertEqual(codium["bytes"], 200 * 1024)
            self.assertTrue(codium["approximate"])
            self.assertEqual(firefox["bytes"], 150 * 1024)
            self.assertFalse(firefox["approximate"])

    def test_drm_units_and_unsupported_values(self):
        for text, expected in [("0", 0), ("42 B", 42), ("12 KiB", 12288),
                               ("2 MiB", 2097152), ("n/a", None), ("", None)]:
            self.assertEqual(collector.drm_memory(text), expected)

    def test_vram_deduplicates_clients_and_filters_gpu(self):
        with tempfile.TemporaryDirectory() as directory:
            proc = Path(directory)
            # Client 8 is duplicated within and across processes and two groups.
            for pid, app, entries in [
                (100001, "editor", [(3, 8, "2 MiB", "0000:03:00.0"),
                                    (4, 8, "2048 KiB", "0000:03:00.0"),
                                    (5, 9, "9 MiB", "0000:0f:00.0")]),
                (100002, "editor", [(6, 8, "2 MiB", "0000:03:00.0")]),
                (100003, "browser", [(7, 8, "2 MiB", "0000:03:00.0"),
                                     (8, 10, "3 MiB", "0000:03:00.0")]),
            ]:
                process = proc / str(pid)
                (process / "fdinfo").mkdir(parents=True)
                (process / "comm").write_text("renderer")
                (process / "cgroup").write_text(f"0::/app-{app}-123.scope")
                # Deliberately no readable PSS; VRAM must still be collected.
                for fd, client, amount, pci in entries:
                    (process / "fdinfo" / str(fd)).write_text(
                        f"drm-driver:\tamdgpu\ndrm-pdev: {pci}\ndrm-client-id: {client}\n"
                        f"drm-resident-vram: {amount}\ndrm-memory-vram: 999 MiB\n")
            result = collector.applications_snapshot(proc, gpu_pci="0000:03:00.0")
            self.assertEqual(result["items"], [])
            self.assertEqual(result["vramStatus"], "ok")
            self.assertEqual([(item["name"], item["bytes"]) for item in result["vramItems"]],
                             [("browser", 4 * 1024 ** 2), ("editor", 1024 ** 2)])
            self.assertEqual(collector.applications_snapshot(proc)["vramStatus"], "unavailable")

    def test_vram_legacy_alias_and_readable_zero(self):
        with tempfile.TemporaryDirectory() as directory:
            process = Path(directory) / "100001"
            (process / "fdinfo").mkdir(parents=True)
            fd = process / "fdinfo/3"
            prefix = "drm-driver: amdgpu\ndrm-pdev: 0000:03:00.0\ndrm-client-id: 5\n"
            fd.write_text(prefix + "drm-memory-vram: 3 KiB\n")
            self.assertEqual(collector.vram_clients(process, "0000:03:00.0"), {"5": 3072})
            fd.write_text(prefix + "drm-resident-vram: 0\n")
            self.assertEqual(collector.vram_clients(process, "0000:03:00.0"), {"5": 0})


if __name__ == "__main__":
    unittest.main()
