// Bake data/index.json into worker/src/kb.json — the knowledge base the Worker
// ships with, so retrieval needs no Vectorize index and no embedding API.
//
// Two things happen here that keep the bundle small enough for a Worker:
//   1. Document vectors are PRECOMPUTED, so the Worker never spends startup CPU
//      re-tokenizing 3k chunks on every cold isolate.
//   2. Each vector keeps only its TOP_TERMS heaviest terms. Cosine is dominated
//      by the high-IDF terms; the long tail of near-zero weights costs bytes and
//      changes almost no rankings.
import fs from 'node:fs';
import path from 'node:path';
import { INDEX_PATH, ROOT } from '../src/config.mjs';
import { stubEmbedOne } from '../src/tokenize.mjs';

const TOP_TERMS = Number(process.env.TOP_TERMS || 48);
const PRECISION = 5;

const index = JSON.parse(fs.readFileSync(INDEX_PATH, 'utf8'));
if (index.meta?.provider !== 'stub') {
  console.error(
    `This index was built with "${index.meta?.provider}". The bundled Worker KB uses the\n` +
      'sparse stub space. Rebuild with:  npm run ingest\n',
  );
  process.exit(1);
}

const idf = index.meta.idf || null;
const idfDefault = index.meta.idfDefault || 1;

const chunks = index.chunks.map((c) => {
  // Same heading boost the Node retriever applies on load (retriever.mjs
  // hydrate), so a dream naming a symbol ranks that dictionary entry higher.
  const source = c.heading ? `${c.heading}. ${c.heading}. ${c.text}` : c.text;
  const full = stubEmbedOne(source, { idf, idfDefault });

  const top = Object.entries(full)
    .sort((a, b) => b[1] - a[1])
    .slice(0, TOP_TERMS);

  // Re-normalize after truncation so cosine stays in 0..1 and long chunks are
  // not implicitly favoured over short ones.
  const norm = Math.sqrt(top.reduce((s, [, w]) => s + w * w, 0)) || 1;
  const v = {};
  for (const [t, w] of top) v[t] = Number((w / norm).toFixed(PRECISION));

  return {
    t: c.title,
    a: c.author,
    h: c.heading || null,
    x: c.text,
    v,
  };
});

const out = {
  meta: {
    space: index.meta.space,
    chunks: chunks.length,
    topTerms: TOP_TERMS,
    idfDefault,
    builtAt: new Date().toISOString(),
    sources: index.meta.sources,
  },
  // The query is embedded at request time and needs the same IDF the documents
  // were weighted with, so it ships too.
  idf,
  chunks,
};

const dest = path.join(ROOT, 'worker', 'src', 'kb.json');
fs.writeFileSync(dest, JSON.stringify(out));
const mb = (fs.statSync(dest).size / 1048576).toFixed(2);
console.log(`Wrote ${dest}`);
console.log(`  ${chunks.length} chunks · top-${TOP_TERMS} terms · ${mb} MB raw`);
