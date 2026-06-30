// Metadata-only fix for the v1.0 rejection (guidelines 2.1 face data + 2.3.7 price refs).
// No new binary: the existing REJECTED 1.0 version is editable; we patch metadata,
// replace the two price-referencing screenshots, and write the face-data answers into
// the App Review notes. Resolution Center reply + final "Resubmit" are done in the web UI.
//   node resubmit_fix.mjs
import { CONFIG, api as rawApi, uploadScreenshot } from './asc.mjs';
import * as M from './metadata.mjs';

const APP = CONFIG.appId;
const log = (...a) => console.log('•', ...a);

// Apple's API throws sporadic 500s; retry transient server errors a few times.
async function api(method, path, body) {
  for (let i = 0; ; i++) {
    try { return await rawApi(method, path, body); }
    catch (e) {
      const transient = /-> 5\d\d:/.test(String(e.message));
      if (!transient || i >= 4) throw e;
      await new Promise(r => setTimeout(r, 1500 * (i + 1)));
      log('retry', method, path.split('?')[0], `(${i + 1})`);
    }
  }
}

// Face-data answers (guideline 2.1) — also pasted into the Resolution Center reply.
export const reviewNotes = `Guideline 2.1 — Face data

FreeID Photo is an on-device passport/ID photo tool. It does NOT collect, store, transmit, or share any face data.

1) What face data does the app collect?
None is collected or retained. To frame and crop a compliant ID photo, the app performs a one-time, on-device face detection using Apple's Vision framework (VNDetectFaceLandmarksRequest). From the current camera frame it reads only transient geometry — the position of the top of the head, chin, and eyes, and the head's roll/yaw/pitch angles — held in memory only long enough to crop the photo. No face templates, embeddings, or biometric signatures are created.

2) All planned uses of the face data.
The geometry is used solely to (a) position the on-screen head-and-shoulders framing guide, (b) crop the photo to the selected document's official head-size/eye-position spec, and (c) optionally replace the background color. That is the only use. It is discarded as soon as the photo is produced.

3) Shared with third parties? Where stored?
No, and nowhere. It is never shared and never stored. All processing happens entirely on the user's device. The app has no servers, no accounts, no analytics, and no third-party SDKs. Nothing is uploaded.

4) How long is face data retained?
Not retained. The transient measurements exist only in memory during processing and are released immediately afterward. Nothing is written to disk except the finished photo the user explicitly chooses to save to their own Photo Library.

5) Where in the privacy policy is this explained?
https://doaipm.com/privacy — see the section "Face data" (English) / "人脸数据" (中文).

6) Exact privacy-policy text concerning face data:
"To position your head and crop to the document's spec, the App runs a one-time, on-device face detection using Apple's built-in Vision framework, reading geometry such as the top of the head, chin, eye positions, and head angle. This face data is used only for instant framing and cropping. It is never stored, never turned into a face template or biometric signature, never leaves your device, and is never shared with any third party. The measurements are discarded as soon as the photo is processed. The App retains no face data."

Guideline 2.3.7 — We removed all price references from the subtitle, screenshots, keywords, and promotional text (previously "Truly free" / "真正免费"). Regarding the app name "FreeID Photo": "FreeID" is the product's brand name (a play on "free identity / ID"), not a price claim. If the team still considers the brand name a price reference, please let us know and we will rename.`;

// 1) Locate the editable 1.0 version (REJECTED is editable).
const vers = (await api('GET', `/v1/apps/${APP}/appStoreVersions?limit=10`)).data;
const ver = vers.find(v => ['REJECTED', 'PREPARE_FOR_SUBMISSION', 'DEVELOPER_REJECTED', 'METADATA_REJECTED'].includes(v.attributes.appStoreState)) || vers[0];
const verId = ver.id;
log('version', ver.attributes.versionString, ver.attributes.appStoreState, verId);

// 2) App-info localizations (name / subtitle / privacy URL) — all 8 locales.
const appInfos = (await api('GET', `/v1/apps/${APP}/appInfos`)).data;
const appInfo = appInfos.find(d => (d.attributes.appStoreState || d.attributes.state) === 'PREPARE_FOR_SUBMISSION') || appInfos[0];
const ilocs = (await api('GET', `/v1/appInfos/${appInfo.id}/appInfoLocalizations?limit=50`)).data;
for (const [locale, a] of Object.entries(M.appInfoLocalizations)) {
  const ex = ilocs.find(l => l.attributes.locale === locale);
  if (ex) await api('PATCH', `/v1/appInfoLocalizations/${ex.id}`, { data: { type: 'appInfoLocalizations', id: ex.id, attributes: a } });
  else await api('POST', '/v1/appInfoLocalizations', { data: { type: 'appInfoLocalizations', attributes: { locale, ...a }, relationships: { appInfo: { data: { type: 'appInfos', id: appInfo.id } } } } });
  log('appInfo loc', locale, '→', a.subtitle);
}

// 3) Version localizations (description / keywords / promo) — en + zh.
const vlocs = (await api('GET', `/v1/appStoreVersions/${verId}/appStoreVersionLocalizations?limit=50`)).data;
for (const [locale, raw] of Object.entries(M.versionLocalizations)) {
  const { whatsNew, ...a } = raw; // whatsNew isn't editable on a first version
  const ex = vlocs.find(l => l.attributes.locale === locale);
  if (ex) await api('PATCH', `/v1/appStoreVersionLocalizations/${ex.id}`, { data: { type: 'appStoreVersionLocalizations', id: ex.id, attributes: a } });
  else await api('POST', '/v1/appStoreVersionLocalizations', { data: { type: 'appStoreVersionLocalizations', attributes: { locale, ...a }, relationships: { appStoreVersion: { data: { type: 'appStoreVersions', id: verId } } } } });
  log('version loc', locale);
}

// 4) App Review notes — the face-data explanation (guideline 2.1).
const rd = (await api('GET', `/v1/appStoreVersions/${verId}/appStoreReviewDetail`)).data;
const attrs = { ...M.reviewContact, notes: reviewNotes };
if (rd) await api('PATCH', `/v1/appStoreReviewDetails/${rd.id}`, { data: { type: 'appStoreReviewDetails', id: rd.id, attributes: attrs } });
else await api('POST', '/v1/appStoreReviewDetails', { data: { type: 'appStoreReviewDetails', attributes: attrs, relationships: { appStoreVersion: { data: { type: 'appStoreVersions', id: verId } } } } });
log('review notes set (face-data explanation)');

// 5) Replace screenshots: delete existing in the 6.7" set, re-upload all 3 (new shot 1).
for (const [locale, files] of Object.entries(M.screenshots.locales)) {
  const vl = (await api('GET', `/v1/appStoreVersions/${verId}/appStoreVersionLocalizations?limit=50`)).data.find(l => l.attributes.locale === locale);
  if (!vl) { log('screenshots: no version loc for', locale, '(skip)'); continue; }
  let set = (await api('GET', `/v1/appStoreVersionLocalizations/${vl.id}/appScreenshotSets`)).data.find(s => s.attributes.screenshotDisplayType === M.screenshots.displayType);
  if (!set) set = (await api('POST', '/v1/appScreenshotSets', { data: { type: 'appScreenshotSets', attributes: { screenshotDisplayType: M.screenshots.displayType }, relationships: { appStoreVersionLocalization: { data: { type: 'appStoreVersionLocalizations', id: vl.id } } } } })).data;
  const existing = (await api('GET', `/v1/appScreenshotSets/${set.id}/appScreenshots`)).data;
  for (const s of existing) { await api('DELETE', `/v1/appScreenshots/${s.id}`); }
  log('screenshots', locale, '— deleted', existing.length, 'old');
  for (const f of files) { await uploadScreenshot(set.id, M.screenshots.dir + f); log('  uploaded', locale, f); }
}

console.log('\n✅ Metadata + screenshots + review notes updated on the REJECTED 1.0 version.');
console.log('   Next: post the Resolution Center reply and click Resubmit (web UI).');
