// Shared retrieval scoring for the bundled knowledge base.
//
// Pure: imports only tokenize.mjs, so the Cloudflare Worker and the Node dev
// server run byte-identical ranking logic.
//
// Two corrections sit on top of plain sparse cosine, both aimed at the same
// mismatch: the dictionary was written in 1901 and the dreamer is typing today.
import { tokens, stubEmbedOne, sparseCosine } from './tokenize.mjs';

// 1. VOCABULARY BRIDGE. Miller files entries under words a modern dreamer does
//    not use. No amount of TF-IDF reaches "Death" from "she died", because the
//    forms share no stem — it is suppletion, not morphology. A small hand-built
//    map is the honest fix for a fixed, known corpus.
export const ALIASES = {
  died: ['death', 'dead'], die: ['death', 'dead'], dying: ['death', 'dead'],
  died_: [], passed: ['death'], funeral: ['death', 'burial'],
  phone: ['telephone'], mobile: ['telephone'], call: ['telephone'],
  car: ['carriage', 'driving', 'wagon'], truck: ['wagon'], bus: ['coach'],
  exam: ['school', 'examination'], test: ['school'], teacher: ['school'],
  snake: ['snakes', 'serpents'], serpent: ['serpents'],
  chased: ['running', 'pursued'], chasing: ['running'], chase: ['running'],
  nude: ['naked'], undressed: ['naked'],
  grandad: ['grandparents'], grandfather: ['grandparents'],
  grandmother: ['grandparents'], grandpa: ['grandparents'], granny: ['grandparents'],
  mum: ['mother'], mom: ['mother'], dad: ['father'],
  plane: ['flying', 'aeroplane'], airplane: ['flying'], flight: ['flying'],
  lift: ['elevator'], stairs: ['stairway'], toilet: ['closet'],
  gun: ['pistol', 'shooting'], police: ['policeman'], doctor: ['physician'],
  money: ['gold', 'wealth'], job: ['work'], boss: ['employer'],
  sea: ['ocean'], boat: ['ship'], kid: ['children'], kids: ['children'],
  baby: ['infant'], pregnant: ['pregnancy'], sick: ['illness'],
  lost: ['journey', 'wandering'], late: ['hurry'], trapped: ['prison'],
  falling: ['fall'], fell: ['fall'], drowned: ['drowning'],
};

export function expandQuery(text) {
  const extra = [];
  for (const t of new Set(text.toLowerCase().match(/[a-z]+/g) || [])) {
    const a = ALIASES[t];
    if (a) extra.push(...a);
  }
  return extra.length ? `${text} ${extra.join(' ')}` : text;
}

// 2. SPECIFICITY PENALTY. A compound headword ("Fire Budget", "Baby Carriages",
//    "Riding School") carries the query's word plus others the dreamer never
//    said, and its entry is short, so its vector is concentrated and it
//    outranks the general entry the reader actually wants. Penalise each
//    headword token absent from the query.
const UNMATCHED_PENALTY = 0.05;   // smallest value reaching the eval plateau (see eval/)

// Exported so the Node dev server ranks identically to the deployed Worker.
// Without this the CLI and production disagree, and a local preview stops being
// evidence about what users will actually see.
export function headwordPenalty(headingTokens, querySet) {
  if (!headingTokens || headingTokens.length < 2) return 0;
  let unmatched = 0;
  for (const t of headingTokens) if (!querySet.has(t)) unmatched++;
  return unmatched * UNMATCHED_PENALTY;
}

export function makeRetriever(KB) {
  const idf = KB.idf;
  const idfDefault = KB.meta.idfDefault;
  // Cached once per isolate; tokenizing 3.5k headwords on every request would
  // dominate the cost of the scan itself.
  const heads = KB.chunks.map((c) => (c.h ? tokens(c.h) : null));

  return function retrieve(dream, k = 6) {
    const expanded = expandQuery(dream);
    const q = stubEmbedOne(expanded, { idf, idfDefault });
    const qt = new Set(tokens(expanded));

    const scored = [];
    for (let i = 0; i < KB.chunks.length; i++) {
      const c = KB.chunks[i];
      let score = sparseCosine(q, c.v);
      if (score <= 0) continue;
      const h = heads[i];
      if (h && h.length > 1) {
        let unmatched = 0;
        for (const t of h) if (!qt.has(t)) unmatched++;
        score -= unmatched * UNMATCHED_PENALTY;
      }
      if (score > 0) scored.push({ score, c });
    }
    scored.sort((a, b) => b.score - a.score);
    return scored.slice(0, k).map(({ c }) => ({
      chunk: { title: c.t, author: c.a, heading: c.h, text: c.x },
    }));
  };
}
