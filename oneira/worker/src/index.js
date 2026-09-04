// Oneira — production /explain proxy (Cloudflare Worker).
//
// Holds the Anthropic + embedding keys, enforces per-user quotas (KV), verifies
// subscription tier (RevenueCat), retrieves from the KB (Vectorize), and calls
// Claude. Same request/response contract as the Node dev server (src/server.mjs)
// so the Flutter app talks to either unchanged.
//
// Hardening notes (from the August 2026 audit):
// * The dream is length-capped BEFORE anything is spent — an uncapped body let
//   anyone inflate the Claude bill on our key.
// * Quotas are increment-then-check (with a refund on pipeline failure), which
//   shrinks the KV read-modify-write race from "trivially bypassable with one
//   parallel burst" to a narrow window. A Durable Object is the real fix and is
//   documented in docs/LAUNCH.md.
// * RevenueCat is cached in KV and called with a timeout; before this it ran
//   uncached on EVERY request and an RC outage silently downgraded paying
//   customers to the free tier.
// * Day/month windows honour the client's UTC offset (x-tz-offset, minutes),
//   so "resets tomorrow" means the user's tomorrow, not UTC's.
// * No CORS: the client is a native app. Serving Access-Control-Allow-* only
//   helped web-page quota farming.
//
// NOT runtime-verified in this repo (needs your Cloudflare account). Verify with
// `wrangler dev` — see worker/README.md.
import { SYSTEM_PROMPT, EXPLAIN_SCHEMA, buildUserContent } from '../../src/prompt.mjs';

// First-person ideation only. The previous pattern also matched "…kill me",
// which fired on the single most common nightmare narrative ("a man was trying
// to kill me") and answered an ordinary dream with a suicide hotline. Keep in
// sync with oneira_app/lib/data/safety.dart.
const CRISIS = [
  /\b(kill|hurt|harm)(ing)?\s+myself\b/i,
  /\b(cut|cutting)\s+myself\b/i,
  /\bsuicid/i,
  /\b(want|wanting|wanna|going)\s+to\s+die\b/i,
  /\bwanna\s+die\b/i,
  /\bend(ing)?\s+(my|it)\s+(life|all)\b/i,
  /\bself[-\s]?harm/i,
  /\bno\s+(reason|point)\s+(to\s+live|in\s+living)\b/i,
  /\bbetter\s+off\s+without\s+me\b/i,
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

// Product-sane ceiling: two minutes of fast speech is under 3,000 characters.
const MAX_DREAM_CHARS = 4000;

// Per-IP backstop, independent of device tokens — tokens are self-issued, so
// they cannot be the only thing standing between the internet and our API key.
const IP_DAY_LIMIT = 30;

const TIER_CACHE_TTL_S = 600;

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') return new Response(null, { status: 204 });
    const url = new URL(request.url);

    if (url.pathname === '/health') return json({ ok: true });

    const deviceToken = request.headers.get('X-Device-Token') || '';
    if (deviceToken.length < 8 || deviceToken.length > 64) {
      return json({ error: 'Missing or invalid X-Device-Token' }, 401);
    }

    // Client's UTC offset in minutes (Dart's timeZoneOffset convention:
    // positive east). Absent header = UTC, matching the old behavior.
    const tzOffset = clampInt(request.headers.get('x-tz-offset'), -840, 840, 0);

    if (url.pathname === '/usage' && request.method === 'GET') {
      const tier = await resolveTier(deviceToken, env);
      return json(await peek(env, deviceToken, tier, tzOffset));
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
      if (dream.length > MAX_DREAM_CHARS) {
        return json(
          { error: `dream too long (max ${MAX_DREAM_CHARS} characters)` },
          400,
        );
      }

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

      // IP backstop before the per-token quota: a fresh UUID per request gets
      // past token quotas, but not past this.
      const ip = request.headers.get('CF-Connecting-IP') || 'unknown';
      const ipCount = await kvInc(env, `rl:ip:${hashLite(ip)}:d:${dayKey(tzOffset)}`);
      if (ipCount > IP_DAY_LIMIT) {
        return json({ error: 'daily limit reached', reason: 'daily' }, 429);
      }

      const tier = await resolveTier(deviceToken, env);
      const quota = await checkAndIncrement(env, deviceToken, 'explain', tier, tzOffset);
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
        // The user paid quota for nothing — give it back, log the real error,
        // and keep provider/model details out of the response.
        await refund(env, deviceToken, 'explain', tzOffset);
        console.error('explain failed:', e?.stack || e);
        return json(
          { error: 'The reading could not be completed. Please try again.' },
          502,
        );
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
      // Adaptive thinking shares this budget with the answer; 4000 let long
      // dreams think the answer into truncation (unparseable JSON, quota
      // burned). NOTE: cache_control below only engages on models whose
      // minimum cacheable prefix is <= the ~750-token system prompt (e.g.
      // claude-opus-5 at 512); on claude-opus-4-8 (min 1024) it is a no-op.
      max_tokens: 12000,
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
  if (j.stop_reason === 'max_tokens') throw new Error('truncated at max_tokens');
  const text = (j.content || []).find((b) => b.type === 'text')?.text || '{}';
  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch {
    throw new Error('unparseable model output');
  }
  // Model name is shown/stored by the app; usage stays server-side.
  return { ...parsed, provider: 'claude', _meta: { model: j.model } };
}

// ---- quota (KV, day + month, client-local windows) ----
const dayKey = (off) => new Date(Date.now() + off * 60_000).toISOString().slice(0, 10);
const monthKey = (off) => new Date(Date.now() + off * 60_000).toISOString().slice(0, 7);

async function kvGet(env, k) {
  return parseInt((await env.RATE_LIMIT.get(k)) || '0', 10);
}
async function kvInc(env, k) {
  const v = (await kvGet(env, k)) + 1;
  await env.RATE_LIMIT.put(k, String(v), { expirationTtl: 60 * 60 * 24 * 40 });
  return v;
}
async function kvDec(env, k) {
  const v = Math.max(0, (await kvGet(env, k)) - 1);
  await env.RATE_LIMIT.put(k, String(v), { expirationTtl: 60 * 60 * 24 * 40 });
  return v;
}

const keysFor = (id, endpoint, off) => ({
  dk: `rl:${id}:${endpoint}:d:${dayKey(off)}`,
  mk: `rl:${id}:${endpoint}:m:${monthKey(off)}`,
});

// Increment FIRST, then check. Read-check-increment let any burst of parallel
// requests pass the check together; counting first closes that for
// same-isolate bursts and shrinks it elsewhere. Over-limit attempts leave the
// counter above the cap, which is harmless — the user was already capped.
async function checkAndIncrement(env, id, endpoint, tier, off) {
  const lim = LIMITS[tier]?.[endpoint];
  if (!lim) return { allowed: true, tier };
  const { dk, mk } = keysFor(id, endpoint, off);
  const d = await kvInc(env, dk);
  if (d > lim.day) {
    return { allowed: false, reason: 'daily', used: lim.day, limit: lim.day, tier, resetsAt: nextMidnight(off) };
  }
  const m = await kvInc(env, mk);
  if (m > lim.month) {
    await kvDec(env, dk); // the day slot was not actually used
    return { allowed: false, reason: 'monthly', used: lim.month, limit: lim.month, tier, resetsAt: nextMonth(off) };
  }
  return { allowed: true, tier, day: { used: Math.min(d, lim.day), limit: lim.day }, month: { used: Math.min(m, lim.month), limit: lim.month } };
}

// A failed pipeline must not eat the free tier's single daily reading.
async function refund(env, id, endpoint, off) {
  try {
    const { dk, mk } = keysFor(id, endpoint, off);
    await kvDec(env, dk);
    await kvDec(env, mk);
  } catch (e) {
    console.error('refund failed:', e);
  }
}

async function peek(env, id, tier, off) {
  const lim = LIMITS[tier]?.explain;
  if (!lim) return { tier };
  const { dk, mk } = keysFor(id, 'explain', off);
  const d = await kvGet(env, dk);
  const m = await kvGet(env, mk);
  return {
    tier,
    endpoint: 'explain',
    day: { used: Math.min(d, lim.day), limit: lim.day, remaining: Math.max(0, lim.day - d) },
    month: { used: Math.min(m, lim.month), limit: lim.month, remaining: Math.max(0, lim.month - m) },
  };
}

// ---- subscription tier (RevenueCat, cached) ----
async function resolveTier(id, env) {
  if (!env.REVENUECAT_API_KEY) return 'free';
  const cacheKey = `tier:${id}`;
  try {
    const cached = await env.RATE_LIMIT.get(cacheKey);
    if (cached) return cached;
  } catch (_) {}
  let tier = 'free';
  try {
    const r = await fetch(`https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(id)}`, {
      headers: { authorization: `Bearer ${env.REVENUECAT_API_KEY}` },
      signal: AbortSignal.timeout(3000),
    });
    if (r.ok) {
      const j = await r.json();
      const ent = j.subscriber?.entitlements?.paid;
      if (ent && (!ent.expires_date || new Date(ent.expires_date) > new Date())) tier = 'paid';
    } else {
      // RC outage or rate limit: do not cache, do not downgrade a known-paid
      // user for 10 minutes — just fall back for this one request.
      console.error(`RevenueCat ${r.status}`);
      return 'free';
    }
  } catch (e) {
    console.error('RevenueCat unreachable:', e?.name || e);
    return 'free';
  }
  try {
    await env.RATE_LIMIT.put(cacheKey, tier, { expirationTtl: TIER_CACHE_TTL_S });
  } catch (_) {}
  return tier;
}

// ---- helpers ----
function clampInt(raw, min, max, dflt) {
  const n = parseInt(raw ?? '', 10);
  if (Number.isNaN(n)) return dflt;
  return Math.max(min, Math.min(max, n));
}

// Non-cryptographic key shortener for IP bucketing (keys stay opaque in KV).
function hashLite(s) {
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return (h >>> 0).toString(36);
}

function nextMidnight(off) {
  const d = new Date(Date.now() + off * 60_000);
  d.setUTCHours(24, 0, 0, 0);
  return new Date(d.getTime() - off * 60_000).toISOString();
}
function nextMonth(off) {
  const d = new Date(Date.now() + off * 60_000);
  d.setUTCMonth(d.getUTCMonth() + 1, 1);
  d.setUTCHours(0, 0, 0, 0);
  return new Date(d.getTime() - off * 60_000).toISOString();
}
function json(o, s = 200) {
  return new Response(JSON.stringify(o), {
    status: s,
    headers: { 'content-type': 'application/json' },
  });
}
