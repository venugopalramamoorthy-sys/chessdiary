#!/usr/bin/env node
// Builds static pages for approved public game reports into the Flutter web
// build, so Google sees plain HTML (the in-browser viewer at /g/ is noindex).
//
//   node tools/public-games/build.js --out build/web            # from Firestore
//   node tools/public-games/build.js --out <dir> --fixture f.json  # offline test
//
// Run by deploy.sh after `flutter build web`. Writes:
//   <out>/g/<slug>/index.html   one indexable page per approved report
//   <out>/games/index.html      the hub listing them (noindex while empty)
//   <out>/sitemap.xml           with the hub and every report added
// Reads Firestore with the Admin SDK key in serviceAccount.json at the repo
// root (gitignored), or GOOGLE_APPLICATION_CREDENTIALS.
'use strict';

const fs = require('fs');
const path = require('path');
const { approvedForIndex, SLUG_RE, loadAdmin } = require('./common');
const CDReport = require('../../web/g/report-render.js');

const SITE = 'https://chessdiary.app';
const ADSENSE = '<script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-1687484988403199" crossorigin="anonymous"></script>';

function arg(name) {
  const i = process.argv.indexOf(name);
  return i > 0 ? process.argv[i + 1] : undefined;
}

function toIso(v) {
  if (!v) return undefined;
  if (typeof v === 'string') return v;
  if (typeof v.toDate === 'function') return v.toDate().toISOString();
  return undefined;
}

// Firestore document data -> plain report object for the renderer.
function normalise(data) {
  return CDReport.fromStored({ ...data, publishedAt: toIso(data.publishedAt), updatedAt: toIso(data.updatedAt) });
}

async function loadReports() {
  const fixture = arg('--fixture');
  if (fixture) return JSON.parse(fs.readFileSync(fixture, 'utf8'));
  const admin = loadAdmin();
  const snap = await admin.firestore().collection('publicGames').where('approved', '==', true).get();
  return snap.docs.map((d) => d.data());
}

function replaceBlock(html, name, content) {
  const re = new RegExp('<!--CD:' + name + '-->[\\s\\S]*?<!--/CD:' + name + '-->');
  if (!re.test(html)) throw new Error('Template is missing the CD:' + name + ' block');
  return html.replace(re, content);
}

function fill(template, page, { indexable, ads, backLink }) {
  const esc = CDReport.esc;
  const url = SITE + page.path;
  let html = template
    .replace(/<title>[\s\S]*?<\/title>/, '<title>' + esc(page.title) + ' — ChessDiary</title>')
    .replace(/<meta name="description" content="[^"]*">/, '<meta name="description" content="' + esc(page.description) + '">')
    .replace(/<main id="report">[\s\S]*?<\/main>/, () => '<main id="report">\n' + page.html + '\n  </main>');
  if (backLink) html = html.replace(/<a href="\/games\/" class="back-link">[^<]*<\/a>/, backLink);
  html = replaceBlock(html, 'ROBOTS', indexable ? '' : '<meta name="robots" content="noindex">');
  const head = [
    '<link rel="canonical" href="' + url + '">',
    '<meta property="og:type" content="article">',
    '<meta property="og:site_name" content="ChessDiary">',
    '<meta property="og:title" content="' + esc(page.title) + '">',
    '<meta property="og:description" content="' + esc(page.description) + '">',
    '<meta property="og:url" content="' + url + '">',
    '<meta property="og:image" content="' + SITE + '/icons/Icon-512.png">',
    '<meta name="twitter:card" content="summary">',
  ];
  if (page.jsonLd) head.push('<script type="application/ld+json">' + JSON.stringify(page.jsonLd).replace(/</g, '\\u003c') + '</script>');
  if (ads) head.push('<!-- Google AdSense -->', ADSENSE);
  html = replaceBlock(html, 'HEAD', head.join('\n  '));
  return replaceBlock(html, 'LOADER', '');
}

function addToSitemap(file, entries) {
  if (!fs.existsSync(file) || !entries.length) return;
  const xml = fs.readFileSync(file, 'utf8');
  const urls = entries.map((e) =>
    '  <url>\n    <loc>' + SITE + e.path + '</loc>\n    <lastmod>' + e.lastmod + '</lastmod>\n  </url>').join('\n');
  if (!xml.includes('</urlset>')) throw new Error('sitemap.xml has no </urlset>');
  fs.writeFileSync(file, xml.replace('</urlset>', urls + '\n</urlset>'));
}

async function main() {
  const out = arg('--out');
  if (!out) throw new Error('Usage: build.js --out <web build dir> [--fixture file.json]');
  const template = fs.readFileSync(path.join(out, 'g', 'index.html'), 'utf8');

  const reports = (await loadReports())
    .filter((d) => {
      if (!SLUG_RE.test(d.slug || '')) { console.warn('  skipping report with invalid slug:', d.slug); return false; }
      // Approval is a human decision, but a report edited below the bar after
      // approval should not stay indexed.
      if (d.approved !== true) return false;
      if (!approvedForIndex(d)) { console.warn('  skipping', d.slug, '- approved but now below the publishing bar'); return false; }
      return true;
    })
    .map(normalise)
    .sort((a, b) => String(b.publishedAt).localeCompare(String(a.publishedAt)));

  const sitemap = [];
  for (const r of reports) {
    const page = CDReport.render(r);
    const dir = path.join(out, 'g', r.slug);
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(path.join(dir, 'index.html'), fill(template, page, { indexable: true, ads: true }));
    sitemap.push({ path: page.path, lastmod: (r.updatedAt || r.publishedAt || '').slice(0, 10) });
  }

  const hub = {
    title: 'Player-Annotated Chess Games',
    description: 'Real chess games published by the players who played them, with their own notes and Stockfish analysis of the critical moments.',
    path: '/games/',
    html: CDReport.renderIndex(reports),
  };
  fs.mkdirSync(path.join(out, 'games'), { recursive: true });
  fs.writeFileSync(path.join(out, 'games', 'index.html'), fill(template, hub, {
    indexable: reports.length > 0,
    ads: false,
    backLink: '<a href="/" class="back-link">← Home</a>',
  }));
  if (reports.length) {
    sitemap.unshift({ path: '/games/', lastmod: sitemap.map((s) => s.lastmod).sort().pop() });
  }
  addToSitemap(path.join(out, 'sitemap.xml'), sitemap);

  console.log('Public game reports: built ' + reports.length + ' page(s) and /games/' +
    (reports.length ? '' : ' (empty, noindex)'));
}

main().then(() => process.exit(0), (e) => { console.error('build.js failed:', e.message); process.exit(1); });
