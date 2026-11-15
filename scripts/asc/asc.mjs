// App Store Connect API helpers (ES256 JWT + fetch wrapper) + a screenshot uploader.
// Used by release.mjs. The .p8 private key is read from ~/.appstoreconnect/private_keys
// and is NEVER committed. Only the non-secret IDs live in config below.
import crypto from 'node:crypto';
import fs from 'node:fs';

export const CONFIG = {
  keyId:   process.env.ASC_KEY_ID   || 'H85Q4NJPVD',                               // "FreeID Photo CI" key (Admin)
  issuer:  process.env.ASC_ISSUER   || '21dd1b35-fb04-42f1-8ec0-d847838fa7b6',
  appId:   process.env.ASC_APP_ID   || '6779873542',                               // FreeID Photo
  keyPath: process.env.ASC_KEY_PATH || `${process.env.HOME}/.appstoreconnect/private_keys/AuthKey_${process.env.ASC_KEY_ID || 'H85Q4NJPVD'}.p8`,
};

const b64u = (b) => Buffer.from(b).toString('base64').replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');

/** A fresh bearer token. Apple caps token lifetime at 20 min — we use ~18. */
export function token() {
  const p8 = fs.readFileSync(CONFIG.keyPath, 'utf8');
  const now = Math.floor(Date.now() / 1000);
  const header = b64u(JSON.stringify({ alg: 'ES256', kid: CONFIG.keyId, typ: 'JWT' }));
  const payload = b64u(JSON.stringify({ iss: CONFIG.issuer, iat: now, exp: now + 1080, aud: 'appstoreconnect-v1' }));
  const key = crypto.createPrivateKey(p8);
  const sig = crypto.sign('SHA256', Buffer.from(`${header}.${payload}`), { key, dsaEncoding: 'ieee-p1363' });
  return `${header}.${payload}.${b64u(sig)}`;
}

let JWT = token();
let JWT_AT = Date.now();
/** Call the ASC API. Auto-refreshes JWT before expiry; throws on HTTP >= 300. */
export async function api(method, path, body) {
  if (Date.now() - JWT_AT > 14 * 60 * 1000) {
    JWT = token();
    JWT_AT = Date.now();
  }
  const r = await fetch('https://api.appstoreconnect.apple.com' + path, {
    method,
    headers: { Authorization: `Bearer ${JWT}`, 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await r.text();
  const json = text ? JSON.parse(text) : null;
  if (r.status >= 300) {
    const detail = json?.errors?.[0]?.detail || json?.errors?.[0]?.title || r.status;
    throw new Error(`${method} ${path} -> ${r.status}: ${detail}`);
  }
  return json;
}

/** Upload one screenshot file into a screenshot set (reserve -> PUT bytes -> commit). */
export async function uploadScreenshot(setId, file) {
  const buf = fs.readFileSync(file);
  const name = file.split('/').pop();
  const res = await api('POST', '/v1/appScreenshots', {
    data: { type: 'appScreenshots', attributes: { fileName: name, fileSize: buf.length },
      relationships: { appScreenshotSet: { data: { type: 'appScreenshotSets', id: setId } } } },
  });
  const id = res.data.id;
  for (const op of res.data.attributes.uploadOperations || []) {
    const headers = {}; (op.requestHeaders || []).forEach((h) => (headers[h.name] = h.value));
    const up = await fetch(op.url, { method: op.method, headers, body: buf.subarray(op.offset, op.offset + op.length) });
    if (!up.ok) throw new Error(`PUT ${name} -> ${up.status}`);
  }
  const md5 = crypto.createHash('md5').update(buf).digest('hex');
  await api('PATCH', `/v1/appScreenshots/${id}`, { data: { type: 'appScreenshots', id, attributes: { uploaded: true, sourceFileChecksum: md5 } } });
  return name;
}
