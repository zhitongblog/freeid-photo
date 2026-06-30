// Resubmit the edited (REJECTED) v1.0 for review via the ASC API.
// Creates/reuses a review submission, adds the version as an item, marks submitted.
import { CONFIG, api as rawApi } from './asc.mjs';
const APP = CONFIG.appId;
const log = (...a) => console.log('•', ...a);
async function api(m, p, b) { for (let i = 0; ; i++) { try { return await rawApi(m, p, b); } catch (e) { if (!/-> 5\d\d:/.test(String(e.message)) || i >= 4) throw e; await new Promise(r => setTimeout(r, 1500 * (i + 1))); } } }

const ver = (await api('GET', `/v1/apps/${APP}/appStoreVersions?limit=10`)).data
  .find(v => ['REJECTED', 'PREPARE_FOR_SUBMISSION', 'DEVELOPER_REJECTED', 'METADATA_REJECTED'].includes(v.attributes.appStoreState));
log('version', ver.attributes.versionString, ver.attributes.appStoreState, ver.id);

// Reuse a READY_FOR_REVIEW submission if one exists, else create a new one.
let sub = (await api('GET', `/v1/apps/${APP}/reviewSubmissions?filter[state]=READY_FOR_REVIEW&limit=1`)).data?.[0];
if (!sub) {
  sub = (await api('POST', '/v1/reviewSubmissions', { data: { type: 'reviewSubmissions',
    attributes: { platform: 'IOS' }, relationships: { app: { data: { type: 'apps', id: APP } } } } })).data;
  log('created submission', sub.id);
} else log('reusing submission', sub.id);

const items = (await api('GET', `/v1/reviewSubmissions/${sub.id}/items`)).data || [];
if (!items.length) {
  await api('POST', '/v1/reviewSubmissionItems', { data: { type: 'reviewSubmissionItems',
    relationships: { reviewSubmission: { data: { type: 'reviewSubmissions', id: sub.id } },
      appStoreVersion: { data: { type: 'appStoreVersions', id: ver.id } } } } });
  log('added version to submission');
} else log('submission already has', items.length, 'item(s)');

await api('PATCH', `/v1/reviewSubmissions/${sub.id}`, { data: { type: 'reviewSubmissions', id: sub.id, attributes: { submitted: true } } });
const after = (await api('GET', `/v1/reviewSubmissions/${sub.id}`)).data;
console.log('\n✅ Resubmitted. Submission', sub.id, 'state:', after.attributes.state);
