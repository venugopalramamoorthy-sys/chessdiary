#!/usr/bin/env node
// Moderation for public game reports (publicGames/{slug}). Uses the Admin SDK,
// so it can set the `approved` flag the app is never allowed to write.
//
//   node tools/public-games/reports.js list [--pending]
//   node tools/public-games/reports.js show <slug>
//   node tools/public-games/reports.js approve <slug> [--force]
//   node tools/public-games/reports.js unapprove <slug>
//   node tools/public-games/reports.js takedown <slug>
//
// Approval takes effect on the next deploy (bash deploy.sh), which builds the
// static, indexable page. The owner editing a report resets approval.
'use strict';

const { quality, loadAdmin, SLUG_RE, MIN_OWN_WORDS, MIN_COMMENTED_MOMENTS } = require('./common');

function iso(ts) {
  return ts && ts.toDate ? ts.toDate().toISOString().slice(0, 16).replace('T', ' ') : '-';
}

async function getReport(db, slug) {
  if (!SLUG_RE.test(slug || '')) throw new Error('Not a valid slug: ' + slug);
  const ref = db.collection('publicGames').doc(slug);
  const snap = await ref.get();
  if (!snap.exists) throw new Error('No report with slug ' + slug);
  return { ref, data: snap.data() };
}

async function main() {
  const [cmd, slug] = process.argv.slice(2);
  const flag = (f) => process.argv.includes(f);
  const db = loadAdmin().firestore();

  if (cmd === 'list') {
    const snap = await db.collection('publicGames').orderBy('updatedAt', 'desc').get();
    const rows = snap.docs.map((d) => d.data()).filter((d) => !flag('--pending') || !d.approved);
    if (!rows.length) return console.log(flag('--pending') ? 'Nothing waiting for review.' : 'No public reports yet.');
    for (const d of rows) {
      const q = quality(d);
      console.log([
        d.approved ? 'APPROVED' : 'pending ',
        d.slug.padEnd(42),
        ('words ' + q.ownWords).padEnd(10),
        ('comments ' + q.commented).padEnd(11),
        q.meetsBar ? 'meets bar' : 'below bar',
        'by ' + d.authorName,
        'updated ' + iso(d.updatedAt),
      ].join('  '));
    }
    return;
  }

  if (cmd === 'show') {
    const { data } = await getReport(db, slug);
    const q = quality(data);
    console.log(`${data.whiteName} (${data.whiteRating || '-'}) vs ${data.blackName} (${data.blackRating || '-'})  ${data.result}  ${data.opening || ''}`);
    console.log(`by ${data.authorName} · approved: ${data.approved} · own words: ${q.ownWords} · commented moments: ${q.commented}`);
    console.log(`viewer: https://chessdiary.app/g/${data.slug}/\n\nNOTES\n${data.notes || '(none)'}\n`);
    for (const m of data.moments || []) {
      console.log(`MOMENT ply ${m.ply} ${m.move} (${m.quality})\n${m.comment || '(no comment)'}\n`);
    }
    return;
  }

  if (cmd === 'approve') {
    const { ref, data } = await getReport(db, slug);
    const q = quality(data);
    if (!q.meetsBar && !flag('--force')) {
      throw new Error(`Below the publishing bar (${q.ownWords}/${MIN_OWN_WORDS} own words, ` +
        `${q.commented}/${MIN_COMMENTED_MOMENTS} commented moments). Use --force to approve anyway; ` +
        'build.js will still leave it out until it meets the bar.');
    }
    await ref.update({ approved: true });
    return console.log(`Approved ${slug}. It goes live as an indexed page on the next deploy (bash deploy.sh).`);
  }

  if (cmd === 'unapprove') {
    const { ref } = await getReport(db, slug);
    await ref.update({ approved: false });
    return console.log(`Unapproved ${slug}. The static page is removed on the next deploy; the share link keeps working (noindex).`);
  }

  if (cmd === 'takedown') {
    const { ref, data } = await getReport(db, slug);
    await ref.delete();
    if (data.ownerUid && data.sourceGameId) {
      const game = db.collection('users').doc(data.ownerUid).collection('games').doc(data.sourceGameId);
      const admin = loadAdmin();
      await game.update({ publicSlug: admin.firestore.FieldValue.delete() }).catch(() => {});
    }
    return console.log(`Took down ${slug}. The share link stops working now; redeploy to remove any static page.`);
  }

  console.log('Usage: reports.js list [--pending] | show <slug> | approve <slug> [--force] | unapprove <slug> | takedown <slug>');
  process.exitCode = 1;
}

main().catch((e) => { console.error(e.message); process.exit(1); });
