// Download the public-domain source texts from Project Gutenberg into data/raw/.
// Verifies provenance (author/title must appear in the file) so a wrong or
// renamed Gutenberg ID fails loudly instead of poisoning the knowledge base.
import fs from 'node:fs';
import path from 'node:path';
import { RAW_DIR } from '../src/config.mjs';
import { SOURCES, gutenbergTextUrl } from '../src/sources.mjs';

async function fetchText(url, timeoutMs = 60000) {
  const ac = new AbortController();
  const t = setTimeout(() => ac.abort(), timeoutMs);
  try {
    const res = await fetch(url, { signal: ac.signal, redirect: 'follow' });
    if (!res.ok) throw new Error(`HTTP ${res.status} for ${url}`);
    return await res.text();
  } finally {
    clearTimeout(t);
  }
}

async function main() {
  fs.mkdirSync(RAW_DIR, { recursive: true });
  const manifest = [];

  for (const src of SOURCES) {
    const url = gutenbergTextUrl(src.gutenbergId);
    process.stdout.write(`↓ ${src.id.padEnd(18)} #${src.gutenbergId} … `);
    let raw;
    try {
      raw = await fetchText(url);
    } catch (err) {
      console.log(`FAILED (${err.message})`);
      continue;
    }

    const hay = raw.toLowerCase();
    const missing = src.provenance.filter((p) => !hay.includes(p.toLowerCase()));
    if (missing.length) {
      console.log(
        `PROVENANCE MISMATCH — missing ${JSON.stringify(missing)}. Skipped.`,
      );
      continue;
    }

    const outPath = path.join(RAW_DIR, `${src.id}.txt`);
    fs.writeFileSync(outPath, raw, 'utf8');
    manifest.push({
      id: src.id,
      gutenbergId: src.gutenbergId,
      title: src.title,
      author: src.author,
      bytes: Buffer.byteLength(raw),
      file: path.basename(outPath),
      license: src.license,
    });
    console.log(`ok (${(raw.length / 1024).toFixed(0)} KB)`);
  }

  fs.writeFileSync(
    path.join(RAW_DIR, 'manifest.json'),
    JSON.stringify(manifest, null, 2),
  );
  console.log(
    `\nDownloaded ${manifest.length}/${SOURCES.length} sources → ${RAW_DIR}`,
  );
  if (manifest.length === 0) process.exit(1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
