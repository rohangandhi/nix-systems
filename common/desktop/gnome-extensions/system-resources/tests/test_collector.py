import os
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
from unittest.mock import patch

import collector


def mount(path, device="0:1", fs="tmpfs", root="/"):
    return f"1 0 {device} {root} {path} rw - {fs} none rw\n"


class CollectorTests(unittest.TestCase):
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
        self.assertEqual([item["name"] for item in result["volatile"]], ["Home", "Root"])
        self.assertEqual(result["persistent"][3]["status"], "unmounted")

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
