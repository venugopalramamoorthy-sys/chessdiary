const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const path = require('path');

const serviceAccount = require(path.join(__dirname, '..', 'serviceAccount.json'));

initializeApp({ credential: cert(serviceAccount) });

// Credentials come from the environment or the gitignored .env.test at the
// repo root -- never hard-code them here, the repo is public
const fs = require('fs');
const envFile = path.join(__dirname, '..', '.env.test');
if (fs.existsSync(envFile)) {
  for (const line of fs.readFileSync(envFile, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z_][A-Z0-9_]*)\s*=\s*(.*?)\s*$/);
    if (m && process.env[m[1]] === undefined) process.env[m[1]] = m[2];
  }
}
const TEST_EMAIL = process.env.TEST_EMAIL;
const TEST_PASSWORD = process.env.TEST_PASSWORD;
if (!TEST_EMAIL || !TEST_PASSWORD) {
  console.error('❌ Set TEST_EMAIL and TEST_PASSWORD in .env.test (repo root) first.');
  process.exit(1);
}
const TEST_NAME = 'Test User';

async function main() {
  const auth = getAuth();
  try {
    const existing = await auth.getUserByEmail(TEST_EMAIL);
    console.log(`✅ Test user already exists: ${existing.uid}`);
    return;
  } catch (e) {
    if (e.code !== 'auth/user-not-found') throw e;
  }
  const user = await auth.createUser({
    email: TEST_EMAIL,
    password: TEST_PASSWORD,
    displayName: TEST_NAME,
    emailVerified: true,
  });
  console.log(`✅ Test user created: ${user.uid}`);
  console.log(`   Email:    ${TEST_EMAIL}`);
}

main().catch(e => { console.error('❌ Failed:', e.message); process.exit(1); });
