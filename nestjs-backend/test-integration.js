/**
 * Comprehensive Integration Test: Files, Chat, Reviews
 * Tests file proxy, Dateien screen endpoints, chat/feedback, and reviews.
 */
const https = require('https');

const BASE = 'https://admin-backend-php-production.up.railway.app';
const TRAINER_TOKEN = 'b7ad15d9955954cece0a54ed3588c104';
const TEST_CLIENT_ID = 23; // Jesko

function request(method, path, { token, body, followRedirect = false } = {}) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE);
    const headers = { 'Accept': 'application/json' };
    if (token) headers['x-auth-token'] = token;
    if (body) {
      headers['Content-Type'] = 'application/json';
    }

    const options = {
      hostname: url.hostname,
      port: 443,
      path: url.pathname + url.search,
      method,
      headers,
    };

    const req = https.request(options, (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => {
        const raw = Buffer.concat(chunks).toString();
        let data;
        try { data = JSON.parse(raw); } catch { data = raw; }
        resolve({
          status: res.statusCode,
          headers: res.headers,
          data,
          raw,
        });
      });
    });

    req.on('error', reject);
    req.setTimeout(15000, () => { req.destroy(); reject(new Error('Timeout')); });
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

// Download test (binary - check headers only)
function downloadTest(path, token) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE);
    const headers = { 'Accept': '*/*' };
    if (token) headers['x-auth-token'] = token;

    const options = {
      hostname: url.hostname,
      port: 443,
      path: url.pathname + url.search,
      method: 'GET',
      headers,
    };

    const req = https.request(options, (res) => {
      let size = 0;
      const first1k = [];
      res.on('data', (c) => {
        size += c.length;
        if (size <= 1024) first1k.push(c);
      });
      res.on('end', () => {
        resolve({
          status: res.statusCode,
          headers: res.headers,
          size,
          first1k: Buffer.concat(first1k).toString('utf8').slice(0, 200),
        });
      });
    });

    req.on('error', reject);
    req.setTimeout(20000, () => { req.destroy(); reject(new Error('Timeout')); });
    req.end();
  });
}

let passed = 0;
let failed = 0;
const failures = [];

function assert(condition, testName, detail) {
  if (condition) {
    passed++;
    console.log(`  ✅ ${testName}`);
  } else {
    failed++;
    failures.push({ testName, detail });
    console.log(`  ❌ ${testName} — ${detail || ''}`);
  }
}

async function run() {
  console.log('=== INTEGRATION TEST: Dateien, Chat, Reviews ===\n');
  console.log(`Base: ${BASE}`);
  console.log(`Token: ${TRAINER_TOKEN.slice(0, 8)}...`);
  console.log(`Client: ${TEST_CLIENT_ID}\n`);

  // ─── 1. FILE LIST (Trainer App) ───
  console.log('── 1. File List (Trainer: GET /api/file?client_id=23) ──');
  const fileList = await request('GET', `/api/file?client_id=${TEST_CLIENT_ID}`, { token: TRAINER_TOKEN });
  assert(fileList.status === 200, 'File list returns 200', `got ${fileList.status}`);
  const files = Array.isArray(fileList.data) ? fileList.data : [];
  assert(files.length > 0, `Files found for client ${TEST_CLIENT_ID}`, `count: ${files.length}`);

  if (files.length > 0) {
    const f = files[0];
    assert(f.file && f.file.startsWith('/api/file/'), 'File URL is proxy format', `got: ${f.file}`);
    assert(!f.file_original, 'No file_original exposed', f.file_original ? `EXPOSED: ${f.file_original}` : '');
    assert(f.id !== undefined, 'Has id field', JSON.stringify(Object.keys(f)));
    assert(f.name !== undefined || f.name === null, 'Has name field');
    assert(f.date !== undefined, 'Has date field');
    assert(f.client_id !== undefined, 'Has client_id field');
  }

  // ─── 2. FILE DOWNLOAD PROXY (Auth) ───
  console.log('\n── 2. File Download Proxy (Auth required) ──');
  if (files.length > 0) {
    const fileId = files[0].id;
    const dlPath = `/api/file/${fileId}/download`;

    // Without auth → should fail
    const noAuth = await downloadTest(dlPath, null);
    assert(noAuth.status === 401 || noAuth.status === 403, 'Download without auth blocked', `status: ${noAuth.status}`);

    // With auth → should stream file
    const withAuth = await downloadTest(dlPath, TRAINER_TOKEN);
    assert(withAuth.status === 200, 'Download with auth succeeds', `status: ${withAuth.status}`);
    if (withAuth.status === 200) {
      assert(withAuth.headers['content-type'] !== undefined, 'Has Content-Type header', withAuth.headers['content-type']);
      assert(
        withAuth.headers['content-disposition'] !== undefined,
        'Has Content-Disposition header',
        withAuth.headers['content-disposition']
      );
      assert(
        withAuth.headers['x-content-type-options'] === 'nosniff',
        'Has X-Content-Type-Options: nosniff',
        withAuth.headers['x-content-type-options']
      );
      assert(withAuth.size > 100, 'File has content', `size: ${withAuth.size} bytes`);
    }

    // With query token → should also work (for iframe/browser access)
    const queryToken = await downloadTest(`${dlPath}?token=${TRAINER_TOKEN}`, null);
    assert(queryToken.status === 200, 'Download with query token works', `status: ${queryToken.status}`);
  }

  // ─── 3. FILE LIST (Client App) ───
  console.log('\n── 3. File List (Client App: GET /api/client/files/23) ──');
  const clientFiles = await request('GET', `/api/client/files/${TEST_CLIENT_ID}`, { token: TRAINER_TOKEN });
  assert(clientFiles.status === 200, 'Client files endpoint returns 200', `got ${clientFiles.status}`);
  const cFiles = Array.isArray(clientFiles.data) ? clientFiles.data : [];
  assert(cFiles.length > 0, 'Client files found', `count: ${cFiles.length}`);
  if (cFiles.length > 0) {
    assert(cFiles[0].file && cFiles[0].file.startsWith('/api/file/'), 'Client files use proxy URL', `got: ${cFiles[0].file}`);
  }

  // ─── 4. MULTIPLE FILE DOWNLOADS (Bulk) ───
  console.log('\n── 4. Bulk Download Test (first 10 files) ──');
  const testFiles = files.slice(0, 10);
  let downloadSuccess = 0;
  let downloadFail = 0;
  for (const f of testFiles) {
    try {
      const dl = await downloadTest(`/api/file/${f.id}/download`, TRAINER_TOKEN);
      if (dl.status === 200 && dl.size > 0) {
        downloadSuccess++;
      } else {
        downloadFail++;
        console.log(`    ⚠️  File ${f.id}: status=${dl.status}, size=${dl.size}`);
      }
    } catch (e) {
      downloadFail++;
      console.log(`    ⚠️  File ${f.id}: ${e.message}`);
    }
  }
  // Most files should download; a few old ones on www.sihltraining.ch may still 403
  const successRate = downloadSuccess / testFiles.length;
  assert(successRate >= 0.7, `≥70% downloads succeed (${downloadSuccess}/${testFiles.length})`, `${Math.round(successRate*100)}%`);

  // ─── 5. CHAT / FEEDBACK ───
  console.log('\n── 5. Chat/Feedback (GET /api/feedback?client_id=23) ──');
  const chatResp = await request('GET', `/api/feedback?client_id=${TEST_CLIENT_ID}`, { token: TRAINER_TOKEN });
  assert(chatResp.status === 200, 'Feedback endpoint returns 200', `got ${chatResp.status}`);
  const chats = Array.isArray(chatResp.data) ? chatResp.data : (chatResp.data?.data || []);
  console.log(`  ℹ️  Messages found: ${chats.length}`);

  if (chats.length > 0) {
    const msg = chats[0];
    assert(msg.text !== undefined || msg.message !== undefined, 'Message has text or message field', JSON.stringify(Object.keys(msg)));
    assert(msg.client_id !== undefined, 'Message has client_id', JSON.stringify(Object.keys(msg)));
    // Check for file references in chat
    const fileMessages = chats.filter(m => m.file || m.attachment || m.image);
    console.log(`  ℹ️  Messages with file/attachment/image: ${fileMessages.length}`);
    if (fileMessages.length > 0) {
      const fm = fileMessages[0];
      console.log(`    Sample file message keys: ${JSON.stringify(Object.keys(fm))}`);
      if (fm.file) console.log(`    file field: ${fm.file}`);
      if (fm.image) console.log(`    image field: ${fm.image}`);
    }
  }

  // ─── 6. REVIEWS ───
  console.log('\n── 6. Reviews (GET /api/review?client_id=23) ──');
  const reviewResp = await request('GET', `/api/review?client_id=${TEST_CLIENT_ID}`, { token: TRAINER_TOKEN });
  assert(reviewResp.status === 200, 'Review endpoint returns 200', `got ${reviewResp.status}`);
  const reviews = Array.isArray(reviewResp.data) ? reviewResp.data : (reviewResp.data?.data || []);
  console.log(`  ℹ️  Reviews found: ${reviews.length}`);

  if (reviews.length > 0) {
    const r = reviews[0];
    assert(r.id !== undefined, 'Review has id');
    // Reviews link to clients through training_id, not directly via client_id
    assert(r.training_id !== undefined || r.training !== undefined, 'Review linked to training', JSON.stringify(Object.keys(r)));
    assert(r.heart_rate !== undefined, 'Review has heart_rate data');
    console.log(`    Sample review keys: ${JSON.stringify(Object.keys(r))}`);
    console.log(`    heart_rate: ${r.heart_rate}, training_type: ${r.training_type}`);
  }

  // ─── 7. ALL CLIENTS FILE CHECK ───
  console.log('\n── 7. All Clients — File Availability ──');
  const clientsResp = await request('GET', '/api/client', { token: TRAINER_TOKEN });
  assert(clientsResp.status === 200, 'Client list returns 200', `got ${clientsResp.status}`);
  const clients = Array.isArray(clientsResp.data) ? clientsResp.data : [];
  console.log(`  ℹ️  Total clients: ${clients.length}`);

  let clientsWithFiles = 0;
  let clientsChecked = 0;
  const clientErrors = [];

  // Check files for each client (limit to avoid timeout)
  for (const c of clients.slice(0, 30)) {
    try {
      const resp = await request('GET', `/api/file?client_id=${c.id}`, { token: TRAINER_TOKEN });
      clientsChecked++;
      if (resp.status === 200) {
        const cf = Array.isArray(resp.data) ? resp.data : [];
        if (cf.length > 0) {
          clientsWithFiles++;
          // Verify proxy URLs
          const hasDirectUrl = cf.some(f => f.file && !f.file.startsWith('/api/file/'));
          if (hasDirectUrl) {
            clientErrors.push(`Client ${c.id} (${c.vorname || ''} ${c.name || ''}): has direct URL exposed!`);
          }
        }
      } else {
        clientErrors.push(`Client ${c.id}: status ${resp.status}`);
      }
    } catch (e) {
      clientErrors.push(`Client ${c.id}: ${e.message}`);
    }
  }

  console.log(`  ℹ️  Clients checked: ${clientsChecked}`);
  console.log(`  ℹ️  Clients with files: ${clientsWithFiles}`);
  assert(clientErrors.length === 0, 'No errors in client file checks', clientErrors.join('; '));

  // ─── 8. FILE METADATA ───
  console.log('\n── 8. Single File Metadata (GET /api/file/:id) ──');
  if (files.length > 0) {
    const singleFile = await request('GET', `/api/file/${files[0].id}`, { token: TRAINER_TOKEN });
    assert(singleFile.status === 200, 'Single file metadata returns 200', `got ${singleFile.status}`);
    if (singleFile.status === 200) {
      const sf = singleFile.data;
      assert(sf.file && sf.file.startsWith('/api/file/'), 'Single file has proxy URL', sf.file);
      // Note: single file endpoint shows file_original for admin
      console.log(`    file: ${sf.file}`);
      console.log(`    file_original: ${sf.file_original || 'N/A'}`);
    }
  }

  // ─── 9. ALL FILES COUNT ───
  console.log('\n── 9. Total Files in System ──');
  const allFiles = await request('GET', '/api/file', { token: TRAINER_TOKEN });
  assert(allFiles.status === 200, 'All files endpoint returns 200', `got ${allFiles.status}`);
  const totalFiles = Array.isArray(allFiles.data) ? allFiles.data : [];
  console.log(`  ℹ️  Total files in database: ${totalFiles.length}`);
  const filesWithUrl = totalFiles.filter(f => f.file);
  console.log(`  ℹ️  Files with download URL: ${filesWithUrl.length}`);
  const filesWithoutUrl = totalFiles.filter(f => !f.file);
  if (filesWithoutUrl.length > 0) {
    console.log(`  ⚠️  Files without URL: ${filesWithoutUrl.length}`);
  }

  // ─── 10. CONTENT TYPE VERIFICATION ───
  console.log('\n── 10. Content Type Verification (PDF check) ──');
  // Use the first file (most are PDFs based on the data)
  const pdfFile = files.length > 0 ? files[0] : null;
  if (pdfFile) {
    const pdfDl = await downloadTest(`/api/file/${pdfFile.id}/download`, TRAINER_TOKEN);
    assert(pdfDl.status === 200, 'PDF download succeeds', `status: ${pdfDl.status}`);
    if (pdfDl.status === 200) {
      assert(
        pdfDl.headers['content-type'] === 'application/pdf',
        'PDF has correct Content-Type',
        `got: ${pdfDl.headers['content-type']}`
      );
      // PDF files should have significant content
      assert(
        pdfDl.size > 1000,
        'PDF has significant file size',
        `size: ${pdfDl.size} bytes`
      );
    }
  } else {
    console.log('  ⚠️  No PDF file found in client files to test');
  }

  // ─── SUMMARY ───
  console.log('\n' + '='.repeat(50));
  console.log(`\n✅ PASSED: ${passed}`);
  console.log(`❌ FAILED: ${failed}`);

  if (failures.length > 0) {
    console.log('\n── Failed Tests ──');
    failures.forEach(f => console.log(`  • ${f.testName}: ${f.detail}`));
  }

  console.log('\n' + '='.repeat(50));
  process.exit(failed > 0 ? 1 : 0);
}

run().catch(e => {
  console.error('Fatal error:', e);
  process.exit(2);
});
