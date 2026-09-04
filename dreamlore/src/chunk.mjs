// Turn a raw Gutenberg text into retrieval chunks.
//  - dictionary (Miller): one chunk per symbol entry, headword preserved.
//  - prose (Freud): overlapping paragraph windows.
import { stripBoilerplate, toParagraphs } from './gutenberg.mjs';

// A Miller headword sits alone on a line, italicised: `_Abandon_.`
// Roughly one entry in eight carries a Gutenberg footnote marker after the
// period (`_Snakes_.[210]`). Those must be matched too — without the optional
// group here, 242 entries were silently skipped, and because footnotes cluster
// on the notable symbols the losses included Death, Serpents and Snakes.
const HEADWORD_LINE = /^_([A-Za-z][A-Za-z ',.&\-]*?)_\.?(?:\[\d+\])?$/;
const LETTER_HEADER = /^[A-Z]\.$/;

function cleanText(t) {
  return t
    .replace(/\r\n/g, '\n')
    .replace(/``|''/g, '"')
    .replace(/@@@/g, '')
    .replace(/\[\d+\]/g, '')   // Gutenberg footnote markers
    .replace(/_/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

function mkChunk(src, n, text, heading = null) {
  return {
    id: `${src.id}:${n}`,
    bookId: src.id,
    title: src.title,
    author: src.author,
    type: src.type,
    heading,
    text,
  };
}

function chunkDictionary(body, src) {
  const lines = body.replace(/\r\n/g, '\n').split('\n');
  const entries = [];
  let cur = null;
  for (const raw of lines) {
    const line = raw.trim();
    if (LETTER_HEADER.test(line)) {
      if (cur) entries.push(cur);
      cur = null; // drop epigraphs between letter sections
      continue;
    }
    const m = line.match(HEADWORD_LINE);
    if (m) {
      if (cur) entries.push(cur);
      cur = { heading: m[1].replace(/\s+/g, ' ').trim(), lines: [] };
    } else if (cur) {
      cur.lines.push(raw);
    }
  }
  if (cur) entries.push(cur);

  const chunks = [];
  let n = 0;
  for (const e of entries) {
    const body = cleanText(e.lines.join('\n'));
    if (body.replace(/[^A-Za-z]/g, '').length < 40) continue; // skip stubs/index
    chunks.push(mkChunk(src, n++, `${e.heading}. ${body}`, e.heading));
  }
  return chunks;
}

function isBodyPara(p) {
  if (p.length < 60) return false;
  if (/^produced by/i.test(p)) return false;
  if (/online distributed proofreading/i.test(p)) return false;
  const letters = p.replace(/[^A-Za-z]/g, '').length;
  const caps = p.replace(/[^A-Z]/g, '').length;
  if (letters > 0 && caps / letters > 0.6 && p.length < 140) return false; // title-page / heading
  return true;
}

function chunkProse(body, src, { target = 1200, overlap = 1 } = {}) {
  const paras = toParagraphs(body).map(cleanText).filter(isBodyPara);
  const chunks = [];
  let n = 0;
  let buf = [];
  let len = 0;
  const flush = () => {
    if (buf.length) chunks.push(mkChunk(src, n++, buf.join('\n\n')));
  };
  for (const p of paras) {
    buf.push(p);
    len += p.length;
    if (len >= target) {
      flush();
      buf = buf.slice(-overlap);
      len = buf.reduce((a, b) => a + b.length, 0);
    }
  }
  flush();
  return chunks;
}

export function chunkSource(rawText, src) {
  const body = stripBoilerplate(rawText);
  return src.type === 'dictionary'
    ? chunkDictionary(body, src)
    : chunkProse(body, src);
}
