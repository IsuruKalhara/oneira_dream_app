// Pluggable embeddings.
//   'stub'  → deterministic, offline, zero-dependency sparse TF-IDF vector
//             keyed by token (no hashing → no collisions). Runs with no key.
//   'openai'/'voyage' → production dense semantic vectors.
// The SAME provider must be used at ingest and query time (enforced via
// embeddingSpaceId stamped into the index).
//
// IDF is essential: without it, similarity is dominated by words every entry
// shares ("dream", "denotes", "friends"). It's computed over the corpus at
// ingest, stored in the index, and applied to documents (on load) and queries.
//
// The tokenizer and sparse embedder live in tokenize.mjs — a pure module with no
// config dependency, so the Worker can share the exact same code.
import { config } from './config.mjs';
export { tokens, stubEmbedOne, sparseCosine } from './tokenize.mjs';
import { stubEmbedOne } from './tokenize.mjs';

async function apiEmbed({ url, key, buildBody, pick }, texts) {
  if (!key) throw new Error(`Missing API key for ${url}`);
  const out = [];
  const B = 64;
  for (let i = 0; i < texts.length; i += B) {
    const res = await fetch(url, {
      method: 'POST',
      headers: { authorization: `Bearer ${key}`, 'content-type': 'application/json' },
      body: JSON.stringify(buildBody(texts.slice(i, i + B))),
    });
    if (!res.ok) throw new Error(`Embeddings HTTP ${res.status}: ${await res.text()}`);
    for (const emb of pick(await res.json())) out.push(emb);
  }
  return out;
}

export async function embed(texts, { inputType = 'document', idf = null, idfDefault = 1 } = {}) {
  const p = config.embeddingsProvider;
  if (p === 'stub') return texts.map((t) => stubEmbedOne(t, { idf, idfDefault }));
  if (p === 'openai')
    return apiEmbed(
      {
        url: 'https://api.openai.com/v1/embeddings',
        key: config.openai.apiKey,
        buildBody: (b) => ({ model: config.openai.model, input: b }),
        pick: (j) => j.data.sort((a, b) => a.index - b.index).map((d) => d.embedding),
      },
      texts,
    );
  if (p === 'voyage')
    return apiEmbed(
      {
        url: 'https://api.voyageai.com/v1/embeddings',
        key: config.voyage.apiKey,
        buildBody: (b) => ({
          model: config.voyage.model,
          input: b,
          input_type: inputType === 'query' ? 'query' : 'document',
        }),
        pick: (j) => j.data.sort((a, b) => a.index - b.index).map((d) => d.embedding),
      },
      texts,
    );
  throw new Error(`Unknown EMBEDDINGS_PROVIDER: ${p}`);
}

export async function embedOne(text, opts) {
  return (await embed([text], opts))[0];
}
