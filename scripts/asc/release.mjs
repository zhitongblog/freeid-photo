// One-shot App Store Connect release for FreeID Photo.
//   node release.mjs <marketingVersion> <buildNumber> [--no-submit]
//   e.g. node release.mjs 1.1 14
// Idempotent: applies all metadata every run, creates the version if needed, attaches the
// build, uploads screenshots (only if the version has none yet), then submits for review.
// Pricing, App Privacy ("Data Not Collected") and the privacy page are app-level / one-time
// and carry across versions — they are NOT re-done here.
import { CONFIG, api, uploadScreenshot } from './asc.mjs';
import * as M from './metadata.mjs';
import fs from 'node:fs';

const [marketingVersion, buildNumber] = process.argv.slice(2);
const NO_SUBMIT = process.argv.includes('--no-submit');
if (!marketingVersion || !buildNumber) { console.error('usage: node release.mjs <marketingVersion> <buildNumber> [--no-submit]'); process.exit(1); }
const APP = CONFIG.appId;
const log = (...a) => console.log('•', ...a);

// 1) Ensure an editable (PREPARE_FOR_SUBMISSION) version with the right versionString.
let vers = (await api('GET', `/v1/apps/${APP}/appStoreVersions?limit=10`)).data;
let ver = vers.find((v) => v.attributes.appStoreState === 'PREPARE_FOR_SUBMISSION');
if (!ver) {
  log(`creating version ${marketingVersion}`);
  ver = (await api('POST', '/v1/appStoreVersions', { data: { type: 'appStoreVersions',
    attributes: { platform: 'IOS', versionString: marketingVersion },
    relationships: { app: { data: { type: 'apps', id: APP } } } } })).data;
} else if (ver.attributes.versionString !== marketingVersion) {
  await api('PATCH', `/v1/appStoreVersions/${ver.id}`, { data: { type: 'appStoreVersions', id: ver.id, attributes: { versionString: marketingVersion } } });
}
const verId = ver.id;
log('version', marketingVersion, verId);

// 2) App-info localizations (name / subtitle / privacy URL).
const appInfo = (await api('GET', `/v1/apps/${APP}/appInfos`)).data
  .find((d) => (d.attributes.appStoreState || d.attributes.state) === 'PREPARE_FOR_SUBMISSION') || (await api('GET', `/v1/apps/${APP}/appInfos`)).data[0];
const ilocs = (await api('GET', `/v1/appInfos/${appInfo.id}/appInfoLocalizations?limit=50`)).data;
for (const [locale, a] of Object.entries(M.appInfoLocalizations)) {
  const ex = ilocs.find((l) => l.attributes.locale === locale);
  if (ex) await api('PATCH', `/v1/appInfoLocalizations/${ex.id}`, { data: { type: 'appInfoLocalizations', id: ex.id, attributes: a } });
  else await api('POST', '/v1/appInfoLocalizations', { data: { type: 'appInfoLocalizations', attributes: { locale, ...a },
    relationships: { appInfo: { data: { type: 'appInfos', id: appInfo.id } } } } });
  log('appInfo loc', locale);
}
// primary category
await api('PATCH', `/v1/appInfos/${appInfo.id}`, { data: { type: 'appInfos', id: appInfo.id,
  relationships: { primaryCategory: { data: { type: 'appCategories', id: M.appFields.primaryCategory } } } } });

// 3) Version localizations (description / keywords / promo / whatsNew / urls).
const vlocs = (await api('GET', `/v1/appStoreVersions/${verId}/appStoreVersionLocalizations?limit=50`)).data;
for (const [locale, a] of Object.entries(M.versionLocalizations)) {
  const ex = vlocs.find((l) => l.attributes.locale === locale);
  if (ex) await api('PATCH', `/v1/appStoreVersionLocalizations/${ex.id}`, { data: { type: 'appStoreVersionLocalizations', id: ex.id, attributes: a } });
  else await api('POST', '/v1/appStoreVersionLocalizations', { data: { type: 'appStoreVersionLocalizations', attributes: { locale, ...a },
    relationships: { appStoreVersion: { data: { type: 'appStoreVersions', id: verId } } } } });
  log('version loc', locale);
}

// 4) App + version fields: copyright, content rights, release type.
await api('PATCH', `/v1/apps/${APP}`, { data: { type: 'apps', id: APP, attributes: { contentRightsDeclaration: M.appFields.contentRightsDeclaration } } });
await api('PATCH', `/v1/appStoreVersions/${verId}`, { data: { type: 'appStoreVersions', id: verId, attributes: { copyright: M.appFields.copyright, releaseType: M.appFields.releaseType } } });
log('copyright / contentRights / releaseType set');

// 5) Age rating (lives on the appInfo).
const decl = (await api('GET', `/v1/appInfos/${appInfo.id}/ageRatingDeclaration`)).data;
if (decl) { await api('PATCH', `/v1/ageRatingDeclarations/${decl.id}`, { data: { type: 'ageRatingDeclarations', id: decl.id, attributes: M.ageRating } }); log('age rating 4+'); }

// 6) Review contact.
const rd = (await api('GET', `/v1/appStoreVersions/${verId}/appStoreReviewDetail`)).data;
if (rd) await api('PATCH', `/v1/appStoreReviewDetails/${rd.id}`, { data: { type: 'appStoreReviewDetails', id: rd.id, attributes: M.reviewContact } });
else await api('POST', '/v1/appStoreReviewDetails', { data: { type: 'appStoreReviewDetails', attributes: M.reviewContact,
  relationships: { appStoreVersion: { data: { type: 'appStoreVersions', id: verId } } } } });
log('review contact set');

// 7) Attach the build matching <buildNumber>.
const build = (await api('GET', `/v1/builds?filter[app]=${APP}&filter[version]=${buildNumber}&limit=1`)).data[0];
if (!build) throw new Error(`build ${buildNumber} not found / not processed yet on App Store Connect`);
await api('PATCH', `/v1/appStoreVersions/${verId}/relationships/build`, { data: { type: 'builds', id: build.id } });
log('attached build', buildNumber, build.id);

// 8) Screenshots — upload only into sets that are currently empty (carries across re-runs).
for (const [locale, files] of Object.entries(M.screenshots.locales)) {
  const vl = (await api('GET', `/v1/appStoreVersions/${verId}/appStoreVersionLocalizations?limit=50`)).data.find((l) => l.attributes.locale === locale);
  if (!vl) { log('screenshots: no version loc for', locale, '(skip)'); continue; }
  let set = (await api('GET', `/v1/appStoreVersionLocalizations/${vl.id}/appScreenshotSets`)).data.find((s) => s.attributes.screenshotDisplayType === M.screenshots.displayType);
  if (!set) set = (await api('POST', '/v1/appScreenshotSets', { data: { type: 'appScreenshotSets', attributes: { screenshotDisplayType: M.screenshots.displayType },
    relationships: { appStoreVersionLocalization: { data: { type: 'appStoreVersionLocalizations', id: vl.id } } } } })).data;
  const existing = (await api('GET', `/v1/appScreenshotSets/${set.id}/appScreenshots`)).data.length;
  if (existing > 0) { log('screenshots', locale, '— already has', existing, '(skip)'); continue; }
  for (const f of files) { await uploadScreenshot(set.id, M.screenshots.dir + f); log('  uploaded', locale, f); }
}

// 9) Submit for review.
if (NO_SUBMIT) { log('--no-submit: everything staged but NOT submitted.'); process.exit(0); }
let sub = (await api('GET', `/v1/apps/${APP}/reviewSubmissions?filter[state]=READY_FOR_REVIEW&limit=1`)).data?.[0]
  || (await api('POST', '/v1/reviewSubmissions', { data: { type: 'reviewSubmissions', attributes: { platform: 'IOS' },
    relationships: { app: { data: { type: 'apps', id: APP } } } } })).data;
log('review submission', sub.id);
const items = (await api('GET', `/v1/reviewSubmissions/${sub.id}/items`)).data || [];
if (!items.length) {
  await api('POST', '/v1/reviewSubmissionItems', { data: { type: 'reviewSubmissionItems',
    relationships: { reviewSubmission: { data: { type: 'reviewSubmissions', id: sub.id } }, appStoreVersion: { data: { type: 'appStoreVersions', id: verId } } } } });
  log('added version to submission');
}
await api('PATCH', `/v1/reviewSubmissions/${sub.id}`, { data: { type: 'reviewSubmissions', id: sub.id, attributes: { submitted: true } } });
console.log('\n✅ Submitted for review. Auto-release after approval. You will get an email from Apple.');
