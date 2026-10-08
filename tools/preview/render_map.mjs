// uso: node render_map.mjs <scene.json> <outdir> [viste: all | nome1,nome2] [preview.json]
import http from 'http';
import fs from 'fs';
import path from 'path';
import { chromium } from 'playwright-core';

const ROOT = path.dirname(new URL(import.meta.url).pathname);
const sceneFile = path.resolve(process.argv[2]);
const outDir = path.resolve(process.argv[3] || path.join(ROOT, 'shots'));
const only = process.argv[4] && process.argv[4] !== 'all' ? process.argv[4].split(',') : null;
const previewFile = process.argv[5] ? path.resolve(process.argv[5]) : null;
const views = JSON.parse(fs.readFileSync(path.join(ROOT, 'views.json'), 'utf8'));
const MIME = { '.js': 'text/javascript', '.mjs': 'text/javascript', '.html': 'text/html', '.json': 'application/json' };

const server = http.createServer((req, res) => {
  const u = decodeURIComponent(req.url.split('?')[0]);
  const p = u === '/scene.json' ? sceneFile : path.join(ROOT, u);
  if (!fs.existsSync(p) || fs.statSync(p).isDirectory()) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'content-type': MIME[path.extname(p)] || 'application/octet-stream' });
  fs.createReadStream(p).pipe(res);
}).listen(0);
const port = server.address().port;

const browser = await chromium.launch({
  executablePath: process.env.CHROMIUM_PATH || undefined,
  args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--use-gl=angle', '--no-sandbox'],
});
const W = Number(process.env.VIEW_W || 1600), H = Number(process.env.VIEW_H || 900);
const page = await browser.newPage({ viewport: { width: W, height: H } });
page.on('console', (m) => { const t = m.text(); if (m.type() === 'error' || m.type() === 'warning' || /terreno/.test(t)) console.log('[browser]', t.slice(0, 300)); });
page.on('pageerror', (e) => console.log('[pageerror]', e.message));
const preview = previewFile ? JSON.parse(fs.readFileSync(previewFile, 'utf8')) : {};
await page.addInitScript(({ preview, W, H }) => { window.PREVIEW = preview; window.VIEW_W = W; window.VIEW_H = H; }, { preview, W, H });
await page.goto(`http://localhost:${port}/viewer_map.html`);
await page.waitForFunction('window.ready === true', null, { timeout: 60000 });
const extras = views._extras || {};
const t0 = Date.now();
const info = await page.evaluate(([u, e]) => window.loadScene(u, e), ['/scene.json', extras]);
console.log('scena caricata', JSON.stringify(info), ((Date.now() - t0) / 1000).toFixed(1) + 's');
fs.mkdirSync(outDir, { recursive: true });
for (const [name, v] of Object.entries(views)) {
  if (name.startsWith('_')) continue;
  if (only && !only.includes(name)) continue;
  const t1 = Date.now();
  await page.evaluate((vv) => window.setView(vv), v);
  await page.locator('canvas').screenshot({ path: path.join(outDir, name + '.png') });
  console.log(' ', name, ((Date.now() - t1) / 1000).toFixed(1) + 's');
}
await browser.close();
server.close();
