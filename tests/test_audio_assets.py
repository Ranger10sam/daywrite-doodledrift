"""Signal checks for original bundled loops; no subjective listening claims."""
from array import array
import hashlib
import json
from pathlib import Path
import unittest
import wave

ROOT = Path(__file__).resolve().parents[1]
DIRECTORY = ROOT / "audio/generated"


class OriginalSoundscapeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads((DIRECTORY / "manifest.json").read_text())
        cls.signals = {}
        for record in cls.manifest["files"]:
            with wave.open(str(DIRECTORY / record["file"]), "rb") as stream:
                signal = array("h", stream.readframes(stream.getnframes()))
                cls.signals[record["file"]] = (record, stream.getparams(), signal)

    def test_ten_original_distinct_layers(self):
        self.assertEqual(len(self.signals), 10)
        self.assertEqual(len({record["sha256"] for record in self.manifest["files"]}), 10)
        self.assertEqual(len(self.manifest["biome_palettes"]), 5)
        self.assertIn("None", self.manifest["source_samples"])

    def test_pcm_headers_durations_and_manifest_hashes(self):
        for filename, (record, parameters, signal) in self.signals.items():
            with self.subTest(filename=filename):
                self.assertEqual((parameters.nchannels, parameters.sampwidth, parameters.framerate), (2, 2, 22050))
                self.assertAlmostEqual(parameters.nframes / parameters.framerate, record["seconds"], places=5)
                self.assertEqual(hashlib.sha256((DIRECTORY / filename).read_bytes()).hexdigest(), record["sha256"])
                self.assertEqual(len(signal), parameters.nframes * 2)

    def test_headroom_no_clipping_and_no_dc_offset(self):
        for filename, (record, _, signal) in self.signals.items():
            with self.subTest(filename=filename):
                peak = max(abs(value) for value in signal) / 32767
                mean = sum(signal) / len(signal) / 32767
                self.assertLessEqual(peak, 0.201)
                self.assertAlmostEqual(peak, record["peak"], delta=0.00004)
                self.assertLess(abs(mean), 0.003)
                self.assertGreater(record["rms"], 0.001)

    def test_loop_join_is_continuous_without_a_silent_gap(self):
        for filename, (_, _, signal) in self.signals.items():
            with self.subTest(filename=filename):
                for channel in (0, 1):
                    self.assertLess(abs(signal[channel] - signal[-2 + channel]) / 32767, 0.012)
                # The join contains meaningful audio rather than a whole-loop
                # fade-to-zero that would create a periodic audible dropout.
                edge = signal[:4410] + signal[-4410:]
                self.assertGreater(sum(abs(value) for value in edge) / len(edge), 6)

    def test_musical_and_environmental_periods_differ(self):
        for biome in self.manifest["biome_palettes"]:
            music = self.signals[biome + "_music.wav"][0]
            ambience = self.signals[biome + "_ambience.wav"][0]
            self.assertEqual(music["seconds"], 25.6)
            self.assertEqual(ambience["seconds"], 32.0)
            self.assertNotEqual(music["sha256"], ambience["sha256"])


if __name__ == "__main__":
    unittest.main()
