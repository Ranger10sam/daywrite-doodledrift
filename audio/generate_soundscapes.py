"""Original DoodleDrift music/ambience; pure Python, deterministic, no samples.

Run from any directory: python audio/generate_soundscapes.py
Output is stereo, 22,050 Hz, 16-bit PCM. Events wrap around each cyclic buffer,
and wind filters are warmed over a whole period, so loops have no fade-to-silence
gap or discontinuous tail. All compositions and synthesized sounds are original
project work, released under the project's MIT license.
"""
from array import array
import hashlib
import json
import math
from pathlib import Path
import random
import sys
import wave

RATE = 22050
TAU = math.tau
OUTPUT = Path(__file__).resolve().parent / "generated"
BIOMES = ["valley", "peaks", "desert", "caverns", "volcano"]
DESCRIPTIONS = [
    "Felt keys, open major harmony, soft birds, leaf-like wind",
    "Sparse glass bells, open fifths, airy mountain wind, distant tinkles",
    "Warm plucked strings, Dorian colour, soft sand grains, a low warm drone",
    "Shimmering glass, suspended minor harmony, quiet drops with stereo echoes",
    "Rounded marimba-like tones, low warm harmony, gentle bubbles and soft flow",
]


def track(seconds):
    length = round(seconds * RATE)
    return array("f", [0.0]) * length, array("f", [0.0]) * length


def midi(note):
    return 440.0 * 2.0 ** ((note - 69.0) / 12.0)


def note(buffers, onset, duration, frequency, gain, timbre="felt", pan=0.0):
    left, right = buffers
    start, count = round(onset * RATE), round(duration * RATE)
    l_gain = math.sqrt((1.0 - pan) * 0.5) * gain
    r_gain = math.sqrt((1.0 + pan) * 0.5) * gain
    for i in range(count):
        t = i / RATE
        fraction = i / max(1, count - 1)
        attack = min(1.0, t / 0.012)
        # The final eased tail is exactly zero, including wrapped echo tails.
        envelope = attack * math.exp(-4.2 * fraction) * (1.0 - fraction) ** 2
        phase = TAU * frequency * t
        if timbre == "bell":
            value = math.sin(phase) + 0.24 * math.sin(phase * 2.01) * math.exp(-3 * fraction)
            value += 0.10 * math.sin(phase * 3.98) * math.exp(-6 * fraction)
        elif timbre == "pluck":
            value = math.sin(phase) + 0.27 * math.sin(phase * 2) + 0.11 * math.sin(phase * 3)
            envelope *= math.exp(-1.3 * fraction)
        elif timbre == "glass":
            value = math.sin(phase) + 0.19 * math.sin(phase * 2.002) + 0.07 * math.sin(phase * 3.0)
        elif timbre == "rounded":
            value = math.sin(phase) + 0.21 * math.sin(phase * 2) * math.exp(-5 * fraction)
        else:
            value = math.sin(phase) + 0.12 * math.sin(phase * 2) + 0.035 * math.sin(phase * 3)
        position = (start + i) % len(left)
        left[position] += value * envelope * l_gain
        right[position] += value * envelope * r_gain


def bird(buffers, onset, gain, pan, seed):
    randomizer = random.Random(seed)
    frequency = randomizer.uniform(1400, 1850)
    duration = randomizer.uniform(0.18, 0.28)
    left, right = buffers
    count, start = round(duration * RATE), round(onset * RATE)
    for i in range(count):
        t = i / RATE
        x = i / max(1, count - 1)
        envelope = math.sin(math.pi * x) ** 2
        # A modest curved chirp, intentionally quieter than any gameplay cue.
        phase = TAU * (frequency * t + 350 * t * t + 13 * math.sin(t * 32))
        value = math.sin(phase) * envelope * gain
        position = (start + i) % len(left)
        left[position] += value * math.sqrt((1 - pan) * 0.5)
        right[position] += value * math.sqrt((1 + pan) * 0.5)


def filtered_wind(buffers, seed, cutoff, gain, gusts):
    left, right = buffers
    randomizer = random.Random(seed)
    noise = array("f", (randomizer.uniform(-1, 1) for _ in left))
    coefficient = 1.0 - math.exp(-TAU * cutoff / RATE)
    state = 0.0
    for value in noise:  # Periodic steady state before writing the loop.
        state += coefficient * (value - state)
    slow = 0.0
    for i, value in enumerate(noise):
        state += coefficient * (value - state)
        slow += 0.00015 * (state - slow)
        phase = TAU * i / len(left)
        gust = 0.62 + 0.22 * math.sin(phase * gusts + 0.3) + 0.12 * math.sin(phase * 2 + 1.1)
        value = (state - slow * 0.3) * gust * gain
        left[i] += value * (0.85 + 0.12 * math.sin(phase * 3))
        right[i] += value * (0.85 + 0.12 * math.cos(phase * 3))
    # The secondary very-slow filter also needs a cyclic warm state. Its initial
    # contribution is tiny; a local four-millisecond cyclic blend removes any
    # residual DC mismatch without fading either end to silence.
    blend = round(RATE * 0.004)
    for channel in buffers:
        seam = (channel[0] + channel[-1]) * 0.5
        first_delta = seam - channel[0]
        last_delta = seam - channel[-1]
        for i in range(blend):
            weight = (1.0 - i / blend) ** 2
            channel[i] += first_delta * weight
            channel[-1 - i] += last_delta * weight


def drone(buffers, frequencies, gain, cycles=2):
    left, right = buffers
    seconds = len(left) / RATE
    # Quantizing each oscillator to an integer number of cycles closes its phase.
    frequencies = [round(f * seconds) / seconds for f in frequencies]
    for i in range(len(left)):
        t = i / RATE
        phase = TAU * i / len(left)
        envelope = 0.7 + 0.3 * math.sin(phase * cycles + 0.7)
        value = sum(math.sin(TAU * f * t + j * 0.25) / (j + 1) for j, f in enumerate(frequencies)) * gain * envelope
        left[i] += value * (0.8 + 0.15 * math.sin(phase))
        right[i] += value * (0.8 + 0.15 * math.cos(phase))


def bubble(buffers, onset, frequency, gain, pan):
    left, right = buffers
    duration = 0.34
    count, start = round(duration * RATE), round(onset * RATE)
    for i in range(count):
        t = i / RATE
        x = i / max(1, count - 1)
        envelope = math.sin(math.pi * x) ** 2 * math.exp(-2 * x)
        value = math.sin(TAU * (frequency * t + 130 * t * t)) * envelope * gain
        position = (start + i) % len(left)
        left[position] += value * math.sqrt((1 - pan) * 0.5)
        right[position] += value * math.sqrt((1 + pan) * 0.5)


def music(index):
    buffers = track(25.6)  # Eight bars, 75 BPM. Ambience has a different period.
    chord_sets = [
        [[48, 55, 60, 64], [53, 60, 65, 69], [45, 52, 57, 60], [55, 62, 67, 71]],
        [[50, 57, 62, 66], [55, 62, 67, 71], [47, 54, 59, 62], [57, 64, 69, 73]],
        [[45, 52, 57, 60], [50, 57, 62, 65], [48, 55, 60, 64], [43, 50, 55, 59]],
        [[48, 55, 60, 63], [44, 51, 56, 60], [46, 53, 58, 62], [55, 62, 67, 70]],
        [[43, 50, 55, 58], [48, 55, 60, 63], [46, 53, 58, 62], [41, 48, 53, 57]],
    ]
    melodies = [
        [72, 76, 79, 76, 74, 72, 69, 67, 72, 74, 76, 79, 76, 74, 72, 67],
        [78, 81, 85, 81, 78, 74, 73, 69, 74, 78, 81, 85, 83, 81, 78, 74],
        [69, 72, 76, 74, 72, 69, 67, 65, 64, 67, 72, 74, 72, 69, 67, 64],
        [72, 75, 79, 82, 79, 75, 72, 70, 68, 72, 75, 79, 77, 75, 72, 67],
        [67, 70, 74, 72, 70, 67, 65, 62, 63, 67, 70, 74, 72, 70, 67, 62],
    ]
    timbre = ["felt", "bell", "pluck", "glass", "rounded"][index]
    for bar in range(8):
        chord = chord_sets[index][bar // 2]
        onset = bar * 3.2
        note(buffers, onset, 3.8, midi(chord[0]), 0.055, "felt", -0.12)
        for offset, chord_note in enumerate(chord[1:]):
            note(buffers, onset + offset * 0.35, 3.5, midi(chord_note), 0.026, timbre, (offset - 1) * 0.32)
        for step in range(2):
            melody_note = melodies[index][bar * 2 + step]
            time = onset + 0.4 + step * 1.6
            note(buffers, time, 2.6, midi(melody_note), 0.065, timbre, 0.25 if step else -0.25)
            if index == 3:
                for delay, attenuation in [(0.29, 0.22), (0.61, 0.09)]:
                    note(buffers, time + delay, 2.6, midi(melody_note), 0.065 * attenuation, timbre, -0.45 if step else 0.45)
        if index == 2:
            note(buffers, onset + 2.4, 1.2, midi(chord[2] + 12), 0.031, "pluck", 0.35)
    return buffers


def ambience(index):
    buffers = track(32.0)
    randomizer = random.Random(4010 + index)
    filtered_wind(buffers, 9001 + index, [90, 190, 450, 55, 80][index], [0.10, 0.12, 0.075, 0.065, 0.10][index], [3, 4, 5, 2, 3][index])
    if index == 0:
        for i in range(9):
            onset = 0.5 + i * 3.45 + randomizer.uniform(-0.35, 0.35)
            pan = randomizer.uniform(-0.65, 0.65)
            bird(buffers, onset, 0.014, pan, 540 + i)
            bird(buffers, onset + 0.27, 0.008, pan, 550 + i)
    elif index == 1:
        for i in range(7):
            note(buffers, i * 4.4 + 1.3, 3.0, midi([86, 81, 90, 85][i % 4]), 0.011, "bell", randomizer.uniform(-0.7, 0.7))
        drone(buffers, [196, 294], 0.0016, 3)
    elif index == 2:
        drone(buffers, [110, 165, 220], 0.005, 2)
        for i in range(24):
            bubble(buffers, i * 1.3 + randomizer.uniform(0, 0.35), randomizer.uniform(200, 330), 0.0025, randomizer.uniform(-0.6, 0.6))
    elif index == 3:
        drone(buffers, [196, 294, 392], 0.003, 4)
        for i in range(12):
            onset = i * 2.6 + 0.8
            pitch = midi([67, 72, 75, 79, 70][i % 5])
            for delay, gain, pan in [(0, 0.011, -0.4), (0.27, 0.005, 0.4), (0.62, 0.002, -0.1)]:
                note(buffers, onset + delay, 1.6, pitch, gain, "glass", pan)
    else:
        drone(buffers, [98, 147, 196], 0.0045, 2)
        for i in range(34):
            bubble(buffers, i * 0.94 + randomizer.uniform(-0.3, 0.3), randomizer.uniform(78, 160), randomizer.uniform(0.009, 0.018), randomizer.uniform(-0.6, 0.6))
    return buffers


def write(name, buffers, target_peak):
    peak = max(max(abs(x) for x in channel) for channel in buffers)
    gain = target_peak / max(0.00001, peak)
    samples = array("h")
    sum_squares = 0.0
    for left, right in zip(*buffers):
        for value in (left, right):
            value *= gain
            samples.append(round(value * 32767))
            sum_squares += value * value
    if sys.byteorder != "little":
        samples.byteswap()
    path = OUTPUT / name
    with wave.open(str(path), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(samples.tobytes())
    seam = max(abs(channel[0] - channel[-1]) * gain for channel in buffers)
    return {"file": name, "seconds": len(buffers[0]) / RATE, "sample_rate": RATE,
            "channels": 2, "peak": target_peak, "rms": (sum_squares / len(samples)) ** 0.5,
            "loop_join_delta": seam, "bytes": path.stat().st_size,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def main():
    OUTPUT.mkdir(exist_ok=True)
    records = []
    for index, biome in enumerate(BIOMES):
        records.append(write(f"{biome}_music.wav", music(index), 0.20))
        records.append(write(f"{biome}_ambience.wav", ambience(index), 0.11))
        print(f"Generated original {biome} music and ambience", flush=True)
    manifest = {"name": "DoodleDrift original soundscapes", "license": "MIT (project license)",
                "generator": "audio/generate_soundscapes.py; Python standard library only",
                "source_samples": "None. All oscillators, noise, notes, and events synthesized from code.",
                "biome_palettes": dict(zip(BIOMES, DESCRIPTIONS)), "files": records}
    (OUTPUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    main()
