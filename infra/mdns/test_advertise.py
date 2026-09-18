import os
from pathlib import Path
import signal
import socket
import tempfile
import threading
import unittest
from unittest.mock import Mock, patch

import advertise


class ConfigurationTests(unittest.TestCase):
    def test_defaults_and_override(self):
        with patch.object(advertise, "default_address", return_value="192.168.1.20") as auto:
            self.assertEqual(advertise.configuration({}), ("192.168.1.20", 18080))
            self.assertEqual(
                advertise.configuration({"MDNS_ADDRESS": "10.0.0.4", "BACKEND_PORT": "9000"}),
                ("10.0.0.4", 9000),
            )
            auto.assert_called_once()

    def test_invalid_ports(self):
        for port in ("", "abc", "0", "-1", "65536", "80.5"):
            with self.subTest(port=port), self.assertRaisesRegex(ValueError, "BACKEND_PORT"):
                advertise.configuration({"BACKEND_PORT": port, "MDNS_ADDRESS": "10.0.0.4"})

    def test_invalid_addresses(self):
        for address in ("127.0.0.1", "0.0.0.0", "::1", "host.local", "224.0.0.251",
                        "255.255.255.255", "169.254.1.2", "999.1.1.1"):
            with self.subTest(address=address), self.assertRaisesRegex(ValueError, "MDNS_ADDRESS"):
                advertise.configuration({"MDNS_ADDRESS": address})

    def test_default_route_uses_lowest_metric_and_primary_ipv4(self):
        routes = "header\neth0 00000000 01010101 0003 0 0 100\nwlan0 00000000 01010101 0003 0 0 50\n"
        response = bytes(20) + socket.inet_aton("192.168.1.20") + bytes(232)
        with patch.object(Path, "read_text", return_value=routes), \
             patch.object(Path, "exists", return_value=False), \
             patch.object(advertise.fcntl, "ioctl", return_value=response) as ioctl:
            self.assertEqual(advertise.default_address(), "192.168.1.20")
            self.assertEqual(ioctl.call_args.args[2].split(b"\0")[0], b"wlan0")

    def test_no_route_or_bridge_requires_override(self):
        for routes, bridge in (("header\n", False),
                               ("header\ndocker0 00000000 0 0003 0 0 0\n", False),
                               ("header\ncustom0 00000000 0 0003 0 0 0\n", True)):
            with self.subTest(routes=routes), \
                 patch.object(Path, "read_text", return_value=routes), \
                 patch.object(Path, "exists", return_value=bridge), \
                 self.assertRaisesRegex(ValueError, "MDNS_ADDRESS"):
                advertise.default_address()


class LifecycleTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.ready = Path(directory.name) / "ready"
        self.patch_ready = patch.object(advertise, "READY_FILE", self.ready)
        self.patch_ready.start()
        self.addCleanup(self.patch_ready.stop)
        self.fake = Mock()
        factory = patch.object(advertise, "Zeroconf", return_value=self.fake)
        self.factory = factory.start()
        self.addCleanup(factory.stop)

    def test_registration_metadata_readiness_and_shutdown(self):
        stop = Mock()
        self.fake.register_service.side_effect = lambda *a, **kw: self.assertFalse(self.ready.exists())
        stop.wait.side_effect = lambda: self.assertTrue(advertise.healthy())
        advertise.advertise("192.168.1.20", 9000, stop)
        self.factory.assert_called_once_with(
            interfaces=["192.168.1.20"], ip_version=advertise.IPVersion.V4Only
        )
        info = self.fake.register_service.call_args.args[0]
        self.assertEqual(info.type, "_arena-api._tcp.local.")
        self.assertEqual(info.name, "Arena API (192.168.1.20)._arena-api._tcp.local.")
        self.assertEqual(info.server, "arena-api-192-168-1-20.local.")
        self.assertEqual(info.port, 9000)
        self.assertEqual(info.parsed_addresses(), ["192.168.1.20"])
        self.assertEqual(info.properties, {b"scheme": b"http", b"path": b"/api", b"apiVersion": b"1"})
        self.assertTrue(self.fake.register_service.call_args.kwargs["allow_name_change"])
        self.fake.unregister_service.assert_called_once_with(info)
        self.fake.close.assert_called_once()
        self.assertFalse(advertise.healthy())

    def test_failed_registration_clears_stale_readiness_and_closes(self):
        self.ready.write_text(str(os.getpid()))
        self.fake.register_service.side_effect = RuntimeError("registration failed")
        with self.assertRaisesRegex(RuntimeError, "registration failed"):
            advertise.advertise("192.168.1.20", 8080, threading.Event())
        self.assertFalse(self.ready.exists())
        self.fake.unregister_service.assert_not_called()
        self.fake.close.assert_called_once()

    def test_close_even_when_unregister_fails(self):
        stop = threading.Event()
        stop.set()
        self.fake.unregister_service.side_effect = RuntimeError("unregister failed")
        with self.assertRaisesRegex(RuntimeError, "unregister failed"):
            advertise.advertise("192.168.1.20", 8080, stop)
        self.fake.close.assert_called_once()
        self.assertFalse(self.ready.exists())

    def test_signals_cleanly_stop_main(self):
        for signum in (signal.SIGTERM, signal.SIGINT):
            with self.subTest(signal=signum):
                self.fake.reset_mock(side_effect=True)
                previous = {sig: signal.getsignal(sig) for sig in (signal.SIGTERM, signal.SIGINT)}
                self.fake.register_service.side_effect = lambda *a, **kw: signal.raise_signal(signum)
                try:
                    with patch.dict(os.environ, {"MDNS_ADDRESS": "192.168.1.20"}, clear=True), \
                         patch.object(advertise.sys, "argv", ["advertise.py"]):
                        self.assertEqual(advertise.main(), 0)
                finally:
                    for sig, handler in previous.items():
                        signal.signal(sig, handler)
                self.fake.unregister_service.assert_called_once()
                self.fake.close.assert_called_once()
                self.assertFalse(self.ready.exists())

    def test_healthcheck_rejects_missing_invalid_and_dead_pid(self):
        self.assertFalse(advertise.healthy())
        for value in ("invalid", "0", "-1"):
            self.ready.write_text(value)
            self.assertFalse(advertise.healthy())
        self.ready.write_text("999999")
        with patch.object(os, "kill", side_effect=ProcessLookupError):
            self.assertFalse(advertise.healthy())


if __name__ == "__main__":
    unittest.main()
