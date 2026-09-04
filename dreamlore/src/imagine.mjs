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
export function buildImagePrompt(dream, symbols = []) {
  const motifs = symbols
    .map((s) => (typeof s === 'string' ? s : s?.symbol))
    .filter(Boolean)
    .slice(0, 5);
  return [
    'A single painterly, dreamlike illustration of this dream, as the dreamer saw it:',
    `"${String(dream).trim().slice(0, MAX_DREAM_CHARS)}"`,
    motifs.length ? `Give quiet emphasis to: ${motifs.join(', ')}.` : '',
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
