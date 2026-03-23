from pathlib import Path
import sys
import unittest
from unittest import mock


PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

import printer_harness


class PrinterHarnessTests(unittest.TestCase):
    def test_filter_preset_options_safe_subset_keeps_auth_and_duplex(self) -> None:
        valid_options = {
            "CNDuplex",
            "CNAuthenticate",
            "number-up",
            "Resolution",
        }
        settings = {
            "CNDuplex": "DuplexFront",
            "CNAuthenticate": "True",
            "CNUsrName": "encoded-user",
            "CNUsrPassword": "encoded-pass",
            "CNJobAccount": "encoded-job-account",
            "number-up": "2",
            "Resolution": "600",
        }

        filtered = printer_harness.filter_preset_options(settings, valid_options, safe_only=True)

        self.assertEqual(
            filtered,
            {
                "CNDuplex": "DuplexFront",
                "CNAuthenticate": "True",
                "CNJobAccount": "encoded-job-account",
                "CNUsrName": "encoded-user",
                "CNUsrPassword": "encoded-pass",
                "Resolution": "600",
            },
        )

    def test_build_install_steps_adds_lpadmin_and_lpoptions(self) -> None:
        steps = printer_harness.build_install_steps(
            queue_name="Canon_iR-ADV_DX_C3826",
            printer_uri="ipp://10.0.0.50/ipp/print",
            printer_info="Canon iR-ADV DX C3826",
            location="6F",
            ppd_path=Path("/Library/Printers/PPDs/Contents/Resources/CNPZUIRAC3826ZU.ppd.gz"),
            options={"CNDuplex": "DuplexFront", "sides": "two-sided-long-edge"},
        )

        self.assertEqual(len(steps), 2)
        self.assertTrue(steps[0].requires_admin)
        self.assertIn("ipp://10.0.0.50/ipp/print", steps[0].argv)
        self.assertEqual(
            steps[1].argv,
            [
                printer_harness.LPOPTIONS,
                "-p",
                "Canon_iR-ADV_DX_C3826",
                "-o",
                "CNDuplex=DuplexFront",
                "-o",
                "sides=two-sided-long-edge",
            ],
        )

    def test_build_print_step_includes_duplex_and_copies(self) -> None:
        step = printer_harness.build_print_step(
            queue_name="Canon_iR-ADV_DX_C3826",
            file_path=Path("/tmp/sample.pdf"),
            copies=2,
            options={
                "CNAuthenticate": "True",
                "CNDuplex": "DuplexFront",
                "sides": "two-sided-long-edge",
            },
        )

        self.assertEqual(
            step.argv,
            [
                printer_harness.LP,
                "-d",
                "Canon_iR-ADV_DX_C3826",
                "-n",
                "2",
                "-o",
                "CNAuthenticate=True",
                "-o",
                "CNDuplex=DuplexFront",
                "-o",
                "sides=two-sided-long-edge",
                "/tmp/sample.pdf",
            ],
        )

    def test_duplex_options_handles_one_sided(self) -> None:
        self.assertEqual(
            printer_harness.duplex_options("one-sided"),
            {"CNDuplex": "None", "sides": "one-sided"},
        )

    def test_discover_ppd_path_prefers_preset_declared_ppd(self) -> None:
        preset = printer_harness.Preset(
            source_id="global-vendor-default",
            label="Vendor default settings",
            settings={"CNPDECALL": "CNPZUIRAC3926ZU"},
        )

        real_exists = Path.exists

        def fake_exists(path: Path) -> bool:
            if str(path).endswith("CNPZUIRAC3926ZU.ppd.gz"):
                return True
            return real_exists(path)

        with mock.patch.object(Path, "exists", fake_exists):
            ppd_path = printer_harness.discover_ppd_path(None, preset)

        self.assertEqual(
            str(ppd_path),
            "/Library/Printers/PPDs/Contents/Resources/CNPZUIRAC3926ZU.ppd.gz",
        )


if __name__ == "__main__":
    unittest.main()
