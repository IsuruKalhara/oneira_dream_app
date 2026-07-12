// Convert a semantically-embedded index.json into an NDJSON file for
// `wrangler vectorize insert`. Requires the index to have stored vectors, i.e.
// built with EMBEDDINGS_PROVIDER=openai|voyage (the stub is sparse/local-only).
import fs from 'node:fs';
import path from 'node:path';
import { INDEX_PATH, ROOT } from '../src/config.mjs';

const index = JSON.parse(fs.readFileSync(INDEX_PATH, 'utf8'));

if (!index.meta?.embedded) {
  console.error(
    'This index has no stored vectors (stub provider). Rebuild with a semantic provider:\n' +
      '  EMBEDDINGS_PROVIDER=openai OPENAI_API_KEY=sk-... npm run ingest\n',
  );
  process.exit(1);
}

const out = path.join(ROOT, 'data', 'vectorize.ndjson');
const ws = fs.createWriteStream(out);
for (const c of index.chunks) {
  ws.write(
    JSON.stringify({
      id: c.id,
      values: c.embedding,
      metadata: {
        title: c.title,
        author: c.author,
        heading: c.heading || '',
        text: c.text.slice(0, 4000), // Vectorize metadata cap
      },
    }) + '\n',
  );
}
ws.end();
ws.on('finish', () => {
  console.log(`Wrote ${index.chunks.length} vectors → ${out}`);
  console.log('\nNext:');
  console.log(`  npx wrangler vectorize create oneira-kb --dimensions=${index.meta.dim} --metric=cosine`);
  console.log('  npx wrangler vectorize insert oneira-kb --file=data/vectorize.ndjson');
});
