// Layout check: opens tests/out/preview_koKR.html and prints every layout
// problem the page found (text cut off or spilling out, overlaps, things
// hidden under other things, outside the window, the same button twice, text
// too small to read). Exit code 1 when there is any.
//   python3 tests/preview.py && node tests/layout_check.js [--json out.json] [scene ...]
const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

(async () => {
  const args = process.argv.slice(2);
  let jsonOut = null;
  const only = [];
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--json') jsonOut = args[++i]; else only.push(args[i]);
  }
  const html = path.resolve(__dirname, 'out', 'preview_koKR.html');
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1400, height: 900 } });
  await page.goto('file://' + html);
  await page.waitForFunction(() => document.title === 'ready', null, { timeout: 120000 });
  let issues = await page.evaluate(() => window.LINT);
  const scenes = await page.evaluate(() => SCENES.map(s => s[0]));
  await browser.close();
  if (only.length) issues = issues.filter(i => only.includes(i.scene));
  const by = {};
  for (const i of issues) (by[i.scene] = by[i.scene] || []).push(i);
  for (const s of scenes) {
    if (only.length && !only.includes(s)) continue;
    const list = by[s] || [];
    console.log((list.length ? 'FAIL ' : 'ok   ') + s + (list.length ? '  (' + list.length + ')' : ''));
    for (const i of list) console.log('    [' + i.kind + '] ' + i.msg + ': ' + i.items.join('  /  '));
  }
  const kinds = {};
  for (const i of issues) kinds[i.kind] = (kinds[i.kind] || 0) + 1;
  console.log('\nlayout problems: ' + issues.length + '  ' + JSON.stringify(kinds));
  if (jsonOut) fs.writeFileSync(jsonOut, JSON.stringify(issues, null, 1));
  process.exit(issues.length ? 1 : 0);
})();
