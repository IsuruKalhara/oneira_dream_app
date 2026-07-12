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
import { config } from './config.mjs';

const STOP = new Set(
  ('the a an and or but if then of to in on at for from by with as is are was were be been being ' +
    'this that these those it its i you he she they we me my your his her their our not no do does ' +
    'did have has had will would can could should may might must so than too very just about into ' +
    'over under out up down off again more most such own same once here there all any each few other some ' +
    'denotes denote dream dreams dreaming denoting signifies signify')
    .split(/\s+/),
);

function stem(w) {
  const s = w.replace(/(ing|edly|ed|ly|ies|es|s)$/, '');
  return s.length >= 3 ? s : w;
}

export function tokens(text) {
  const m = text.toLowerCase().match(/[a-z]+/g) || [];
  return m.filter((w) => w.length > 2 && !STOP.has(w)).map(stem);
}

// Returns a normalized sparse vector: { token: weight }. Cosine over two of
// these is just the dot product over shared keys.
export function stubEmbedOne(text, { idf = null, idfDefault = 1 } = {}) {
  const counts = new Map();
  for (const t of tokens(text)) counts.set(t, (counts.get(t) || 0) + 1);
  const vec = {};
  let sumSq = 0;
  for (const [t, c] of counts) {
    const w = (1 + Math.log(c)) * (idf ? (idf[t] ?? idfDefault) : 1); // sublinear tf × idf
    vec[t] = w;
    sumSq += w * w;
  }
  const norm = Math.sqrt(sumSq) || 1;
  for (const t in vec) vec[t] /= norm;
  return vec;
}

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
