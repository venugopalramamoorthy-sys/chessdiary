// Deep check: Firestore data isolation, the backend's auth gate and limits,
// and the public game report rules end to end (create -> view -> edit ->
// unpublish), always cleaning up its test report.
const fs = require('fs');
const path = require('path');
const { chromium } = require('@playwright/test');
const { ROOT, SITE, API_KEY, DB, FIRESTORE, signIn, backendUrl, checker } = require('./common');

const toRest = (v) => Array.isArray(v) ? { arrayValue: { values: v.map(toRest) } }
  : v && typeof v === 'object' ? { mapValue: { fields: Object.fromEntries(Object.entries(v).map(([k, x]) => [k, toRest(x)])) } }
  : typeof v === 'number' ? (Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v })
  : typeof v === 'boolean' ? { booleanValue: v } : { stringValue: String(v) };
const fieldsOf = (o) => Object.fromEntries(Object.entries(o).map(([k, v]) => [k, toRest(v)]));
const doc = (p) => `${FIRESTORE}${DB}/${p}`;
const SAMPLE_PGN = '1. e4 e5 2. Nf3 Nc6 3. Bc4 Nd4 4. Nxe5 Qg5 5. Nxf7 Qxg2 6. Rf1 Qxe4+ 7. Be2 Nf3#';

(async () => {
  const { check, done } = checker();
  const { token, uid } = await signIn();
  const H = { Authorization: 'Bearer ' + token, 'Content-Type': 'application/json' };
  const write = (p) => fetch(doc(p), { method: 'PATCH', headers: H, body: JSON.stringify({ fields: { a: toRest('x') } }) }).then((r) => r.status);

  // ── Firestore isolation ────────────────────────────────────────────────
  check('anonymous cannot list users', (await fetch(`${doc('users')}?key=${API_KEY}`)).status === 403);
  check("anonymous cannot read a user's games", (await fetch(`${doc(`users/${uid}/games`)}?key=${API_KEY}`)).status === 403);
  check('owner can read own games', (await fetch(doc(`users/${uid}/games`), { headers: H })).status === 200);
  check("cannot read another user's games", (await fetch(doc('users/someoneElseUid123/games'), { headers: H })).status === 403);
  check("cannot write another user's games", (await write('users/someoneElseUid123/games/x')) === 403);
  check('cannot write an unlisted subcollection', (await write(`users/${uid}/evil/x`)) === 403);
  check('cannot create a top-level collection', (await write('admin/x')) === 403);
  check('anonymous cannot list publicGames', (await fetch(`${doc('publicGames')}?key=${API_KEY}`)).status === 403);

  // ── Backend (Render): auth gate, limits, real analysis ────────────────
  const BE = backendUrl();
  const post = (p, body, headers = { 'Content-Type': 'application/json' }) =>
    fetch(BE + p, { method: 'POST', headers, body: typeof body === 'string' ? body : JSON.stringify(body), signal: AbortSignal.timeout(120_000) });
  check('backend /health', (await fetch(BE + '/health', { signal: AbortSignal.timeout(120_000) })).status === 200);
  check('analyze rejects a missing token', (await post('/analyze', { pgn: '1. e4 e5' })).status === 401);
  check('analyze rejects a forged token', (await post('/analyze', { pgn: '1. e4 e5' },
    { 'Content-Type': 'application/json', Authorization: 'Bearer eyJhbGciOiJSUzI1NiJ9.e30.xx' })).status === 401);
  check('gemini rejects a missing token', (await post('/gemini', {})).status === 401);
  check('gemini refuses a non-allowlisted model', [400, 403].includes(
    (await post('/gemini', { model: 'gemini-1.0-pro', contents: [{ parts: [{ text: 'write a poem' }] }] }, H)).status));
  check('analyze rejects a PGN over 20,000 chars', (await post('/analyze', { pgn: 'x'.repeat(20_001) }, H)).status === 413);
  const cyc = ['Nf3', 'Nf6', 'Ng1', 'Ng8']; let long = '';
  for (let i = 0; i < 404; i++) { if (i % 2 === 0) long += `${i / 2 + 1}. `; long += cyc[i % 4] + ' '; }
  check('analyze rejects a game over 400 plies', (await post('/analyze', { pgn: long }, H)).status === 413);
  const an = await post('/analyze', { pgn: SAMPLE_PGN }, H);
  const aj = an.status === 200 ? await an.json() : {};
  check('analyze works for a signed-in user', an.status === 200 && (aj.analysis || []).length === 14, 'status ' + an.status);

  // ── Public game reports: rules + live viewer ──────────────────────────
  const slug = '2026-11-deepcheck-' + Math.random().toString(36).slice(2, 8);
  const docName = `${DB}/publicGames/${slug}`;
  const f = JSON.parse(fs.readFileSync(path.join(ROOT, 'tools', 'public-games', 'fixture.json'), 'utf8'))[0];
  const report = { ...f, slug, ownerUid: uid, sourceGameId: 'deep-check-game', approved: false };
  delete report.publishedAt; delete report.updatedAt;
  const ts = (...ps) => ps.map((p) => ({ fieldPath: p, setToServerValue: 'REQUEST_TIME' }));
  const commit = (w) => fetch(`${FIRESTORE}${DB}:commit`, { method: 'POST', headers: H, body: JSON.stringify({ writes: [w] }) }).then((r) => r.status);
  const create = (r) => commit({ update: { name: docName, fields: fieldsOf(r) }, updateTransforms: ts('publishedAt', 'updatedAt'), currentDocument: { exists: false } });
  const patch = (fields, mask) => commit({ update: { name: docName, fields }, updateMask: { fieldPaths: mask }, updateTransforms: ts('updatedAt') });

  const browser = await chromium.launch();
  try {
    check('report: self-approval on create is rejected', (await create({ ...report, approved: true })) === 403);
    check('report: wrong owner is rejected', (await create({ ...report, ownerUid: 'someone-else' })) === 403);
    check('report: owner can publish', (await create(report)) === 200);
    check('report: anyone can read it by slug', (await fetch(`${FIRESTORE}${docName}?key=${API_KEY}`)).status === 200);

    const page = await browser.newPage();
    const errors = []; page.on('pageerror', (e) => errors.push(e.message));
    await page.goto(`${SITE}/g/${slug}/`, { waitUntil: 'networkidle', timeout: 60_000 });
    const v = await page.evaluate(() => ({
      h1: (document.querySelector('h1') || {}).textContent || '',
      boards: document.querySelectorAll('figure.board').length,
      robots: (document.querySelector('meta[name=robots]') || {}).content,
      ads: !!document.querySelector('script[src*=adsbygoogle]'),
    }));
    check('report: viewer renders it', /Philidor/.test(v.h1) && v.boards > 0, `${v.boards} boards`);
    check('report: viewer is noindex with no ads', v.robots === 'noindex' && !v.ads);
    check('report: no script errors in the viewer', !errors.length, errors.join(' | ').slice(0, 200));

    check('report: owner can edit notes', (await patch({ notes: toRest(report.notes + '\n\nEdited.'), approved: toRest(false) }, ['notes', 'approved'])) === 200);
    check('report: owner cannot approve it', (await patch({ approved: toRest(true) }, ['approved'])) === 403);
    check('report: unknown fields are rejected', (await patch({ foo: toRest('bar') }, ['foo'])) === 403);
    check('report: publish date cannot change', (await patch({ publishedAt: { timestampValue: '2020-01-01T00:00:00Z' } }, ['publishedAt'])) === 403);
    const q = await fetch(`${FIRESTORE}${DB}:runQuery`, { method: 'POST', headers: H, body: JSON.stringify({ structuredQuery: {
      from: [{ collectionId: 'publicGames' }], where: { fieldFilter: { field: { fieldPath: 'ownerUid' }, op: 'EQUAL', value: { stringValue: uid } } } } }) });
    check('report: owner can list own reports', q.status === 200 && (await q.json()).some((r) => r.document && r.document.name.endsWith(slug)));
    check('report: owner can unpublish', (await fetch(`${FIRESTORE}${docName}`, { method: 'DELETE', headers: H })).status === 200);
    await page.goto(`${SITE}/g/${slug}/`, { waitUntil: 'networkidle', timeout: 60_000 });
    check('report: link shows "not found" afterwards', (await page.textContent('h1')) === 'Report not found');
  } finally {
    await fetch(`${FIRESTORE}${docName}`, { method: 'DELETE', headers: H }); // always clean up
    await browser.close();
  }
  done();
})().catch((e) => { console.log('FAIL security check crashed  ' + e.message); console.log('SUMMARY 0 1'); process.exitCode = 1; });
