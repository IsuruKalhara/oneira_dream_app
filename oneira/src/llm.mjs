// The interpretation step. Two providers:
//   - 'claude'  → real interpretation via the Anthropic SDK (needs a key).
//   - 'stub'    → deterministic, retrieval-grounded placeholder that quotes the
//                 real retrieved passages, so the whole pipeline runs offline.
import { config } from './config.mjs';

// ---- Claude (production) ---------------------------------------------------

export async function callClaude({ system, user, schema }) {
  if (!config.anthropic.apiKey) {
    throw new Error('ANTHROPIC_API_KEY is not set (required for LLM_PROVIDER=claude).');
  }
  let Anthropic;
  try {
    ({ default: Anthropic } = await import('@anthropic-ai/sdk'));
  } catch {
    throw new Error('Anthropic SDK not installed. Run: npm install');
  }
  const client = new Anthropic({ apiKey: config.anthropic.apiKey });

  const resp = await client.messages.create({
    model: config.anthropic.model,
    max_tokens: 4000,
    thinking: { type: 'adaptive' },
    output_config: {
      effort: config.anthropic.effort,
      format: { type: 'json_schema', schema },
    },
    // Frozen system prompt → cached prefix. Volatile dream+passages in the user
    // turn are NOT cached. This is where prompt caching pays off at scale.
    system: [{ type: 'text', text: system, cache_control: { type: 'ephemeral' } }],
    messages: [{ role: 'user', content: user }],
  });

  const text = resp.content.find((b) => b.type === 'text')?.text || '{}';
  const parsed = JSON.parse(text);
  return {
    ...parsed,
    _meta: {
      model: resp.model,
      usage: resp.usage,
      cached_read: resp.usage?.cache_read_input_tokens ?? 0,
    },
  };
}

// ---- Stub (offline) --------------------------------------------------------

const stripHeading = (text, heading) =>
  heading && text.startsWith(`${heading}. `) ? text.slice(heading.length + 2) : text;

function excerpt(text, n) {
  const t = text.replace(/\s+/g, ' ').trim();
  if (t.length <= n) return t;
  const cut = t.slice(0, n);
  return cut.slice(0, cut.lastIndexOf(' ')).trimEnd() + '…';
}

function firstSentence(text) {
  const m = text.replace(/\s+/g, ' ').trim().match(/^(.*?[.!?])(\s|$)/);
  return m ? m[1] : excerpt(text, 160);
}

export function buildStubExplanation(dreamText, hits) {
  const top = hits.slice(0, Math.min(3, hits.length));

  const quotes = top.map((h) => ({
    book: h.chunk.title,
    author: h.chunk.author,
    text: excerpt(stripHeading(h.chunk.text, h.chunk.heading), 300),
  }));

  const symbols = top
    .filter((h) => h.chunk.heading)
    .map((h) => ({
      symbol: h.chunk.heading,
      meaning: firstSentence(stripHeading(h.chunk.text, h.chunk.heading)),
    }));

  const paras = [
    'A few images in your dream line up with themes the classic dream literature speaks to directly:',
  ];
  for (const h of top) {
    const src =
      `${h.chunk.author}, ${h.chunk.title}` +
      (h.chunk.heading ? ` (entry "${h.chunk.heading}")` : '');
    paras.push(`${src}: "${excerpt(stripHeading(h.chunk.text, h.chunk.heading), 220)}"`);
  }
  paras.push(
    'Read these as lenses, not verdicts. Notice which one, if any, resonates with what you have been carrying in waking life.',
  );

  return {
    explanation: paras.join('\n\n'),
    symbols,
    quotes,
    reflection: 'Which single image from the dream feels most charged when you sit with it now?',
    _meta: {
      model: 'stub',
      note: 'Offline stub: deterministic, retrieval-grounded. Set LLM_PROVIDER=claude with an ANTHROPIC_API_KEY for a full interpretation.',
    },
  };
}
