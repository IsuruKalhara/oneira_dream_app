// Orchestrates one dream interpretation: embed the dream → retrieve top-K
// passages → interpret (Claude or stub), grounded in and quoting those passages.
import { config, embeddingSpaceId } from './config.mjs';
import { embedOne } from './embeddings.mjs';
import { loadIndex, hydrate, retrieve } from './retriever.mjs';
import { SYSTEM_PROMPT, EXPLAIN_SCHEMA, buildUserContent } from './prompt.mjs';
import { callClaude, buildStubExplanation } from './llm.mjs';

let _index = null;
function getIndex() {
  if (!_index) _index = hydrate(loadIndex());
  return _index;
}

export async function explainDream(dreamText, { topK } = {}) {
  if (!dreamText || !dreamText.trim()) throw new Error('Empty dream text.');
  const index = getIndex();

  const space = embeddingSpaceId();
  if (index.meta?.space && index.meta.space !== space) {
    throw new Error(
      `Embedding-space mismatch: index was built with "${index.meta.space}" but you are querying with "${space}". ` +
        `Re-run ingest with the matching EMBEDDINGS_PROVIDER, or switch the query provider.`,
    );
  }

  const qEmb = await embedOne(dreamText, {
    inputType: 'query',
    idf: index.meta?.idf,
    idfDefault: index.meta?.idfDefault,
  });
  const hits = retrieve(index, qEmb, topK ?? config.topK);

  const retrieval = hits.map((h) => ({
    id: h.chunk.id,
    title: h.chunk.title,
    author: h.chunk.author,
    heading: h.chunk.heading,
    score: Number(h.score.toFixed(4)),
  }));

  const result =
    config.llmProvider === 'claude'
      ? await callClaude({
          system: SYSTEM_PROMPT,
          user: buildUserContent(dreamText, hits),
          schema: EXPLAIN_SCHEMA,
        })
      : buildStubExplanation(dreamText, hits);

  return {
    provider: config.llmProvider,
    embeddings: space,
    dream: dreamText.trim(),
    retrieval,
    ...result,
  };
}
