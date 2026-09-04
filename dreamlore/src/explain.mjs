// Orchestrates one dream interpretation: embed the dream → retrieve top-K
// passages → interpret (Claude or stub), grounded in and quoting those passages.
import { config, embeddingSpaceId } from './config.mjs';
import { embedOne } from './embeddings.mjs';
import { loadIndex, hydrate, retrieve } from './retriever.mjs';
import { SYSTEM_PROMPT, EXPLAIN_SCHEMA, buildUserContent } from './prompt.mjs';
import { expandQuery, headwordPenalty } from './retrieve.mjs';
import { tokens } from './tokenize.mjs';
import { callClaude, callOpenAI, buildStubExplanation } from './llm.mjs';

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

  // The sparse stub space is the one the Worker ships with, so it gets the same
  // two corrections production applies: alias expansion over Miller's archaic
  // headwords, and a penalty for headword words the dreamer never said. Dense
  // providers already handle synonymy, so they are left alone.
  const isStub = config.embeddingsProvider === 'stub';
  const queryText = isStub ? expandQuery(dreamText) : dreamText;

  const qEmb = await embedOne(queryText, {
    inputType: 'query',
    idf: index.meta?.idf,
    idfDefault: index.meta?.idfDefault,
  });

  const k = topK ?? config.topK;
  let hits;
  if (isStub) {
    const qt = new Set(tokens(queryText));
    hits = retrieve(index, qEmb, index.chunks.length)
      .map((h) => ({
        ...h,
        score: h.score - headwordPenalty(h.chunk.heading ? tokens(h.chunk.heading) : null, qt),
      }))
      .filter((h) => h.score > 0)
      .sort((a, b) => b.score - a.score)
      .slice(0, k);
  } else {
    hits = retrieve(index, qEmb, k);
  }

  const retrieval = hits.map((h) => ({
    id: h.chunk.id,
    title: h.chunk.title,
    author: h.chunk.author,
    heading: h.chunk.heading,
    score: Number(h.score.toFixed(4)),
  }));

  const call = { system: SYSTEM_PROMPT, user: buildUserContent(dreamText, hits), schema: EXPLAIN_SCHEMA };
  const result =
    config.llmProvider === 'claude'
      ? await callClaude(call)
      : config.llmProvider === 'openai'
        ? await callOpenAI(call)
        : buildStubExplanation(dreamText, hits);

  return {
    provider: config.llmProvider,
    embeddings: space,
    dream: dreamText.trim(),
    retrieval,
    ...result,
  };
}
