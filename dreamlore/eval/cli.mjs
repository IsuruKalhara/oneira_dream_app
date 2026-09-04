// npm run eval — retrieval quality against eval/dreams.json.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { evaluate } from './run.mjs';
import { makeRetriever } from '../src/retrieve.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const kbPath = path.join(ROOT, 'worker/src/kb.json');
if (!fs.existsSync(kbPath)) {
  console.error('worker/src/kb.json missing — run: npm run ingest && npm run build:kb');
  process.exit(1);
}
const KB = JSON.parse(fs.readFileSync(kbPath, 'utf8'));
const r = evaluate(makeRetriever(KB), { verbose: process.argv.includes('-v') });
console.log(`\nhit@6 ${(r.hitRate * 100).toFixed(1)}%  (${r.hits}/${r.n})   MRR ${r.mrr.toFixed(3)}`);
if (r.hitRate < 1) process.exitCode = 1;
