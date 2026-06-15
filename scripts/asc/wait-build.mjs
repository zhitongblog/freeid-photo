// Poll App Store Connect until build <version> is processed (VALID). Used by release.sh.
//   node wait-build.mjs <buildNumber>
import { CONFIG, api } from './asc.mjs';

const build = process.argv[2];
if (!build) { console.error('usage: node wait-build.mjs <buildNumber>'); process.exit(1); }

const deadline = Date.now() + 30 * 60 * 1000; // 30 min max
while (Date.now() < deadline) {
  const b = (await api('GET', `/v1/builds?filter[app]=${CONFIG.appId}&filter[version]=${build}&limit=1`)).data[0];
  const state = b?.attributes?.processingState;
  if (state === 'VALID') { console.log(`  build ${build} is VALID`); process.exit(0); }
  if (state === 'INVALID' || state === 'FAILED') { console.error(`  build ${build} is ${state}`); process.exit(1); }
  console.log(`  build ${build}: ${state || 'not visible yet'} — waiting 30s…`);
  await new Promise((r) => setTimeout(r, 30000));
}
console.error('  timed out waiting for build to process'); process.exit(1);
