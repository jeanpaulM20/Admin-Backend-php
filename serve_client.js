const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');
const url = require('url');

const WEB_DIR = path.join(__dirname, 'nestjs-backend', 'public');
const PROXY_HOST = 'apps.sihltraining.ch';
const PORT = 8083;

const MIME = {
  '.html': 'text/html', '.js': 'application/javascript', '.css': 'text/css',
  '.png': 'image/png', '.jpg': 'image/jpeg', '.svg': 'image/svg+xml',
  '.json': 'application/json', '.wasm': 'application/wasm',
  '.ttf': 'font/ttf', '.otf': 'font/otf', '.ico': 'image/x-icon',
};

http.createServer((req, res) => {
  const parsed = url.parse(req.url);

  if (parsed.pathname.startsWith('/api/')) {
    const options = {
      hostname: PROXY_HOST, port: 443, path: req.url,
      method: req.method, headers: { ...req.headers, host: PROXY_HOST },
      rejectUnauthorized: false,
    };
    const proxy = https.request(options, (pres) => {
      res.writeHead(pres.statusCode, pres.headers);
      pres.pipe(res);
    });
    proxy.on('error', (e) => { res.writeHead(502); res.end('Proxy error: ' + e.message); });
    req.pipe(proxy);
    return;
  }

  // Strip /client/ prefix for file serving
  let pathname = parsed.pathname;
  if (pathname.startsWith('/client/')) pathname = pathname.slice('/client/'.length);
  if (!pathname || pathname === '/') pathname = 'index.html';

  let filePath = path.join(WEB_DIR, pathname);
  if (!fs.existsSync(filePath)) filePath = path.join(WEB_DIR, 'index.html');

  const ext = path.extname(filePath);
  const mime = MIME[ext] || 'application/octet-stream';
  fs.readFile(filePath, (err, data) => {
    if (err) { res.writeHead(404); res.end('Not found'); return; }
    res.writeHead(200, { 'Content-Type': mime });
    res.end(data);
  });
}).listen(PORT, () => console.log('Client app: http://localhost:' + PORT + '/client/'));
