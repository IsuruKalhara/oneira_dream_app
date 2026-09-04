// The public-domain knowledge base manifest.
//
// LEGAL: every source here is public domain, sourced from Project Gutenberg.
// Do NOT add copyrighted / in-print dream books — the app quotes these texts
// verbatim to users, which is only lawful for public-domain works.
//
// `type: 'dictionary'` books are split into one chunk per symbol entry;
// `type: 'prose'` books are split into overlapping paragraph windows.
// `provenance` strings must all appear in the downloaded text, or the
// downloader rejects the file (guards against a wrong/renamed Gutenberg ID).

export const SOURCES = [
  {
    id: 'miller-10k',
    gutenbergId: 926,
    title: 'Ten Thousand Dreams Interpreted; or, What\'s in a Dream',
    author: 'Gustavus Hindman Miller',
    year: 1901,
    type: 'dictionary',
    provenance: ['ten thousand dreams', 'miller'],
    license: 'Public domain (Project Gutenberg eBook #926)',
  },
  {
    id: 'freud-iod',
    gutenbergId: 66048,
    title: 'The Interpretation of Dreams',
    author: 'Sigmund Freud',
    translator: 'A. A. Brill',
    year: 1913,
    type: 'prose',
    provenance: ['interpretation of dreams', 'freud'],
    license: 'Public domain (Project Gutenberg eBook #66048)',
  },
  {
    id: 'freud-dreampsych',
    gutenbergId: 15489,
    title: 'Dream Psychology: Psychoanalysis for Beginners',
    author: 'Sigmund Freud',
    year: 1920,
    type: 'prose',
    provenance: ['dream psychology', 'freud'],
    license: 'Public domain (Project Gutenberg eBook #15489)',
  },
];

export const gutenbergTextUrl = (gid) =>
  `https://www.gutenberg.org/cache/epub/${gid}/pg${gid}.txt`;

export const sourceById = (id) => SOURCES.find((s) => s.id === id);
