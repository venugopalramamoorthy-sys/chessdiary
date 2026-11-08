#!/usr/bin/env node
// Offline checks for the report renderer and build: builds fixture.json into
// a temp copy of web/ and asserts on the output. Run: node test.js
'use strict';

const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');
const { quality } = require('./common');

const web = path.resolve(__dirname, '..', '..', 'web');
const out = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-public-games-'));
fs.mkdirSync(path.join(out, 'g'));
fs.copyFileSync(path.join(web, 'g', 'index.html'), path.join(out, 'g', 'index.html'));
fs.copyFileSync(path.join(web, 'sitemap.xml'), path.join(out, 'sitemap.xml'));

function build(fixture) {
  return execFileSync(process.execPath, [path.join(__dirname, 'build.js'), '--out', out, '--fixture', fixture], { encoding: 'utf8' });
}

const fixture = JSON.parse(fs.readFileSync(path.join(__dirname, 'fixture.json'), 'utf8'));
assert.ok(quality(fixture[0]).meetsBar, 'fixture report should meet the bar');
assert.ok(!quality(fixture[1]).meetsBar, 'short report should not meet the bar');

build(path.join(__dirname, 'fixture.json'));
const read = (p) => fs.readFileSync(path.join(out, p), 'utf8');
const page = read('g/2026-10-philidor-defence-k3f9q2/index.html');

// Only the approved report that meets the bar gets a static page.
assert.deepStrictEqual(fs.readdirSync(path.join(out, 'g')).sort(), ['2026-10-philidor-defence-k3f9q2', 'index.html']);

// Indexable, canonical, ads, structured data; viewer script and noindex gone.
assert.ok(!page.includes('<meta name="robots"'), 'static report must be indexable');
assert.ok(page.includes('<link rel="canonical" href="https://chessdiary.app/g/2026-10-philidor-defence-k3f9q2/">'));
assert.ok(page.includes('pagead2.googlesyndication.com'), 'static report carries the AdSense script');
assert.ok(page.includes('"@type":"Article"') && page.includes('"datePublished":"2026-11-01"'));
assert.ok(!page.includes('report-render.js') && !page.includes('CD:LOADER') && !page.includes('CD:HEAD'));
assert.ok(page.includes("gtag('config', 'G-8KWDLD0JLY')"), 'GA tag must be present');
assert.ok(page.includes('location.replace("https://chessdiary.app"'), 'canonical-host redirect must be present');

// Content: notes, all three moments with boards, move list, guide links.
assert.ok(page.includes('Annotated by Knight Owl, who played Black'));
assert.strictEqual((page.match(/<figure class="board">/g) || []).length, 3);
assert.ok(page.includes('href="#cd-black-king"'), 'boards reference the shared piece defs');
assert.ok(page.includes('/guides/pins-skewers-and-discovered-attacks/'));
assert.ok(page.includes('/guides/back-rank-mate-how-to-stop-it/'));
assert.ok(page.includes('14&hellip;Qe6') && page.includes('Rd8#'));

// User text is escaped, never executed.
assert.ok(!page.includes("<script>alert('xss')</script>"));
assert.ok(page.includes('&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;'));

// Hub lists the report and is indexable; sitemap gained the hub and the report.
const hub = read('games/index.html');
assert.ok(hub.includes('/g/2026-10-philidor-defence-k3f9q2/') && !hub.includes('<meta name="robots"') && !hub.includes('pagead2'));
const sitemap = read('sitemap.xml');
assert.ok(sitemap.includes('<loc>https://chessdiary.app/games/</loc>'));
assert.ok(sitemap.includes('<loc>https://chessdiary.app/g/2026-10-philidor-defence-k3f9q2/</loc>\n    <lastmod>2026-11-03</lastmod>'));
assert.ok(!sitemap.includes('below-bar') && !sitemap.includes('pending'));

// With nothing approved the hub still exists (CTA links point at it) but is noindex.
fs.copyFileSync(path.join(web, 'sitemap.xml'), path.join(out, 'sitemap.xml'));
const empty = path.join(out, 'empty.json');
fs.writeFileSync(empty, '[]');
build(empty);
assert.ok(read('games/index.html').includes('<meta name="robots" content="noindex">'));
assert.ok(!read('sitemap.xml').includes('/games/'));

fs.rmSync(out, { recursive: true, force: true });
console.log('public-games: all checks passed');
