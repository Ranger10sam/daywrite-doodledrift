# Android build and publication

Engine pin: **Godot 4.7.2 stable**, official standard GDScript build. The local
debug export configuration was checked on **12 November 2026**.
The project uses Compatibility rendering, a fixed 60 Hz physics step, landscape
orientation, native Godot controls and physics, and no network service.

## What is configured

`export_presets.cfg` contains `Android Debug APK` and `Android Release AAB`. Debug
uses the official prebuilt APK template, whose inspected manifest has API 24
minimum and **API 36 target**. Release uses Gradle with explicit API 24/36 settings.
Debug includes arm64 and x86_64
for hardware/emulator testing; release includes arm64. Preserve `package/unique_name`
as `com.momentumquest.game` for updates to the existing application. Version name is `1.0.0`, version
code `1`; increase the code with every Play upload.

The project fixes landscape in `display/window/handheld/orientation=0`. Adaptive
foreground/background and monochrome launcher icons are original SVGs under
`android/icons/`; the central graphic stays within Android's safe circle. Android
splash uses the project icon and cream background. No internet, storage, microphone,
or tracking permissions are requested by these presets. The sole optional-control
permission is VIBRATE for opt-in touch haptics (disabled by default). Native user-selected backup
files should use Android's system document picker; confirm its behavior on device.

The AAB configuration and option names were checked against the [Godot 4.7.2
Android exporter source](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/android/export/export_plugin.cpp).
Source configuration alone does not establish Android build success.

## Install the build prerequisites

1. Install the exact Godot 4.7.2 export templates through **Editor > Manage Export
   Templates**. Do not mix engine and template versions.
2. Install OpenJDK 17 (recommended by Godot). JDK 21 exists on the development host
   but has not been verified against an Android Gradle build here.
3. Install Android Studio or Google's command-line tools. Install platform-tools,
   the Android 36 platform, and Android 36 build-tools; accept the SDK licenses.
   The official 4.7.2 Gradle template requests build-tools `36.1.0`, NDK
   `29.0.14206865`, and Gradle `8.11.1`; use its requested versions for AAB builds.
   The prebuilt debug APK export was verified using build-tools `36.0.0`.
4. In Godot **Editor Settings > Export > Android**, set **Java SDK Path** to the
   JDK and **Android SDK Path** to the SDK directory containing `platform-tools`.
5. Use **Project > Install Android Build Template**. Godot installs the generated
   Gradle project under `android/build`; do not hand-author an incomplete Gradle
   template. Generated caches and build outputs are excluded from game resources.

Godot's [Android export instructions](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)
and [Gradle template instructions](https://docs.godotengine.org/en/stable/tutorials/export/android_gradle_build.html)
describe this setup. Their SDK example may lag Play policy; this project's explicit
target is 36. Recheck [Play's target API
requirements](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en)
before upload; a local export is not a store-policy verification.

## Debug build and installation

From the project directory in PowerShell, after completing setup:

```powershell
& '.\tools\build-android.ps1' -Configuration Debug -Godot 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe' -AndroidSdk 'C:\Android\Sdk' -JavaSdk 'C:\JDK17'
```

The helper requires Python 3 and uses task-local editor settings, checks
prerequisites, creates only a development signing key, exports, repairs the
prebuilt template's provider authorities, aligns and signs the final APK, verifies
its signature, inspects its manifest, and writes a SHA-256 file. It accepts `-TemplatesRoot` when export templates are
not in Godot's standard location. SDKs, the engine, and private signing materials
are intentionally excluded from the source archive. An equivalent editor/CLI
export, after configuring Editor Settings normally, starts with:

```powershell
& '.\tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --export-debug 'Android Debug APK' 'builds/doodledrift-debug.apk'
adb devices
adb install -r '.\builds\doodledrift-debug.apk'
adb shell am start -n com.momentumquest.game/com.godot.game.GodotAppLauncher
```

For Godot 4.7.2, use the build helper for the delivered debug APK: a direct prebuilt
export needs the repair described below before installation. The final APK then
has unique FileProvider/AndroidX authorities and a complete adaptive icon resource.

### Godot 4.7.2 prebuilt-template repair

The pinned engine's [prebuilt manifest rewrite](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/android/export/export_plugin.cpp#L1282)
sets every provider authority to `<package>.fileprovider`, including AndroidX's
initialization provider. `tools/fix_android_manifest.py` repairs only that
provider's binary-XML reference to `<package>.androidx-startup` and checks that all
other attributes are unchanged. It fails on unexpected structures, checks unique
authorities, and is idempotent. It also restores the template's missing unused
`themed_icon.xml` alias using the existing valid adaptive-icon XML. Seven
regressions use an actual exported manifest fixture plus archive-integrity tests.

The build helper runs this repair, uses Android's `zipalign` with 16 KB native
alignment, re-signs with the development key, and verifies the final signature and
alignment. Editing an APK invalidates its previous signatures; the unsigned
intermediate is never the deliverable. The release AAB uses Gradle manifest merging
and is separate from this prebuilt debug workaround. Verify its final authorities
again when a real release signing configuration is available.

Use a release installation with matching signing keys for update tests. If an
installation reports a signature mismatch, do not casually uninstall the user's
game: that can remove its progress. Back up first or use a different debug package
ID. Debug builds intentionally expose all worlds for development; this is clearly
separated from release premium entitlements.

## Release signing and AAB

Create an upload keystore outside this repository with `keytool -genkeypair`; use
an RSA key of at least 2048 bits and preserve secure independent backups. Enter
passwords interactively or through a secret manager, never in committed scripts or
command history. Set Godot's Release Keystore/User/Password fields or inject the
documented environment variables `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`,
`GODOT_ANDROID_KEYSTORE_RELEASE_USER`, and `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`
into the build process. This repository contains no keystore or signing password.

Then export without debug:

```powershell
& '.\tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --export-release 'Android Release AAB' 'builds/doodledrift-release.aab'
```

The helper also supports `-Configuration Release`; it requires all three release
signing environment variables before exporting and does not create a release key.

Inspect the resulting manifest, SDK levels, permissions, ABI coverage, signatures,
and packaged resources with Android tooling. An AAB is uploaded to Play; install
APK sets generated with Google's bundletool or distribute through a Play test
track. Enroll in Play App Signing and keep the upload key separate from the
Play-managed app-signing key according to Google's current guidance.

## Work required before Play publication

- Connect and test the production Billing adapter. Release currently gives free
  access to Green Valley; purchasing/restoring premium returns an explicit
  unavailable message. No client save or imported backup grants premium.
- Complete real-device testing on representative mid-range Android hardware and
  tablets: frame time, heat, touch latency/multitouch, safe areas, 16:9 through
  wider displays, orientation, audio interruption, background/resume, low memory,
  offline starts, and system document-picker backup round trips.
- Human-play all 50 levels in each difficulty. Analytic route checks and loading
  tests are useful but do not establish complete puzzle playability.
- Run a Play internal test, then any closed testing required for the developer
  account; resolve pre-launch report crashes and compatibility findings before
  production rollout.
- Prepare original screenshots from real gameplay, store icon/feature graphic,
  short/full descriptions, support contact, content rating, target audience,
  Data safety declarations, privacy policy, premium-product details, and accurate
  disclosures. Review family/children policies before choosing child audiences.

## Observed Android export status

**A debug APK was actually exported successfully** with Godot 4.7.2, returning
exit code 0. `builds/doodledrift-debug.apk` is 65,489,675 bytes at the time of
this verification. Android's `apksigner verify --verbose` verifies its v2 and v3
signatures with one development signer. `aapt2 dump badging` confirms:

- Application ID `com.momentumquest.game`, version code `1`, version `1.0.0`.
- Minimum SDK `24`, target and compile SDK `36`.
- Landscape screen requirement; arm64-v8a and x86_64 native libraries.
- The sole permission is `android.permission.VIBRATE` for optional haptics.

ZIP inspection confirms all 50 campaign definitions, the biome/ink/physics JSON,
ten offline audio loops, all four font license notices and project licenses,
and no packaged `tools/`, `tests/`, `docs/`, `builds/`, `output/` or QA-profile paths.
The four current game JSON files match the source bytes. The debug signer matches
the previous build's certificate. The final manifest
has distinct FileProvider and AndroidX initialization authorities. Its adaptive
icon and themed-icon alias exist; `aapt2` reports no missing icon resource after
the repair. Launcher appearance still needs a real-device check. Alignment with
16 KB native-library pages and the final v2/v3 signatures are verified.

Verification evidence lives in `builds/android-export-debug.log`,
`builds/android-signature-verification.log`, `builds/android-manifest-verification.log`,
and `builds/android-sha256.txt`. Rebuilding changes the digest and possibly size;
use the accompanying checksum file for the delivered binary.

The first export failed because the machine had no templates/SDK settings and
managed AppData writes were denied. Dependencies were then installed in `tools/`
and Godot's AppData directories redirected there, preserving global user settings.
The official command-line tools SHA-256 and Android SDK package SHA-1 values match
Google's metadata. The 1.28 GB official Godot template download was interrupted
after 613 MB, but its three complete Android members were extracted and their
ZIP CRC and size checked; downloading the remainder and retrieving the complete
archive's SHA-512 failed due remote connection resets. These dependencies came
directly from official HTTPS origins. The complete Android Gradle source template
is installed under `android/build/` locally and excluded from the source package.

There is **no production release AAB or release signing key**, and no verified
Android installation, device gameplay test, or frame-rate measurement. A signed
debug APK is a build artifact, not Play readiness. Use the release prerequisites
and device QA above before distribution.

A task-local `adb devices -l` check completed successfully and found no attached
devices. Its temporary server was then stopped. The manifest exports the launcher
alias `com.godot.game.GodotAppLauncher`; the underlying `GodotApp` activity is
internal, so use the alias when launching through `adb`.
