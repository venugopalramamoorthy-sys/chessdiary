// Deep check: every page in the sitemap (plus a few special ones) at phone
// width -- loads, GA tag present, no script errors, no sideways scroll --
// and every internal link on those pages resolves.
const { chromium } = require('@playwright/test');
const { SITE, checker } = require('./common');

(async () => {
  const { check, done } = checker();
  const sm = await (await fetch(`${SITE}/sitemap.xml`)).text();
  const urls = [...sm.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => m[1]);
  check('sitemap lists pages', urls.length >= 20, `${urls.length} URLs`);
  urls.push(`${SITE}/games/`, `${SITE}/contact/?report=2026-11-test-abc123`, `${SITE}/404-check-nope/`);

  const browser = await chromium.launch();
  const ctx = await browser.newContext({ viewport: { width: 390, height: 800 } });
  const links = new Set();
  for (const url of urls) {
    const p = url.replace(SITE, '');
    const page = await ctx.newPage();
    const errs = [];
    page.on('pageerror', (e) => errs.push(e.message));
    page.on('console', (m) => {
      if (m.type() === 'error' && !/adsbygoogle|googlesyndication|doubleclick|Failed to load resource/.test(m.text())) errs.push(m.text());
    });
    try {
      const res = await page.goto(url, { waitUntil: 'load', timeout: 45_000 });
      const info = await page.evaluate(() => ({
        ga: !!document.querySelector('script[src*="gtag/js?id=G-8KWDLD0JLY"]'),
        overflow: document.documentElement.scrollWidth - window.innerWidth,
        msg: (document.getElementById('message') || {}).value || '',
        links: [...document.querySelectorAll('a[href^="/"]')].map((a) => a.getAttribute('href')),
      }));
      info.links.forEach((l) => links.add(l.split('#')[0].split('?')[0]));
      const bad = [];
      const want = p.startsWith('/404-check') ? 404 : 200;
      if (res.status() !== want) bad.push('status ' + res.status());
      if (!info.ga) bad.push('no GA tag');
      if (info.overflow > 1) bad.push(`overflows ${info.overflow}px`);
      if (errs.length) bad.push('errors: ' + errs.join(' | ').slice(0, 200));
      if (p.startsWith('/contact/?report') && !info.msg.includes('/g/2026-11-test-abc123/')) bad.push('report prefill missing');
      check(`page ${p}`, !bad.length, bad.join('; '));
    } catch (e) {
      check(`page ${p}`, false, e.message.split('\n')[0]);
    }
    await page.close();
  }
  await browser.close();

  for (const l of links) {
    if (l === '/app' || l.startsWith('/app/')) continue;
    const r = await fetch(SITE + l);
    if (r.status !== 200) check(`link ${l}`, false, 'HTTP ' + r.status);
  }
  check(`${links.size} internal links resolve`, true);
  done();
})().catch((e) => { console.log('FAIL sweep crashed  ' + e.message); console.log('SUMMARY 0 1'); process.exitCode = 1; });
