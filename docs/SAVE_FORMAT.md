# Progress, backup security, and sound

`SaveManager` owns a version 1 JSON schema in `user://progress.json`. A save contains
settings, independently earned Explorer/Engineer/Master achievements, each level's
best time/ink/deaths, the last level, tutorial flags, and cosmetic preference. Zen
completion does not award records or unlock competitive progress. There is no
account, network request, identifier, analytics, purchase receipt, or entitlement in
the save. Device-local JSON is **not encrypted**.

Writes validate the full schema, write and flush a temporary file, and rename it
onto the destination. The previous valid primary is separately preserved as
`progress.previous.json`. If the primary is corrupt, loading falls back to that
previous valid save; with neither valid it uses defaults and reports recovery.
An invalid primary is not copied over the last valid backup. Atomic rename is the
filesystem safety mechanism; this is not a guarantee against storage hardware
failure. Saves from unknown schema versions are rejected, not silently imported.

`restore_previous()` reads the previous save before making a new write. Import
requires `confirmed=true`; the UI must obtain explicit overwrite confirmation.
Validation discards unknown fields and bounds settings and record sizes.

## Portable `.mqbackup` format

The JSON envelope records `format`, `version`, `iterations`, `kdf`, `cipher`, and
Base64 salt, IV, ciphertext, and authentication tag. Version 1 uses:

- A fresh cryptographically random 16-byte salt and 16-byte IV for every export.
- PBKDF2-HMAC-SHA256 with **100,000 iterations**, producing 64 bytes. The first 32
  bytes are an AES-256 key; the remaining 32 bytes are an independent HMAC key.
- AES-256-CBC with PKCS#7 padding for confidentiality.
- HMAC-SHA256 over a fixed format/KDF/cipher/iteration header, salt, IV, and
  ciphertext, verified with Godot's constant-time comparison **before decryption**.

This encrypt-then-authenticate construction provides authenticated encryption;
the implementation does not claim to use AES-GCM. Iterations are fixed for this
format to prevent a hostile envelope requesting unbounded KDF work. Backups and
plaintext saves have size limits. Passwords are never saved, logged, or embedded
in source; export requires at least ten characters. Forgotten passwords cannot be
recovered. Native code maintains cryptographic contexts; GDScript strings and byte
arrays do not provide a secure memory-erasure guarantee.

Android's system picker returns a `content://` document URI. The backup writer
opens that granted document directly, since the grant does not authorize creating
a sibling temporary document and renaming it. Interrupted portable exports can
leave an incomplete file, which import rejects safely; device-local progress still
uses atomic temporary-file replacement. No broad storage permission is required.

100,000 iterations balances resistance to password guessing with a portable
GDScript KDF; it is a documented parameter, not a claim of compliance with any
particular password-storage policy. Strong unique passphrases remain important.
Backup derivation is intentionally expensive and can briefly block the current
operation; benchmark on release hardware before selecting a future format/KDF.

The automated persistence test uses a PBKDF2 vector independently calculated with
Python's standard `hashlib.pbkdf2_hmac`, checks encrypted round trips, wrong
passwords, tampering, overwrite confirmation, malformed/future schemas, atomic
save/load, previous-save recovery, Zen exclusion, and independent achievements.
It writes only dedicated temporary files in `res://tests/` and removes them.

Godot API references: [Crypto](https://docs.godotengine.org/en/stable/classes/class_crypto.html)
and [AESContext](https://docs.godotengine.org/en/stable/classes/class_aescontext.html).

## Premium entitlement boundary

`Entitlements` grants development access only in editor/debug builds. Release
builds expose Green Valley and return an honest unavailable message for purchasing
or restoring premium access. Saved progress and imported backups cannot grant
premium. Before distribution, replace this adapter with Google Play Billing,
verify purchases and restoration, acknowledge qualifying transactions, and test
pending, cancelled, refunded, offline, and account-change cases. No price button
pretends that payment has occurred.

## DoodleDrift compatibility and sound

The public name is now DoodleDrift. Schema version 1, the progress filenames and
the `MOMENTUM-QUEST-BACKUP-1` portable marker remain unchanged. Old saves without
the new independent `ambience` setting receive its default 0.35 while retaining
progress and previous preferences. The application keeps the previous platform
save directory; the public name does not select a fresh directory.

`AudioManager` now combines ten original locally bundled stereo music/environment
loops with original synthesized effects. Music, Ambience and SFX have independent
buses under Master. Four reusable decks make smooth bounded biome crossfades;
eight effect voices cover gameplay, rolling, drawing and regeneration cues.
See [DoodleDrift audio](DOODLEDRIFT_AUDIO.md) for provenance, synthesis, loop
continuity, crossfade behavior and the limits of automated audio verification.
