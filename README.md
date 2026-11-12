# DoodleDrift

**A little adventure by Daywrite**

*A tiny ball. A world of possibilities. Draw your way forward.*

DoodleDrift is the existing offline Godot physics-puzzle game, now presented with
pastel landscapes, an expressive peach companion, Fredoka/Nunito typography and
five original layered soundscapes. Rolling, jumping, five physics inks, drawing,
resources, checkpoints, difficulty modes and the current 50-stage campaign remain.

## Play locally

Engine pin: **Godot 4.7.2 stable** (`.godot-version`). Import `project.godot` and
press **F5**, or use `Start-DoodleDrift.cmd` when the downloaded local engine is
present. No paid plugins, accounts or runtime network services are required.

| Action | Keyboard |
|---|---|
| Roll | A / D or Left / Right |
| Jump | Space / W / Up |
| Brake / fast fall | S / Down |
| Draw / resume | E / Tab |
| Choose ink | 1–5 in drawing mode |
| Undo | Z in drawing mode |
| Pause | P / Escape |
| Restart | R |

Touch controls support multiple fingers. Draw pauses the world. Unsupported ink
falls; structures supported at both ends can form anchored bridges. Different
ink materials change contact effects. Each puzzle defines its stock and legal
building zones. [Level-design template](docs/LEVEL_DESIGN_TEMPLATE.md) accepts a
sketch, plain-language design or precise JSON.

## Laptop browser preview

On this development machine the local preview is **http://localhost:8080/**.
Hard-refresh after rebuilding. Browser saving belongs to that origin and is
separate from desktop/Android saving.

```powershell
./tools/build-web.ps1
python tools/serve-web.py --port 8080
```

The script uses installed matching Web templates when available. Its local
fallback runs the exact official 4.7.2 live-editor WebAssembly runtime in game
mode, with the supplied isolation headers. Cached engine/SDK/runtime binaries
are excluded from Git and the source ZIP; a fresh checkout must install Godot's
export templates or provide the documented cached runtime. Gameplay assets,
fonts, music and effects are all local. Browser audio follows its user-gesture
policy; click Start playing and interact with the game to enable sound.

## Settings and audio

Master, Music, Ambience and SFX have independent controls, plus master mute.
Five original music/ambience pairs loop offline and crossfade between biomes.
Rapid changes reuse four decks; transient cues use a bounded eight-voice pool.
Rolling, drawing and regeneration sounds are throttled. App focus/background
changes suspend both layers and clear transient effects; quit drains the mixer.
UI scale, control size/opacity, hints, face and reduced motion are retained.

[Asset licenses](ASSET_LICENSES.md) include authentic Fredoka and Nunito OFL
copyright/license files and hashes. [Audio provenance](docs/DOODLEDRIFT_AUDIO.md)
describes the original synthesis, waveform tests and reproduction commands.

## Progress compatibility

Rebranding does **not** change `com.momentumquest.game`, release signing variables,
local progress filenames, the version-1 save schema or authenticated backup
magic. The previous desktop data directory is deliberately pinned:
`Godot/app_userdata/Momentum Quest` (lowercase `godot` on Linux). Windows before/
after probes returned exactly the same directory. Android retains its existing
application sandbox; Web retains `/userfs` and the same preview origin/pack name.

Older saves gain a default Ambience value without losing records or settings.
Legacy encrypted `.mqbackup` files remain supported. Local JSON is unencrypted;
portable backups use password-derived AES-CBC with encrypt-then-HMAC. Read
[save/backup format](docs/SAVE_FORMAT.md) for the precise limits and recovery rules.

## Testing

```powershell
./tools/run-tests.ps1
# Or pass an installed engine:
./tools/run-tests.ps1 -Godot 'C:/Godot/Godot_v4.7.2-stable_win64_console.exe'
```

Tests use isolated user-data directories. Python 3 is used for structural level,
audio-signal and manifest checks; Godot runs the production physics/UI/save/audio
suites. Historical bridge-only bots and earlier measurements do not establish
solvability or performance for today's mechanic-led campaign. Human timing-route
playtests remain necessary.

See the current [upgrade report](docs/DOODLEDRIFT_UPGRADE.md),
[UI QA](docs/DOODLEDRIFT_UI_QA.md), [visual QA](docs/DOODLEDRIFT_VISUAL_QA.md),
[audio QA](docs/DOODLEDRIFT_AUDIO.md) and [architecture](docs/ARCHITECTURE.md).
Earlier revision reports/screenshots are retained as historical evidence.

## Android builds

```powershell
./tools/build-android.ps1 -Configuration Debug
```

Supply `-Godot`, `-AndroidSdk`, `-JavaSdk` and `-TemplatesRoot` on a fresh machine.
The debug output is `builds/doodledrift-debug.apk`; the release preset produces
`builds/doodledrift-release.aab` when the owner's signing prerequisites exist.
Application ID, minimum/target SDK, ABI choices and signing interfaces are retained.
[Android release instructions](docs/ANDROID_RELEASE.md) cover the verified manifest
repair, signing, installation and remaining device/store checks.

No real-device FPS, audio interruption behavior or Play acceptance is inferred
from desktop tests. Production Billing and entitlement restoration remain
unfinished; debug builds expose all worlds for authoring. No purchase is faked.
Before publication, **DoodleDrift requires trademark and Google Play name/
availability checks**. No trademark clearance or store listing is claimed.

## Repository and distribution

Repository: https://github.com/Ranger10sam/daywrite-doodledrift

**`master` is the production branch.** This is an update to the existing game;
internal legacy class names and save identifiers are intentionally retained.
Use `python tools/package-source.py` to produce `builds/DoodleDrift-source.zip`.
SDKs, engine binaries, local saves, keys and generated builds are excluded.

Game code and original generated artwork/audio use [MIT](LICENSE). Fonts retain
their separate [SIL OFL licenses](ASSET_LICENSES.md). Godot is separately licensed
by its authors; see the [official license](https://godotengine.org/license/).
