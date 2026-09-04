// Pure, dependency-free tokenizer + sparse TF-IDF embedding.
//
// Extracted from embeddings.mjs so the Cloudflare Worker can import it without
// dragging in config.mjs (which touches process.env and would crash in a
// Worker). Build-time indexing and runtime querying MUST use identical
// tokenization — sharing this one module is what guarantees that.

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

// Sparse cosine: both vectors are pre-normalized, so this is the dot product
// over shared keys. Iterating the smaller map keeps it O(min(a,b)).
export function sparseCosine(a, b) {
  const [small, large] = Object.keys(a).length <= Object.keys(b).length ? [a, b] : [b, a];
  let dot = 0;
  for (const k in small) if (k in large) dot += small[k] * large[k];
  return dot;
}
