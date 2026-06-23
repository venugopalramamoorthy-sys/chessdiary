const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const path = require('path');

const serviceAccount = require(path.join(__dirname, '..', 'serviceAccount.json'));

initializeApp({ credential: cert(serviceAccount) });

const TEST_EMAIL = 'testuser@chessdiary.test';
const TEST_PASSWORD = 'TestPass123!';
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
  console.log(`   Password: ${TEST_PASSWORD}`);
}

main().catch(e => { console.error('❌ Failed:', e.message); process.exit(1); });
