# DoodleDrift audio

The soundscapes and effects are original project work generated from code. No
recordings, commercial assets, third-party music, APIs, or downloaded audio samples
are used. They are included under the project's MIT license. The separate font
and visual-asset license inventory is maintained in the
[asset license inventory](../ASSET_LICENSES.md).

| Biome | Music | Environmental layer |
|---|---|---|
| Green Valley | Soft felt-key melody and open major chords | Light wind and restrained, distant bird-like chirps |
| Frozen Peaks | Sparse glass bells and open fifths | Airy mountain wind and very quiet distant tinkles |
| Desert Winds | Warm plucked notes with Dorian colour | Sand-like wind grains and a low warm drone |
| Crystal Caverns | Suspended minor harmony and shimmering glass | Quiet drops, stereo echoes and soft resonances |
| Volcanic Core | Rounded marimba-like notes and low warm harmony | Gentle bubbles and soft flowing noise |

`audio/generate_soundscapes.py` uses only the Python standard library and fixed
seeds. Running it regenerates the ten bundled stereo 22,050 Hz 16-bit WAVs in
`audio/generated/`. The game loads those files locally and does not run Python or
synthesize long soundscapes during gameplay. The generator records provenance,
SHA-256 digests, durations, peak/RMS levels and loop-join deltas in
`audio/generated/manifest.json`.

Music loops span 25.6 seconds (eight bars at 75 BPM); ambience loops span 32
seconds. Their differing periods make the combined scene repeat less often.
Notes, birds, bubbles and echo tails wrap around the cyclic buffer. Low-pass wind
is warmed to its periodic state, and its tiny residual boundary offset is blended
locally without fading the soundscape to silence. Oscillator drones complete an
integer number of cycles. Music has 0.20 full-scale peak and ambience 0.11 before
bus gains, leaving headroom for gameplay effects.

`AudioManager` keeps exactly two Music decks, two Ambience decks and eight SFX
voices. Biome changes use a 0.9-second eased, equal-power crossfade. Requests during
a fade retain only the latest requested biome; the current fade finishes before
the next begins. This preserves audible tails without allocating additional
players or abruptly replacing an audible deck. Finished outgoing decks are stopped
and their streams cleared. Cache size is bounded to five music and five ambience
streams.

Master volume/mute and Music, Ambience and SFX gains are independent. The new
`ambience` preference defaults to 0.35 when an older schema-1 save lacks it. Existing
Music, SFX, settings, records, tutorials, cosmetics and progression remain intact.
The backup format marker, version, cryptographic construction and progress filenames
retain their previous values. An independently generated pre-rebrand encrypted
fixture verifies import after the public name changes.

`play_sfx(name, intensity)` supports all existing cues plus gentle rolling,
accepted-segment drawing and regeneration textures. Repeated rolling/drawing/regen
requests are throttled at 180/95/1450 milliseconds. Quiet continuous cues do not
steal voices from gameplay effects. Root gameplay hooks call them only while the
corresponding action occurs. `suspend_audio()` pauses every music/ambience deck and
stops transient voices; `resume_audio()` resumes the same playback positions and
continues the interrupted transition.

Application quit paths can await `prepare_shutdown()`. It prevents new playback,
releases streams and asynchronously lets the mixer retire its references for a
bounded 150 milliseconds. Direct native tree shutdown also has a 120-millisecond
teardown-only fallback; it never runs during gameplay. This fixes the pinned
engine's immediate-quit PCM reference warnings. Web uses the asynchronous path.

Browsers require a user gesture before Web Audio can play. The preview's Start
button and subsequent game input supply normal browser gestures; a browser or OS
mute policy can still suppress output. No code bypasses that policy.

Verification covers actual PCM headers, hashes, signal headroom/DC/loop joins,
distinct layers, bus routing, crossfade energy and bounded player counts, rapid
switching, suspend/resume, effect throttling, old saves and old encrypted backups.
Headless tests cannot establish subjective sound quality, audible device output,
latency, or Android/browser interruption behavior. Those require listening and
device QA.
