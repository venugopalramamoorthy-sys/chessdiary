// Shared helpers for the deep checks (healthcheck/deep_check.py runs them).
// Credentials come from the gitignored .env.test at the repo root -- the
// same test account the Playwright suite uses. Nothing secret lives here.
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..', '..');
const SITE = 'https://chessdiary.app';
const API_KEY = 'AIzaSyB_mxJS3rdPPKu9ujQf8kc1eEfw_4F2Nvo'; // public Firebase web key
const DB = 'projects/chessdiary-7f1e3/databases/(default)/documents';
const FIRESTORE = 'https://firestore.googleapis.com/v1/';

// The web key only accepts requests from chessdiary.app (Google Cloud key
// restriction), so every Google API call that carries ?key= sends the site's
// Referer -- otherwise the key restriction's 403 would mask what the
// Firestore rules themselves do.
const _fetch = globalThis.fetch;
globalThis.fetch = (url, opts = {}) => {
  const u = String(url);
  if (u.includes('.googleapis.com/') && u.includes('key=')) {
    opts = { ...opts, headers: { Referer: SITE + '/', ...(opts.headers || {}) } };
  }
  return _fetch(url, opts);
};

function loadEnv() {
  const env = { ...process.env };
  const file = path.join(ROOT, '.env.test');
  if (fs.existsSync(file)) {
    for (const line of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
      const m = line.match(/^\s*([A-Z_][A-Z0-9_]*)\s*=\s*(.*?)\s*$/);
      if (m && env[m[1]] === undefined) env[m[1]] = m[2];
    }
  }
  if (!env.TEST_EMAIL || !env.TEST_PASSWORD) throw new Error('TEST_EMAIL/TEST_PASSWORD missing (.env.test)');
  return env;
}

async function signIn() {
  const env = loadEnv();
  const r = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${API_KEY}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: env.TEST_EMAIL, password: env.TEST_PASSWORD, returnSecureToken: true }),
  });
  const j = await r.json();
  if (!j.idToken) throw new Error('test account sign-in failed: ' + (j.error && j.error.message));
  return { token: j.idToken, uid: j.localId };
}

function backendUrl() {
  const src = fs.readFileSync(path.join(ROOT, 'lib', 'services', 'stockfish_service.dart'), 'utf8');
  const m = src.match(/https:\/\/[a-z0-9.-]*onrender\.com/);
  if (!m) throw new Error('backend URL not found in stockfish_service.dart');
  return m[0];
}

/** Counter that prints PASS/FAIL lines and a final machine-readable SUMMARY. */
function checker() {
  let pass = 0, fail = 0;
  const check = (name, ok, extra = '') => {
    ok ? pass++ : fail++;
    console.log((ok ? 'PASS ' : 'FAIL ') + name + (extra ? '  ' + extra : ''));
  };
  const done = () => { console.log(`SUMMARY ${pass} ${fail}`); process.exitCode = fail ? 1 : 0; };
  return { check, done };
}

module.exports = { ROOT, SITE, API_KEY, DB, FIRESTORE, signIn, backendUrl, checker };
