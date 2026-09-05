// Dream → picture. Shared by the Node dev server and the Worker so both build
// the same prompt and speak to the same endpoint.
//
// Cost note: gpt-image-1 at `low` quality, 1024², is roughly a cent an image —
// about ten explain calls' worth. It is a Plus-only feature with its own quota
// for exactly that reason; nothing here should ever run for the free tier.

export const MAX_DREAM_CHARS = 4000;
export const IMAGE_MODEL = 'gpt-image-1';

/**
 * A prompt that paints the dream rather than illustrating a caption. The style
 * lock at the end matters more than it looks: without it the model drifts to
 * glossy stock-art, and dreams are not glossy.
 */
// Words that name a place. Miller files a great many entries under settings —
// House, River, Forest, Street, Garden — and the setting is what decides
// whether a picture reads as the dreamer's dream or as generic night-time
// stock art. Pulled from the retrieved headwords rather than guessed at.
const PLACE_WORDS = new Set([
  'house', 'home', 'room', 'kitchen', 'cellar', 'attic', 'garden', 'forest',
  'wood', 'woods', 'field', 'meadow', 'river', 'sea', 'ocean', 'lake', 'water',
  'beach', 'shore', 'street', 'road', 'path', 'city', 'town', 'village',
  'church', 'school', 'hospital', 'prison', 'castle', 'tower', 'bridge',
  'stairs', 'stairway', 'door', 'window', 'garret', 'hall', 'shop', 'market',
  'graveyard', 'cemetery', 'mountain', 'hill', 'valley', 'desert', 'island',
  'ship', 'boat', 'train', 'carriage', 'sky', 'cave',
]);

/**
 * Builds the picture prompt from the same material the reading was written
 * from, not from the dream text alone.
 *
 * `passages` are the retrieved KB hits — the very entries the interpretation
 * quoted. Their headwords are the images the 1901 dictionary actually names
 * for this dream, so painting from them keeps picture and reading describing
 * one thing. Without it the picture was a separate guess at the same dream and
 * routinely disagreed with the words beside it.
 *
 * Accepts the old `(dream, symbolsArray)` shape too, so the Node dev server and
 * any older caller keep working.
 */
export function buildImagePrompt(dream, opts = {}) {
  const o = Array.isArray(opts) ? { symbols: opts } : opts;
  const symbols = o.symbols || [];
  const passages = o.passages || [];

  const name = (s) => (typeof s === 'string' ? s : s?.symbol || s?.heading);
  const dreamWords = String(dream).toLowerCase().match(/[a-z]+/g) || [];
  const dreamSet = new Set(dreamWords);

  // The setting comes from the DREAM, not from retrieval. Retrieval returns
  // near-misses — a teeth dream pulls in "Tower" — and promoting one of those
  // would paint a place the dreamer never mentioned. The KB may not surface a
  // place entry at all ("dark water" retrieves Drowning, not Water), so the
  // dreamer's own words are the source and the KB only confirms spelling.
  const setting = [];
  for (const w of dreamWords) {
    if (PLACE_WORDS.has(w) && !setting.some((x) => x.toLowerCase() === w)) {
      setting.push(w);
    }
  }

  // Subjects: the model's symbols first — they were chosen having read the
  // whole dream — then at most two KB headwords, which are what earn the
  // synonym the dreamer did not type (snake -> Serpents). Capped, because
  // every extra noun past a handful is another thing for the model to arrange
  // rather than paint.
  const seen = new Set(setting.map((x) => x.toLowerCase()));
  const subjects = [];
  const push = (raw, limit) => {
    const v = String(raw || '').trim();
    if (!v || subjects.length >= limit) return;
    const k = v.toLowerCase();
    if (seen.has(k)) return;
    seen.add(k);
    subjects.push(v);
  };
  for (const sym of symbols.map(name)) push(sym, 3);
  for (const p of passages.slice(0, 3)) push(p?.chunk?.heading, 5);

  return [
    'A single painterly, dreamlike illustration of this dream, as the dreamer saw it:',
    `"${String(dream).trim().slice(0, MAX_DREAM_CHARS)}"`,
    subjects.length ? `Give quiet emphasis to: ${subjects.join(', ')}.` : '',
    // The setting is stated separately because a model given a flat list of
    // nouns tends to arrange them as objects on a shelf rather than place them
    // somewhere.
    setting.length
      ? `Set the scene in or around: ${setting.slice(0, 2).join(' and ')}. Let the place carry the mood.`
      : 'Place the dream somewhere specific rather than in empty space.',
    'Style: soft-focus oil-and-ink, deep indigo night palette with a few warm',
    'highlights, gentle grain, atmospheric, slightly surreal, cinematic',
    'composition. No text, no words, no letters, no captions, no watermark, no',
    'frame. Not a collage, not a comic panel, not photorealistic.',
  ]
    .filter(Boolean)
    .join(' ');
}

/**
 * Calls OpenAI's image endpoint and returns { b64, mime }. Throws on any
 * failure with a message safe to log.
 */
export async function generateImage({ apiKey, prompt, fetchImpl = fetch }) {
  if (!apiKey) throw new Error('OPENAI_API_KEY is not set');
  const res = await fetchImpl('https://api.openai.com/v1/images/generations', {
    method: 'POST',
    headers: {
      authorization: `Bearer ${apiKey}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model: IMAGE_MODEL,
      prompt,
      n: 1,
      size: '1024x1024',
      quality: 'low',
      output_format: 'jpeg',
      output_compression: 80,
    }),
  });
  const j = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(j?.error?.message || `OpenAI images ${res.status}`);
  const b64 = j?.data?.[0]?.b64_json;
  if (!b64) throw new Error('No image returned');
  return { b64, mime: 'image/jpeg', model: IMAGE_MODEL };
}
