// CLI: interpret a dream from the command line.
//   npm run explain -- "I dreamt my teeth fell out"
import { explainDream } from '../src/explain.mjs';

const dream = process.argv.slice(2).join(' ').trim();
if (!dream) {
  console.error('Usage: npm run explain -- "your dream in a sentence or two"');
  process.exit(1);
}

const r = await explainDream(dream);

const rule = (s) => `\n${'─'.repeat(4)} ${s} ${'─'.repeat(Math.max(0, 50 - s.length))}`;
console.log(rule('DREAM'));
console.log(r.dream);
console.log(rule(`INTERPRETATION  (llm=${r.provider}, embeddings=${r.embeddings})`));
console.log(r.explanation);
if (r.symbols?.length) {
  console.log(rule('SYMBOLS'));
  for (const s of r.symbols) console.log(`• ${s.symbol}: ${s.meaning}`);
}
if (r.quotes?.length) {
  console.log(rule('QUOTES'));
  for (const q of r.quotes) console.log(`• "${q.text}"\n    — ${q.author}, ${q.book}`);
}
console.log(rule('REFLECTION'));
console.log(r.reflection);
console.log(rule(`RETRIEVAL  (top ${r.retrieval.length})`));
for (const h of r.retrieval) {
  console.log(`  ${h.score.toFixed(3)}  ${h.title}${h.heading ? `  ::  ${h.heading}` : ''}`);
}
if (r._meta?.note) console.log(`\n(${r._meta.note})`);
