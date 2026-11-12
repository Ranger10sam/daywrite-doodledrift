"""Regression for Godot's actual exported duplicate-authority manifest fixture."""
from pathlib import Path
import importlib.util
import uuid
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("fix_android_manifest", ROOT / "tools/fix_android_manifest.py")
FIX = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(FIX)
FIXTURE = ROOT / "tests/fixtures/android_manifest_duplicate.axml"


class ManifestRepairTests(unittest.TestCase):
    def setUp(self):
        self.manifest = FIXTURE.read_bytes()

    def test_repairs_real_exported_fixture(self):
        before = FIX.provider_authorities(self.manifest)
        self.assertEqual(len(before.values()), 2)
        self.assertEqual(len(set(before.values())), 1)
        after = FIX.provider_authorities(FIX.repair_manifest(self.manifest))
        self.assertEqual(after[FIX.FILE_PROVIDER], "com.momentumquest.game.fileprovider")
        self.assertEqual(after[FIX.TARGET_PROVIDER], "com.momentumquest.game.androidx-startup")
        self.assertEqual(len(after.values()), len(set(after.values())))

    def test_repair_is_idempotent(self):
        repaired = FIX.repair_manifest(self.manifest)
        self.assertEqual(FIX.repair_manifest(repaired), repaired)

    def test_truncated_manifest_fails_closed(self):
        with self.assertRaises(ValueError):
            FIX.repair_manifest(self.manifest[:-5])

    def test_wrong_binary_xml_type_fails_closed(self):
        with self.assertRaises(ValueError):
            FIX.repair_manifest(b"no" + self.manifest[2:])

    def test_missing_known_provider_fails_closed(self):
        malformed = self.manifest.replace(
            FIX.TARGET_PROVIDER.encode("utf-16le"),
            (FIX.TARGET_PROVIDER[:-1] + "X").encode("utf-16le"),
        )
        with self.assertRaises(ValueError):
            FIX.repair_manifest(malformed)

    def test_rebuild_preserves_assets_and_removes_stale_signatures(self):
        token = uuid.uuid4().hex
        original = ROOT / "tests" / f".manifest-{token}-original.apk"
        output = ROOT / "tests" / f".manifest-{token}-fixed.apk"
        try:
            with zipfile.ZipFile(original, "w") as archive:
                archive.writestr("AndroidManifest.xml", self.manifest)
                archive.writestr("assets/game.dat", b"unchanged game payload")
                archive.writestr("res/mipmap-anydpi-v26/icon.xml", b"adaptive icon fixture")
                archive.writestr("META-INF/STALE.RSA", b"stale signature")
                archive.writestr("META-INF/STALE.SF", b"stale signature metadata")
                archive.writestr("META-INF/MANIFEST.MF", b"stale JAR manifest")
            FIX.repair_apk(original, output)
            with zipfile.ZipFile(output) as archive:
                self.assertIsNone(archive.testzip())
                self.assertEqual(archive.read("assets/game.dat"), b"unchanged game payload")
                self.assertEqual(archive.read("res/mipmap-anydpi-v26/themed_icon.xml"), b"adaptive icon fixture")
                self.assertNotIn("META-INF/STALE.RSA", archive.namelist())
                self.assertNotIn("META-INF/STALE.SF", archive.namelist())
                self.assertNotIn("META-INF/MANIFEST.MF", archive.namelist())
                authorities = FIX.provider_authorities(archive.read("AndroidManifest.xml"))
                self.assertEqual(len(authorities), len(set(authorities.values())))
        finally:
            original.unlink(missing_ok=True)
            output.unlink(missing_ok=True)

    def test_input_output_must_differ(self):
        with self.assertRaises(ValueError):
            FIX.repair_apk(FIXTURE, FIXTURE)


if __name__ == "__main__":
    unittest.main()
