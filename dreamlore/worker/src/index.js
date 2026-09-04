// Dreamlore — production /explain proxy (Cloudflare Worker).
//
// Holds the provider key, enforces per-user quotas (KV), verifies subscription
// tier (RevenueCat), retrieves from the KB, and calls Claude. Same request/
// response contract as the Node dev server (src/server.mjs) so the Flutter app
// talks to either unchanged.
//
// Retrieval is IN-BUNDLE: kb.json ships with the Worker (built by
// `npm run build:kb`) and cosine runs here in JS. That means no Vectorize index
// and no embedding API — the whole deployment costs nothing but Claude calls.
// The trade-off is a sparse TF-IDF space rather than a semantic one, so a dream
// about a snake will not match an entry filed only under "Reptile".
//
// NOT runtime-verified in this repo (needs your Cloudflare account). Verify with
// `wrangler dev` — see worker/README.md.
import { SYSTEM_PROMPT, EXPLAIN_SCHEMA, buildUserContent } from '../../src/prompt.mjs';
import { makeRetriever } from '../../src/retrieve.mjs';
import KB from './kb.json';

// Built once per isolate: caches the tokenized headwords the ranking needs.
const retrieve = makeRetriever(KB);

const CRISIS = [
  /\b(kill|hurt|harm)(ing)?\s+(myself|me)\b/i,
  /\bsuicid/i,
  /\b(want|wanting|going)\s+to\s+die\b/i,
  /\bself[-\s]?harm/i,
  /\bno\s+reason\s+to\s+live\b/i,
];

const SAFE_MESSAGE =
  "It sounds like you might be going through something painful. Dreamlore interprets " +
  "dreams for reflection and isn't the right help for a crisis. Please reach out to " +
  "someone who can support you right now: call or text 988 (US), Samaritans 116 123 " +
  "(UK & Ireland), or find a local line at findahelpline.com. If you are in immediate " +
  "danger, call your local emergency number.";

// A dream longer than this is not a dream, it is someone probing what a large
// prompt costs us. A genuine recollection typed at 6am is a few hundred
// characters; Miller's longest entry is well under this.
const MAX_DREAM_CHARS = 4000;

// Two ceilings that do not depend on the client behaving.
//
// X-Device-Token is chosen by the caller, so per-device quota is advisory: send
// a new random token and you get a fresh allowance. That is fine against honest
// use and useless against anyone who reads this file. These are the caps that
// actually bound the bill. Both are overridable from [vars].
const GLOBAL_DAILY_CALLS = 500;   // whole deployment, every user combined
const IP_DAILY_CALLS = 20;        // one address; rotating IPs is real work

const LIMITS = {
  free: { explain: { day: 1, month: 5 } },
  paid: { explain: { day: 3, month: 50 } },
};

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') return cors(new Response(null, { status: 204 }));
    const url = new URL(request.url);

    if (url.pathname === '/health') {
      return json({
        ok: true,
        kb: 'bundled',
        chunks: KB.meta.chunks,
        space: KB.meta.space,
        provider: (env.LLM_PROVIDER || 'openai').toLowerCase(),
        model:
          (env.LLM_PROVIDER || 'openai').toLowerCase() === 'claude'
            ? env.CLAUDE_MODEL || 'claude-sonnet-5'
            : env.OPENAI_MODEL || 'gpt-4o-mini',
      });
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
      if (dream.length > MAX_DREAM_CHARS) {
        return json(
          { error: `Dream is too long (${dream.length} characters, limit ${MAX_DREAM_CHARS}).` },
          413,
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

      // Abuse ceilings. Checked after the crisis branch on purpose: someone in
      // distress must never be turned away by a rate limit.
      const abuse = await checkAbuseCeilings(env, request);
      if (!abuse.allowed) {
        return json(
          { error: 'Service is busy. Please try again later.', retryAfter: abuse.resetsAt },
          429,
        );
      }

      const quota = await checkAndIncrement(env, deviceToken, 'explain', tier);
      if (!quota.allowed) {
        return json(
          { error: `${quota.reason} limit reached`, ...quota, upgrade: tier === 'free' },
          429,
        );
      }

      try {
        const hits = retrieve(dream, Number(env.TOP_K || 6));
        const out = await interpret(dream, hits, env);
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

// ---- interpretation ----
//
// OpenAI by default: gpt-4o-mini answers this prompt for roughly a tenth of a
// cent per dream, and reuses the key the other app already has. Set
// LLM_PROVIDER=claude (plus ANTHROPIC_API_KEY) to switch back.
//
// The system prompt is a fixed ~1.2k-token prefix, which is over OpenAI's
// automatic prompt-caching threshold, so repeat calls bill the cached rate
// without any markup on our side.
async function interpret(dream, hits, env) {
  const provider = (env.LLM_PROVIDER || 'openai').toLowerCase();
  const raw = provider === 'claude'
    ? await callClaude(dream, hits, env)
    : await callOpenAI(dream, hits, env);
  return verifyQuotes(raw, hits);
}

async function callOpenAI(dream, hits, env) {
  if (!env.OPENAI_API_KEY) throw new Error('OPENAI_API_KEY is not set');
  const model = env.OPENAI_MODEL || 'gpt-4o-mini';
  const res = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      authorization: `Bearer ${env.OPENAI_API_KEY}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model,
      temperature: 0.7,
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user', content: buildUserContent(dream, hits) },
      ],
      // Strict structured output: the app can parse the reply without ever
      // seeing malformed JSON. EXPLAIN_SCHEMA is already strict-compatible
      // (additionalProperties:false, every property required).
      response_format: {
        type: 'json_schema',
        json_schema: { name: 'dream_interpretation', strict: true, schema: EXPLAIN_SCHEMA },
      },
    }),
  });
  const j = await res.json();
  if (!res.ok) throw new Error(j?.error?.message || `OpenAI ${res.status}`);
  const msg = j.choices?.[0]?.message;
  if (msg?.refusal) throw new Error('The model declined to interpret this dream.');
  return {
    ...JSON.parse(msg?.content || '{}'),
    provider: 'openai',
    _meta: { model: j.model, usage: j.usage },
  };
}

async function callClaude(dream, hits, env) {
  if (!env.ANTHROPIC_API_KEY) throw new Error('ANTHROPIC_API_KEY is not set');
  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'x-api-key': env.ANTHROPIC_API_KEY,
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model: env.CLAUDE_MODEL || 'claude-sonnet-5',
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

// ---- quote verification ----
//
// The one claim this app makes that competitors do not is that the quotes are
// real. Leaving that to the prompt alone means trusting a model not to
// paraphrase, and a small model paraphrases. So every quote is checked against
// the passages actually retrieved, and anything not found verbatim is dropped
// before the user ever sees it. The guarantee then holds by construction, and
// survives swapping the model for a cheaper one.
const norm = (t) =>
  String(t || '')
    .replace(/[\u2018\u2019]/g, "'")
    .replace(/[\u201C\u201D]/g, '"')
    .replace(/[\u2013\u2014]/g, '-')
    .replace(/\s+/g, ' ')
    .trim()
    .toLowerCase();

function verifyQuotes(result, hits) {
  if (!Array.isArray(result.quotes) || result.quotes.length === 0) return result;
  const corpus = hits.map((h) => norm(h.chunk.text));

  const kept = [];
  let dropped = 0;
  for (const q of result.quotes) {
    // Models often top and tail a quotation with an ellipsis; the words between
    // are still expected to be verbatim, so compare on that span.
    const needle = norm(q?.text).replace(/^[.\u2026]+|[.\u2026]+$/g, '').trim();
    if (needle.length >= 24 && corpus.some((c) => c.includes(needle))) kept.push(q);
    else dropped++;
  }

  result.quotes = kept;
  if (dropped) result._meta = { ...(result._meta || {}), quotesDropped: dropped };
  return result;
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

// Ceilings that hold regardless of what the client claims to be. The global one
// is the backstop on the bill: whatever else goes wrong, the deployment cannot
// make more than GLOBAL_DAILY_CALLS paid model calls in a day.
async function checkAbuseCeilings(env, request) {
  const day = dayKey();
  const globalCap = Number(env.GLOBAL_DAILY_CALLS || GLOBAL_DAILY_CALLS);
  const ipCap = Number(env.IP_DAILY_CALLS || IP_DAILY_CALLS);

  const used = await kvGet(env, `rl:__global:${day}`);
  if (used >= globalCap) return { allowed: false, resetsAt: nextMidnight() };

  const ip = request.headers.get('CF-Connecting-IP') || '';
  if (ip) {
    const ipUsed = await kvGet(env, `rl:ip:${ip}:${day}`);
    if (ipUsed >= ipCap) return { allowed: false, resetsAt: nextMidnight() };
    await kvInc(env, `rl:ip:${ip}:${day}`);
  }
  await kvInc(env, `rl:__global:${day}`);
  return { allowed: true };
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
// CORS governs browsers only — curl and any script ignore it entirely, so this
// is NOT what stops abuse. The ceilings in checkAbuseCeilings are. Left open
// because the client is a native app that sends no Origin header; if a web
// client is ever added, narrow this to its domain then.
function cors(res) {
  const r = new Response(res.body, res);
  r.headers.set('Access-Control-Allow-Origin', '*');
  r.headers.set('Access-Control-Allow-Headers', 'content-type, x-device-token');
  r.headers.set('Access-Control-Allow-Methods', 'POST, GET, OPTIONS');
  return r;
}
