"""Repair Godot 4.7.2 prebuilt APK provider authorities before re-signing.

The upstream prebuilt exporter rewrites every provider authority to
<package>.fileprovider. AndroidX's initialization provider must retain its own
<package>.androidx-startup authority. This narrowly edits that provider's binary
XML string reference, preserves every other attribute, and fails closed for an
unexpected manifest. The caller MUST zipalign and sign the returned APK again.
"""
from __future__ import annotations

import argparse
import copy
from pathlib import Path
import re
import struct
import zipfile

NO_INDEX = 0xFFFFFFFF
TARGET_PROVIDER = "androidx.startup.InitializationProvider"
FILE_PROVIDER = "androidx.core.content.FileProvider"


def u16(data: bytes, offset: int) -> int:
    return struct.unpack_from("<H", data, offset)[0]


def u32(data: bytes, offset: int) -> int:
    return struct.unpack_from("<I", data, offset)[0]


def chunks(data: bytes):
    if len(data) < 8 or u16(data, 0) != 3 or u16(data, 2) != 8 or u32(data, 4) != len(data):
        raise ValueError("Unsupported or truncated Android binary XML")
    position = 8
    while position < len(data):
        if position + 8 > len(data):
            raise ValueError("Truncated binary XML chunk")
        kind, header_size, size = struct.unpack_from("<HHI", data, position)
        if header_size < 8 or size < header_size or position + size > len(data):
            raise ValueError("Invalid binary XML chunk bounds")
        yield position, kind, header_size, size
        position += size


def length8(data: bytes, position: int) -> tuple[int, int]:
    first = data[position]
    if first & 0x80:
        return ((first & 0x7F) << 8) | data[position + 1], position + 2
    return first, position + 1


def length16(data: bytes, position: int) -> tuple[int, int]:
    first = u16(data, position)
    if first & 0x8000:
        return ((first & 0x7FFF) << 16) | u16(data, position + 2), position + 4
    return first, position + 2


def read_pool(data: bytes):
    pools = [item for item in chunks(data) if item[1] == 1]
    if len(pools) != 1:
        raise ValueError("Expected exactly one XML string pool")
    position, _, header_size, size = pools[0]
    if header_size < 28:
        raise ValueError("Unsupported XML string-pool header")
    pool = data[position:position + size]
    count, styles, flags, strings_start, styles_start = struct.unpack_from("<5I", pool, 8)
    if styles != 0 or styles_start != 0 or count > 10000:
        raise ValueError("Styled or excessive XML string pool is not supported")
    if strings_start < header_size + count * 4 or strings_start > len(pool):
        raise ValueError("Invalid XML string-pool offsets")
    utf8 = bool(flags & 0x100)
    strings = []
    for index in range(count):
        offset = strings_start + u32(pool, header_size + index * 4)
        if offset >= len(pool):
            raise ValueError("XML string points outside its pool")
        if utf8:
            _, offset = length8(pool, offset)
            size_bytes, offset = length8(pool, offset)
            end = offset + size_bytes
            if end >= len(pool) or pool[end] != 0:
                raise ValueError("Invalid UTF-8 XML string")
            strings.append(pool[offset:end].decode("utf-8"))
        else:
            count_units, offset = length16(pool, offset)
            end = offset + count_units * 2
            if end + 2 > len(pool) or pool[end:end + 2] != b"\0\0":
                raise ValueError("Invalid UTF-16 XML string")
            strings.append(pool[offset:end].decode("utf-16le"))
    return pools[0], pool, strings, utf8


def attributes(data: bytes, strings: list[str]):
    result = []
    for position, kind, header_size, size in chunks(data):
        if kind != 0x102:
            continue
        if header_size != 16 or size < 36:
            raise ValueError("Unsupported XML start-element header")
        tag = strings[u32(data, position + 20)]
        attribute_start = u16(data, position + 24)
        attribute_size = u16(data, position + 26)
        count = u16(data, position + 28)
        if attribute_size != 20 or 16 + attribute_start + count * 20 > size:
            raise ValueError("Unsupported XML attribute layout")
        values = {}
        offsets = {}
        for index in range(count):
            offset = position + 16 + attribute_start + index * attribute_size
            name = strings[u32(data, offset + 4)]
            raw = u32(data, offset + 8)
            value_type = data[offset + 15]
            typed_value = u32(data, offset + 16)
            value = strings[typed_value] if value_type == 3 else typed_value
            if raw != NO_INDEX:
                value = strings[raw]
            values[name] = value
            offsets[name] = offset
        result.append((tag, values, offsets))
    return result


def provider_authorities(data: bytes) -> dict[str, str]:
    _, _, strings, _ = read_pool(data)
    return {str(values["name"]): str(values["authorities"])
            for tag, values, _ in attributes(data, strings) if tag == "provider"}


def append_string(pool: bytes, text: str, utf8: bool) -> bytes:
    header_size = u16(pool, 2)
    count, _, flags, strings_start, _ = struct.unpack_from("<5I", pool, 8)
    encoded = text.encode("utf-8" if utf8 else "utf-16le")
    units = len(text.encode("utf-16le")) // 2
    if utf8:
        if units >= 128 or len(encoded) >= 128:
            raise ValueError("Authority exceeds the narrow UTF-8 repair limit")
        added = bytes([units, len(encoded)]) + encoded + b"\0"
    else:
        if units >= 0x8000:
            raise ValueError("Authority is too long")
        added = struct.pack("<H", units) + encoded + b"\0\0"
    old_data = pool[strings_start:]
    offsets_and_padding = pool[header_size:strings_start]
    header = bytearray(pool[:header_size])
    struct.pack_into("<I", header, 8, count + 1)
    struct.pack_into("<I", header, 16, flags & ~1)  # Appending clears SORTED.
    struct.pack_into("<I", header, 20, strings_start + 4)
    rebuilt = header + offsets_and_padding + struct.pack("<I", len(old_data)) + old_data + added
    rebuilt.extend(b"\0" * (-len(rebuilt) % 4))
    struct.pack_into("<I", rebuilt, 4, len(rebuilt))
    return bytes(rebuilt)


def repair_manifest(data: bytes) -> bytes:
    pool_info, pool, strings, utf8 = read_pool(data)
    elements = attributes(data, strings)
    manifests = [values for tag, values, _ in elements if tag == "manifest"]
    if len(manifests) != 1 or not re.fullmatch(r"[A-Za-z][A-Za-z0-9_.]*", str(manifests[0].get("package", ""))):
        raise ValueError("Unexpected Android package name")
    package = str(manifests[0]["package"])
    providers = [(values, offsets) for tag, values, offsets in elements if tag == "provider"]
    targets = [(values, offsets) for values, offsets in providers if values.get("name") == TARGET_PROVIDER]
    file_providers = [values for values, _ in providers if values.get("name") == FILE_PROVIDER]
    if len(targets) != 1 or len(file_providers) != 1:
        raise ValueError("Expected exactly one FileProvider and one AndroidX initialization provider")
    expected_file = package + ".fileprovider"
    wanted_authority = package + ".androidx-startup"
    target_values, target_offsets = targets[0]
    if file_providers[0].get("authorities") != expected_file:
        raise ValueError("Unexpected FileProvider authority")
    if target_values.get("authorities") not in (expected_file, wanted_authority):
        raise ValueError("Unexpected initialization-provider authority")
    if target_values["authorities"] == wanted_authority:
        authorities = list(provider_authorities(data).values())
        if len(authorities) != len(set(authorities)):
            raise ValueError("Other duplicate provider authorities remain")
        return data
    attribute_offset = target_offsets["authorities"]
    if data[attribute_offset + 15] != 3:
        raise ValueError("Provider authority must be a typed XML string")
    new_index = strings.index(wanted_authority) if wanted_authority in strings else len(strings)
    updated = bytearray(data)
    if u32(data, attribute_offset + 8) != NO_INDEX:
        struct.pack_into("<I", updated, attribute_offset + 8, new_index)
    struct.pack_into("<I", updated, attribute_offset + 16, new_index)
    if new_index == len(strings):
        pool_position, _, _, pool_size = pool_info
        updated = updated[:pool_position] + append_string(pool, wanted_authority, utf8) + updated[pool_position + pool_size:]
    struct.pack_into("<I", updated, 4, len(updated))
    repaired = bytes(updated)
    # Verify every attribute except the single intended authority is unchanged.
    _, _, new_strings, _ = read_pool(repaired)
    after = [(tag, values) for tag, values, _ in attributes(repaired, new_strings)]
    before = [(tag, values.copy()) for tag, values, _ in elements]
    for tag, values in before:
        if tag == "provider" and values.get("name") == TARGET_PROVIDER:
            values["authorities"] = wanted_authority
    if before != after:
        raise ValueError("Repair changed an unrelated manifest attribute")
    authorities = list(provider_authorities(repaired).values())
    if len(authorities) != len(set(authorities)):
        raise ValueError("Duplicate provider authorities remain after repair")
    return repaired


def repair_apk(source: Path, destination: Path) -> dict[str, str]:
    if source.resolve() == destination.resolve():
        raise ValueError("Write the repaired unsigned APK to a separate path")
    with zipfile.ZipFile(source) as original:
        fixed = repair_manifest(original.read("AndroidManifest.xml"))
        with zipfile.ZipFile(destination, "w") as output:
            for entry in original.infolist():
                # v2/v3 signing blocks are outside ZIP entries and are omitted;
                # v1 certificate entries must also be removed before re-signing.
                if entry.filename.startswith("META-INF/") and entry.filename.upper().endswith((".RSA", ".DSA", ".EC", ".SF", "MANIFEST.MF")):
                    continue
                value = fixed if entry.filename == "AndroidManifest.xml" else original.read(entry)
                # ZipFile mutates the ZipInfo's header offset while writing.
                # Copy it so subsequent reads from the original remain valid.
                output.writestr(copy.copy(entry), value)
            # Fix the official template's stale themed_icon resource reference
            # using the same valid adaptive XML already referenced by the app.
            alias = "res/mipmap-anydpi-v26/themed_icon.xml"
            primary = "res/mipmap-anydpi-v26/icon.xml"
            if alias not in original.namelist() and primary in original.namelist():
                output.writestr(alias, original.read(primary), compress_type=zipfile.ZIP_DEFLATED)
    return provider_authorities(fixed)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    arguments = parser.parse_args()
    providers = repair_apk(arguments.source, arguments.destination)
    for name, authority in providers.items():
        print(f"{name}: {authority}")
    print("Manifest repaired; zipalign and re-sign this unsigned APK before use.")


if __name__ == "__main__":
    main()
