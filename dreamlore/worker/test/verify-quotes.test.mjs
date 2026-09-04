// The quote guarantee is enforced here, not in the prompt, so it needs a test.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

// verifyQuotes is internal to the Worker module, which imports kb.json and
// cannot be loaded under plain node. Lift the two functions out of the source
// so the test exercises the shipped text rather than a copy.
const SRC = fs.readFileSync(
  path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../src/index.js'),
  'utf8',
);
const slice = SRC.slice(SRC.indexOf('const norm ='), SRC.indexOf('// ---- quota'));
const { verifyQuotes } = await import(
  'data:text/javascript,' + encodeURIComponent(slice + '\nexport { verifyQuotes };')
);

const hits = [
  { chunk: { text: 'An ordinary dream of teeth augurs an unpleasant contact with sickness, or disquieting people.' } },
  { chunk: { text: 'To dream of seeing a tower, denotes that you will aspire to high elevations.' } },
];

test('keeps a verbatim quote', () => {
  const r = verifyQuotes({ quotes: [{ text: 'augurs an unpleasant contact with sickness' }] }, hits);
  assert.equal(r.quotes.length, 1);
});

test('drops a fabricated quote', () => {
  const r = verifyQuotes({ quotes: [{ text: 'Freud tells us the teeth represent hidden anxiety about money' }] }, hits);
  assert.equal(r.quotes.length, 0);
  assert.equal(r._meta.quotesDropped, 1);
});

test('drops a paraphrase of a real passage', () => {
  const r = verifyQuotes({ quotes: [{ text: 'a normal dream about teeth predicts unpleasant contact with illness' }] }, hits);
  assert.equal(r.quotes.length, 0);
});

test('tolerates ellipsis and curly quotes', () => {
  const r = verifyQuotes(
    { quotes: [{ text: '…denotes that you will aspire to high elevations…' }] },
    [{ chunk: { text: 'To dream of seeing a tower, denotes that you will aspire to high elevations.' } }],
  );
  assert.equal(r.quotes.length, 1);
});

test('rejects a snippet too short to be evidence', () => {
  const r = verifyQuotes({ quotes: [{ text: 'a tower' }] }, hits);
  assert.equal(r.quotes.length, 0);
});

test('keeps the real one and drops the invented one together', () => {
  const r = verifyQuotes(
    { quotes: [
      { text: 'augurs an unpleasant contact with sickness' },
      { text: 'and therefore great wealth shall follow' },
    ] },
    hits,
  );
  assert.equal(r.quotes.length, 1);
  assert.equal(r._meta.quotesDropped, 1);
});

test('no quotes is not an error', () => {
  assert.deepEqual(verifyQuotes({ quotes: [] }, hits).quotes, []);
});
