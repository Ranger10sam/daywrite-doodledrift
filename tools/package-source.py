"""Create a small source-only deliverable; never bundle SDKs or signing material."""
from pathlib import Path
import zipfile

root = Path(__file__).resolve().parent.parent
destination = root / "builds" / "DoodleDrift-source.zip"
allowed_roots = {"scripts", "scenes", "data", "assets", "shaders", "audio", "docs", "tests"}
allowed_files = {"project.godot", "export_presets.cfg", ".godot-version", ".gitignore", ".gitattributes", "README.md", "LICENSE", "ASSET_LICENSES.md", "Start-DoodleDrift.cmd"}
allowed_tools = {"run-tests.ps1", "run-puzzle-tests.ps1", "package-source.py", "build-android.ps1", "fix_android_manifest.py", "rasterize-splash.gd", "render_branding.gd", "render_companion_expressions.gd", "capture_doodledrift_worlds.gd", "build-web.ps1", "serve-web.py", "web-preview.html", ".gdignore"}
destination.parent.mkdir(exist_ok=True)
candidates = [root / name for name in allowed_files]
candidates += [root / "tools" / name for name in allowed_tools]
for directory in sorted(allowed_roots | {"android/icons"}):
    candidates.extend((root / directory).rglob("*"))
with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for path in sorted(candidates):
        if not path.is_file():
            continue
        relative = path.relative_to(root)
        parts = relative.parts
        eligible = len(parts) == 1 and path.name in allowed_files
        eligible |= parts[0] in allowed_roots
        eligible |= parts[0] == "android" and len(parts) > 1 and parts[1] == "icons"
        eligible |= parts[0] == "tools" and len(parts) == 2 and path.name in allowed_tools
        unwanted_log = path.suffix == ".log" and parts[:2] != ("docs", "results")
        if not eligible or "__pycache__" in parts or unwanted_log or path.suffix in {".import", ".jks", ".keystore", ".mqbackup", ".pyc"}:
            continue
        archive.write(path, Path("DoodleDrift") / relative)
with zipfile.ZipFile(destination) as archive:
    names = archive.namelist()
    assert "DoodleDrift/project.godot" in names
    assert "DoodleDrift/data/levels/campaign.json" in names
    assert not any("/android/build/" in name or "/tools/godot/" in name or name.endswith((".keystore", ".jks")) for name in names)
print(f"Packaged {len(names)} source files: {destination} ({destination.stat().st_size:,} bytes)")
