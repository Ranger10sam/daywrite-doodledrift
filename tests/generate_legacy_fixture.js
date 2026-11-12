// Compatibility fixture only; no real player data or secret is contained here.
// Independently uses Node's standard crypto rather than the game's GDScript.
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const password = 'fixture-only-passphrase';
const magic = 'MOMENTUM-QUEST-BACKUP-1';
const iterations = 100000;
const legacy = {
  version: 1,
  settings: {
    difficulty: 'expert', master: 0.66, music: 0.23, sfx: 0.7,
    mute: false, reduced_motion: true, hints: true, face: true, haptics: false,
    control_opacity: 0.75, control_size: 1.15, ui_scale: 1.0,
    numeric_ink: true, trajectory_hint: false,
  },
  levels: {'1': {explorer: true, engineer: true, master: true, best_time: 18.25, best_ink: 32.5, best_deaths: 0}},
  last_level: 2, tutorials: {draw: true}, cosmetic: 'pearl',
};
const salt = crypto.randomBytes(16);
const iv = crypto.randomBytes(16);
const keys = crypto.pbkdf2Sync(password, salt, iterations, 64, 'sha256');
const cipher = crypto.createCipheriv('aes-256-cbc', keys.subarray(0, 32), iv);
const ciphertext = Buffer.concat([cipher.update(JSON.stringify(legacy), 'utf8'), cipher.final()]);
const authenticated = Buffer.concat([
  Buffer.from(`${magic}:PBKDF2-HMAC-SHA256:AES-256-CBC-HMAC-SHA256:${iterations}`),
  salt, iv, ciphertext,
]);
const envelope = {
  format: magic, version: 1, iterations, kdf: 'PBKDF2-HMAC-SHA256',
  cipher: 'AES-256-CBC-HMAC-SHA256', salt: salt.toString('base64'), iv: iv.toString('base64'),
  ciphertext: ciphertext.toString('base64'),
  mac: crypto.createHmac('sha256', keys.subarray(32, 64)).update(authenticated).digest('base64'),
};
fs.writeFileSync(path.join(__dirname, 'fixtures', 'legacy_progress_v1.encrypted.json'), JSON.stringify(envelope, null, 2) + '\n');
console.log('Generated independent legacy schema-1 backup fixture without an ambience setting.');
