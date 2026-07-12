// Oneira — production /explain proxy (Cloudflare Worker).
//
// Holds the Anthropic + embedding keys, enforces per-user quotas (KV), verifies
// subscription tier (RevenueCat), retrieves from the KB (Vectorize), and calls
// Claude. Same request/response contract as the Node dev server (src/server.mjs)
// so the Flutter app talks to either unchanged.
//
// NOT runtime-verified in this repo (needs your Cloudflare account). Verify with
// `wrangler dev` — see worker/README.md.
import { SYSTEM_PROMPT, EXPLAIN_SCHEMA, buildUserContent } from '../../src/prompt.mjs';

const CRISIS = [
  /\b(kill|hurt|harm)(ing)?\s+(myself|me)\b/i,
  /\bsuicid/i,
  /\b(want|wanting|going)\s+to\s+die\b/i,
  /\bself[-\s]?harm/i,
  /\bno\s+reason\s+to\s+live\b/i,
];

const SAFE_MESSAGE =
  "It sounds like you might be going through something painful. Oneira interprets " +
  "dreams for reflection and isn't the right help for a crisis. Please reach out to " +
  "someone who can support you right now: call or text 988 (US), Samaritans 116 123 " +
  "(UK & Ireland), or find a local line at findahelpline.com. If you are in immediate " +
  "danger, call your local emergency number.";

const LIMITS = {
  free: { explain: { day: 1, month: 5 } },
  paid: { explain: { day: 3, month: 50 } },
};

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') return cors(new Response(null, { status: 204 }));
    const url = new URL(request.url);

    if (url.pathname === '/health') {
      return json({ ok: true, kb: 'vectorize', model: env.CLAUDE_MODEL || 'claude-opus-4-8' });
    }

    const deviceToken = request.headers.get('X-Device-Token') || '';
    if (!deviceToken) return json({ error: 'Missing X-Device-Token' }, 401);

    const tier = await resolveTier(deviceToken, env);

    if (url.pathname === '/usage' && request.method === 'GET') {
      return json(await peek(env, deviceToken, tier));
    }

    if (url.pathname === '/explain' && request.method === 'POST') {
      let body;
      try {
        body = await request.json();
      } catch {
        return json({ error: 'invalid JSON body' }, 400);
      }
      const dream = String(body?.dream || '').trim();
      if (!dream) return json({ error: 'missing "dream" field' }, 400);

      // Server-side safety backstop (the app checks first). Returns a
      // schema-shaped supportive response — does NOT consume quota or hit Claude.
      if (CRISIS.some((r) => r.test(dream))) {
        return json({
          explanation: SAFE_MESSAGE,
          reflection: '',
          symbols: [],
          quotes: [],
          provider: 'safety',
        });
      }

      const quota = await checkAndIncrement(env, deviceToken, 'explain', tier);
      if (!quota.allowed) {
        return json(
          { error: `${quota.reason} limit reached`, ...quota, upgrade: tier === 'free' },
          429,
        );
      }

      try {
        const qEmb = await embed(dream, env);
        const result = await env.VECTORIZE.query(qEmb, {
          topK: Number(env.TOP_K || 6),
          returnMetadata: 'all',
        });
        const hits = (result.matches || []).map((m) => ({
          chunk: {
            title: m.metadata?.title || '',
            author: m.metadata?.author || '',
            heading: m.metadata?.heading || null,
            text: m.metadata?.text || '',
          },
        }));
        const out = await callClaude(dream, hits, env);
        return json({
          ...out,
          quota: { tier: quota.tier, day: quota.day, month: quota.month },
        });
      } catch (e) {
        return json({ error: String(e?.message || e) }, 502);
      }
    }

    return json({ error: 'not found' }, 404);
  },
};

// ---- embeddings (query) ----
async function embed(text, env) {
  const provider = (env.EMBEDDINGS_PROVIDER || 'openai').toLowerCase();
  if (provider === 'voyage') {
    const r = await fetch('https://api.voyageai.com/v1/embeddings', {
      method: 'POST',
      headers: { authorization: `Bearer ${env.VOYAGE_API_KEY}`, 'content-type': 'application/json' },
      body: JSON.stringify({
        model: env.VOYAGE_EMBED_MODEL || 'voyage-3.5-lite',
        input: [text],
        input_type: 'query',
      }),
    });
    if (!r.ok) throw new Error(`Voyage embed ${r.status}`);
    return (await r.json()).data[0].embedding;
  }
  const r = await fetch('https://api.openai.com/v1/embeddings', {
    method: 'POST',
    headers: { authorization: `Bearer ${env.OPENAI_API_KEY}`, 'content-type': 'application/json' },
    body: JSON.stringify({ model: env.OPENAI_EMBED_MODEL || 'text-embedding-3-small', input: text }),
  });
  if (!r.ok) throw new Error(`OpenAI embed ${r.status}`);
  return (await r.json()).data[0].embedding;
}

// ---- Claude (interpretation) ----
async function callClaude(dream, hits, env) {
  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'x-api-key': env.ANTHROPIC_API_KEY,
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model: env.CLAUDE_MODEL || 'claude-opus-4-8',
      max_tokens: 4000,
      thinking: { type: 'adaptive' },
      output_config: {
        effort: env.CLAUDE_EFFORT || 'medium',
        format: { type: 'json_schema', schema: EXPLAIN_SCHEMA },
      },
      system: [{ type: 'text', text: SYSTEM_PROMPT, cache_control: { type: 'ephemeral' } }],
      messages: [{ role: 'user', content: buildUserContent(dream, hits) }],
    }),
  });
  const j = await res.json();
  if (!res.ok) throw new Error(j?.error?.message || `Claude ${res.status}`);
  const text = (j.content || []).find((b) => b.type === 'text')?.text || '{}';
  return { ...JSON.parse(text), provider: 'claude', _meta: { model: j.model, usage: j.usage } };
}

// ---- quota (KV, day + month) ----
const dayKey = () => new Date().toISOString().slice(0, 10);
const monthKey = () => new Date().toISOString().slice(0, 7);

async function kvGet(env, k) {
  return parseInt((await env.RATE_LIMIT.get(k)) || '0', 10);
}
async function kvInc(env, k) {
  const v = (await kvGet(env, k)) + 1;
  await env.RATE_LIMIT.put(k, String(v), { expirationTtl: 60 * 60 * 24 * 40 });
  return v;
}

async function checkAndIncrement(env, id, endpoint, tier) {
  const lim = LIMITS[tier]?.[endpoint];
  if (!lim) return { allowed: true, tier };
  const dk = `rl:${id}:${endpoint}:d:${dayKey()}`;
  const mk = `rl:${id}:${endpoint}:m:${monthKey()}`;
  const d = await kvGet(env, dk);
  const m = await kvGet(env, mk);
  if (d >= lim.day)
    return { allowed: false, reason: 'daily', used: d, limit: lim.day, tier, resetsAt: nextMidnight() };
  if (m >= lim.month)
    return { allowed: false, reason: 'monthly', used: m, limit: lim.month, tier, resetsAt: nextMonth() };
  await kvInc(env, dk);
  await kvInc(env, mk);
  return { allowed: true, tier, day: { used: d + 1, limit: lim.day }, month: { used: m + 1, limit: lim.month } };
}

async function peek(env, id, tier) {
  const lim = LIMITS[tier]?.explain;
  if (!lim) return { tier };
  const d = await kvGet(env, `rl:${id}:explain:d:${dayKey()}`);
  const m = await kvGet(env, `rl:${id}:explain:m:${monthKey()}`);
  return {
    tier,
    endpoint: 'explain',
    day: { used: d, limit: lim.day, remaining: Math.max(0, lim.day - d) },
    month: { used: m, limit: lim.month, remaining: Math.max(0, lim.month - m) },
  };
}

// ---- subscription tier (RevenueCat) ----
async function resolveTier(id, env) {
  if (!env.REVENUECAT_API_KEY) return 'free';
  try {
    const r = await fetch(`https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(id)}`, {
      headers: { authorization: `Bearer ${env.REVENUECAT_API_KEY}` },
    });
    if (r.ok) {
      const j = await r.json();
      const ent = j.subscriber?.entitlements?.paid;
      if (ent && (!ent.expires_date || new Date(ent.expires_date) > new Date())) return 'paid';
    }
  } catch (_) {}
  return 'free';
}

// ---- helpers ----
function nextMidnight() { const d = new Date(); d.setUTCHours(24, 0, 0, 0); return d.toISOString(); }
function nextMonth() { const d = new Date(); d.setUTCMonth(d.getUTCMonth() + 1, 1); d.setUTCHours(0, 0, 0, 0); return d.toISOString(); }
function json(o, s = 200) {
  return cors(new Response(JSON.stringify(o), { status: s, headers: { 'content-type': 'application/json' } }));
}
function cors(res) {
  const r = new Response(res.body, res);
  r.headers.set('Access-Control-Allow-Origin', '*');
  r.headers.set('Access-Control-Allow-Headers', 'content-type, x-device-token');
  r.headers.set('Access-Control-Allow-Methods', 'POST, GET, OPTIONS');
  return r;
}
