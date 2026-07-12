// Load the prebuilt index and do brute-force cosine top-K. The corpus is small
// and static, so an in-memory scan is instant and needs zero infra. The same
// retrieve() signature ports directly to pgvector / Cloudflare Vectorize later.
import fs from 'node:fs';
import { INDEX_PATH } from './config.mjs';
import { stubEmbedOne } from './embeddings.mjs';

export function loadIndex(p = INDEX_PATH) {
  if (!fs.existsSync(p)) {
    throw new Error(
      `Index not found at ${p}\nBuild it first:  npm run download && npm run ingest`,
    );
  }
  return JSON.parse(fs.readFileSync(p, 'utf8'));
}

// Stub indexes store text only (to keep the file small); recompute their
// deterministic vectors in memory. API indexes already carry vectors.
export function hydrate(index) {
  if (index.meta?.embedded) return index;
  const idf = index.meta?.idf || null;
  const idfDefault = index.meta?.idfDefault || 1;
  for (const c of index.chunks) {
    if (!c.embedding) {
      // Boost the dictionary headword so a dream's named symbol ranks higher.
      const text = c.heading ? `${c.heading}. ${c.heading}. ${c.text}` : c.text;
      c.embedding = stubEmbedOne(text, { idf, idfDefault });
    }
  }
  return index;
}

// Handles both stub sparse vectors ({token: weight}, pre-normalized) and dense
// API vectors (number[]). Sparse cosine = dot product over shared keys.
export function cosine(a, b) {
  if (!Array.isArray(a) && !Array.isArray(b)) {
    const [small, large] =
      Object.keys(a).length <= Object.keys(b).length ? [a, b] : [b, a];
    let dot = 0;
    for (const k in small) if (k in large) dot += small[k] * large[k];
    return dot;
  }
  let dot = 0;
  let na = 0;
  let nb = 0;
  const n = Math.min(a.length, b.length);
  for (let i = 0; i < n; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  return dot / (Math.sqrt(na) * Math.sqrt(nb) || 1);
}

export function retrieve(index, queryEmbedding, k = 6) {
  return index.chunks
    .map((chunk) => ({ chunk, score: cosine(queryEmbedding, chunk.embedding) }))
    .sort((a, b) => b.score - a.score)
    .slice(0, k);
}
