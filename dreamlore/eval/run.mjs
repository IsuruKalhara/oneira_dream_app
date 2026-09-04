// Retrieval evaluation. Measures how often the entry a reader would expect
// actually surfaces, so a scoring change can be judged instead of eyeballed.
//   hit@k  — the expected headword appears in the top k
//   MRR    — 1/rank of the first expected headword (0 if absent)
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '..');
const KB = JSON.parse(fs.readFileSync(path.join(ROOT, 'worker/src/kb.json'), 'utf8'));
const SET = JSON.parse(fs.readFileSync(path.join(HERE, 'dreams.json'), 'utf8'));

export function evaluate(retrieve, { k = 6, verbose = false } = {}) {
  let hits = 0, mrr = 0;
  const rows = [];
  for (const { dream, want } of SET) {
    const got = retrieve(dream, k).map((h) => h.chunk.heading).filter(Boolean);
    const rank = got.findIndex((h) => want.includes(h));
    if (rank >= 0) { hits++; mrr += 1 / (rank + 1); }
    rows.push({ dream, want, got, rank });
  }
  const n = SET.length;
  if (verbose) {
    for (const r of rows) {
      const mark = r.rank === 0 ? '##' : r.rank > 0 ? ` ${r.rank + 1}` : ' -';
      console.log(`${mark}  ${r.dream.slice(0, 46).padEnd(46)} want=${r.want.join('/')}`);
      console.log(`      ${r.got.slice(0, 6).join(' · ')}`);
    }
  }
  return { n, hits, hitRate: hits / n, mrr: mrr / n };
}
