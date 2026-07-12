// Strip Project Gutenberg boilerplate and normalize the body text.

const START_RE =
  /\*\*\*\s*START OF (?:THE|THIS) PROJECT GUTENBERG EBOOK[\s\S]*?\*\*\*/i;
const END_RE = /\*\*\*\s*END OF (?:THE|THIS) PROJECT GUTENBERG EBOOK/i;

/** Return just the work's body, with the PG header/license footer removed. */
export function stripBoilerplate(raw) {
  let text = raw;
  const start = text.match(START_RE);
  if (start) text = text.slice(start.index + start[0].length);
  const end = text.match(END_RE);
  if (end) text = text.slice(0, end.index);
  return text.trim();
}

/**
 * Turn hard-wrapped Gutenberg text into clean paragraphs. PG wraps lines at
 * ~70 columns; we join lines within a paragraph and keep blank-line breaks as
 * paragraph boundaries.
 */
export function toParagraphs(text) {
  return text
    .replace(/\r\n/g, '\n')
    .split(/\n[ \t]*\n+/) // blank line = paragraph break
    .map((p) =>
      p
        .split('\n')
        .map((l) => l.trim())
        .join(' ')
        .replace(/[ \t]{2,}/g, ' ')
        .trim(),
    )
    .filter(Boolean);
}
