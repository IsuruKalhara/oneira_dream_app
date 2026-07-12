// Central config. Everything is env-driven so the same code runs offline (stub
// providers) in dev and against real Claude + embeddings in production.
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
export const ROOT = path.resolve(__dirname, '..');
export const DATA_DIR = path.join(ROOT, 'data');
export const RAW_DIR = path.join(DATA_DIR, 'raw');
export const INDEX_PATH = path.join(DATA_DIR, 'index.json');

const env = process.env;

export const config = {
  // 'stub' | 'openai' | 'voyage'  — MUST match at ingest time and query time.
  embeddingsProvider: (env.EMBEDDINGS_PROVIDER || 'stub').toLowerCase(),
  // 'stub' | 'claude'
  llmProvider: (env.LLM_PROVIDER || 'stub').toLowerCase(),

  topK: Number(env.TOP_K || 6),
  stubDim: Number(env.STUB_EMBED_DIM || 1024),

  anthropic: {
    apiKey: env.ANTHROPIC_API_KEY || '',
    model: env.CLAUDE_MODEL || 'claude-opus-4-8',
    effort: env.CLAUDE_EFFORT || 'medium', // low | medium | high | xhigh | max
  },
  openai: {
    apiKey: env.OPENAI_API_KEY || '',
    model: env.OPENAI_EMBED_MODEL || 'text-embedding-3-small',
  },
  voyage: {
    apiKey: env.VOYAGE_API_KEY || '',
    model: env.VOYAGE_EMBED_MODEL || 'voyage-3.5-lite',
  },

  port: Number(env.PORT || 8787),
};

// Identity of the embedding space, stamped into the index so we can refuse to
// query an index built with a different provider/model (that silently wrecks
// retrieval — the #1 RAG footgun).
export function embeddingSpaceId() {
  const p = config.embeddingsProvider;
  if (p === 'stub') return `stub:tfidf-sparse`;
  if (p === 'openai') return `openai:${config.openai.model}`;
  if (p === 'voyage') return `voyage:${config.voyage.model}`;
  return `unknown:${p}`;
}
