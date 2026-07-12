// Add your OWN text to the knowledge base (a "bring-your-own-source" path,
// separate from the Gutenberg manifest). Reads a file or stdin, stages it under
// data/raw/local/, and re-ingests.
//
//   npm run add -- --file book.txt --title "..." --author "..." --type prose --license "..."
//   pbpaste | npm run add -- --title "..." --author "..." --license "..."
//
// LEGAL GATE: --license is required and forces the copyright decision every
// time. Only add PUBLIC-DOMAIN, LICENSED, or ORIGINAL (owned) text. The app
// quotes sources verbatim to users, so do NOT add copyrighted books you don't
// hold rights to. (Not legal advice.)
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { RAW_DIR, ROOT } from '../src/config.mjs';

const arg = (name) => {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : undefined;
};

const file = arg('file');
const title = arg('title');
const author = arg('author');
const type = arg('type') || 'prose';
const license = arg('license');

function fail(msg) {
  console.error(msg);
  console.error(
    '\nUsage: npm run add -- --file <path.txt> --title "..." --author "..." ' +
      '--type prose|dictionary --license "PUBLIC DOMAIN | LICENSED FROM X | ORIGINAL (owned)"\n' +
      '(or pipe text via stdin instead of --file)\n\n' +
      'LEGAL: only add public-domain, licensed, or original text — the app quotes sources verbatim.',
  );
  process.exit(1);
}

if (!title || !author || !license) fail('Missing --title, --author, or --license.');
if (!['prose', 'dictionary'].includes(type)) fail('--type must be prose or dictionary.');

let text;
try {
  text = file ? fs.readFileSync(file, 'utf8') : fs.readFileSync(0, 'utf8'); // fd 0 = stdin
} catch (e) {
  fail(`Could not read input: ${e.message}`);
}
if (!text || text.trim().length < 200) fail('Input text is empty or too short (need ~200+ chars).');

if (type === 'dictionary') {
  console.warn(
    'Note: "dictionary" chunking currently expects Miller-style "_Headword_." entries. ' +
      'For arbitrary pasted text, use --type prose.',
  );
}

const slug = title.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 48);
const localDir = path.join(RAW_DIR, 'local');
fs.mkdirSync(localDir, { recursive: true });
fs.writeFileSync(path.join(localDir, `${slug}.txt`), text);
fs.writeFileSync(
  path.join(localDir, `${slug}.meta.json`),
  JSON.stringify({ id: `local-${slug}`, title, author, type, license }, null, 2),
);

console.log(`Staged "${title}" — ${author} [${type}]  ·  license: ${license}`);
console.log('Re-ingesting the knowledge base…\n');
execFileSync('node', ['scripts/ingest.mjs'], { stdio: 'inherit', cwd: ROOT });
