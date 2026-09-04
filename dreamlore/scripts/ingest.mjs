// Build data/index.json from the downloaded raw texts:
//   raw text → strip boilerplate → chunk → (embed if API provider) → index.
// Stub provider stores text only (vectors recomputed on load); openai/voyage
// store real vectors. The embedding-space id is stamped in so queries can't
// silently run against a mismatched index.
import fs from 'node:fs';
import path from 'node:path';
import { RAW_DIR, INDEX_PATH, config, embeddingSpaceId } from '../src/config.mjs';
import { SOURCES } from '../src/sources.mjs';
import { chunkSource } from '../src/chunk.mjs';
import { embed, tokens } from '../src/embeddings.mjs';

async function main() {
  const chunks = [];
  const sourcesUsed = [];

  for (const src of SOURCES) {
    const file = path.join(RAW_DIR, `${src.id}.txt`);
    if (!fs.existsSync(file)) {
      console.warn(`skip ${src.id} — not downloaded (run: npm run download)`);
      continue;
    }
    const c = chunkSource(fs.readFileSync(file, 'utf8'), src);
    chunks.push(...c);
    sourcesUsed.push({ id: src.id, title: src.title, author: src.author, license: src.license, chunks: c.length });
    console.log(`${src.id.padEnd(18)} ${String(c.length).padStart(5)} chunks`);
  }

  // Bring-your-own sources added via `npm run add` (data/raw/local/*.meta.json)
  const localDir = path.join(RAW_DIR, 'local');
  if (fs.existsSync(localDir)) {
    for (const metaFile of fs.readdirSync(localDir).filter((f) => f.endsWith('.meta.json'))) {
      const src = JSON.parse(fs.readFileSync(path.join(localDir, metaFile), 'utf8'));
      const txt = path.join(localDir, metaFile.replace('.meta.json', '.txt'));
      if (!fs.existsSync(txt)) continue;
      const c = chunkSource(fs.readFileSync(txt, 'utf8'), src);
      chunks.push(...c);
      sourcesUsed.push({ id: src.id, title: src.title, author: src.author, license: src.license, chunks: c.length });
      console.log(`${src.id.padEnd(18)} ${String(c.length).padStart(5)} chunks  [local]`);
    }
  }

  if (chunks.length === 0) {
    console.error('No chunks. Run: npm run download');
    process.exit(1);
  }

  let embedded = false;
  let dim = null;

  if (config.embeddingsProvider !== 'stub') {
    console.log(`\nEmbedding ${chunks.length} chunks via ${config.embeddingsProvider} (${embeddingSpaceId()}) …`);
    const vecs = await embed(chunks.map((c) => c.text), { inputType: 'document' });
    chunks.forEach((c, i) => (c.embedding = vecs[i]));
    dim = vecs[0]?.length ?? null;
    embedded = true;
  }

  // For the stub provider, compute corpus IDF so distinctive terms outweigh
  // words shared by every entry. Stored in the index; applied on load + query.
  let idf = null;
  let idfDefault = 1;
  if (config.embeddingsProvider === 'stub') {
    const df = new Map();
    for (const c of chunks) for (const t of new Set(tokens(c.text))) df.set(t, (df.get(t) || 0) + 1);
    const N = chunks.length;
    idf = {};
    for (const [t, d] of df) idf[t] = Math.log((N + 1) / (d + 1)) + 1;
    idfDefault = Math.log(N + 1) + 1;
    console.log(`idf: ${Object.keys(idf).length} unique terms`);
  }

  const index = {
    meta: {
      space: embeddingSpaceId(),
      provider: config.embeddingsProvider,
      embedded,
      dim,
      idf,
      idfDefault,
      chunks: chunks.length,
      sources: sourcesUsed,
      builtAt: new Date().toISOString(),
    },
    chunks,
  };

  fs.writeFileSync(INDEX_PATH, JSON.stringify(index));
  const kb = (fs.statSync(INDEX_PATH).size / 1024).toFixed(0);
  console.log(`\nWrote ${INDEX_PATH}`);
  console.log(`  ${chunks.length} chunks · space=${index.meta.space} · embedded=${embedded} · ${kb} KB`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
