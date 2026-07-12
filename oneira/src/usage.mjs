// Usage metering + quota enforcement. This is the money-safety layer for a
// paid app: it tracks AI usage per user and blocks over-quota requests.
//
// Two things it does, both server-side (the only place they can be trusted):
//   1. TRACK   — count requests per user × endpoint × day/month; estimate the
//                real $ cost per request from the model's token usage.
//   2. LIMIT   — refuse (429) once a tier's daily or monthly quota is hit.
//
// The counter store is pluggable: MemoryStore for dev; in production swap in
// Cloudflare KV (Timbre's pattern) or a Durable Object for atomic counts.
// The tier resolver is a stub — wire it to RevenueCat server-side (see below).

// ---- Model pricing (USD per 1M tokens) — keep in sync with the Anthropic docs.
const PRICES = {
  'claude-opus-4-8': { in: 5, out: 25 },
  'claude-opus-4-7': { in: 5, out: 25 },
  'claude-sonnet-5': { in: 3, out: 15 },
  'claude-haiku-4-5': { in: 1, out: 5 },
};

export function estimateCostUsd(model, usage) {
  if (!usage) return 0; // stub / no usage reported
  const p = PRICES[model] || PRICES['claude-opus-4-8'];
  const inTok = usage.input_tokens || 0;
  const cacheRead = usage.cache_read_input_tokens || 0; // ~0.1x
  const cacheWrite = usage.cache_creation_input_tokens || 0; // ~1.25x
  const outTok = usage.output_tokens || 0;
  const inCost = (inTok * p.in + cacheRead * p.in * 0.1 + cacheWrite * p.in * 1.25) / 1e6;
  return inCost + (outTok * p.out) / 1e6;
}

// ---- Per-tier quotas (daily for UX, monthly as the COGS backstop). Tunable.
export const LIMITS = {
  free: {
    explain: { day: Number(process.env.FREE_EXPLAIN_DAY || 1), month: Number(process.env.FREE_EXPLAIN_MONTH || 5) },
    chat: { day: 2, month: 10 }, // Phase 2
  },
  paid: {
    explain: { day: Number(process.env.PAID_EXPLAIN_DAY || 3), month: Number(process.env.PAID_EXPLAIN_MONTH || 50) },
    chat: { day: 30, month: 300 },
  },
};

// ---- Counter store. Dev = in-memory. Prod: KV (env.RATE_LIMIT.get/put) or a
// Durable Object. Same get/incr interface either way.
export function createMemoryStore() {
  const m = new Map();
  return {
    async get(key) { return m.get(key) || 0; },
    async incr(key) { const v = (m.get(key) || 0) + 1; m.set(key, v); return v; },
  };
}

const dayUTC = () => new Date().toISOString().slice(0, 10);
const monthUTC = () => new Date().toISOString().slice(0, 7);
function nextMidnightUTC() { const d = new Date(); d.setUTCHours(24, 0, 0, 0); return d.toISOString(); }
function nextMonthUTC() { const d = new Date(); d.setUTCMonth(d.getUTCMonth() + 1, 1); d.setUTCHours(0, 0, 0, 0); return d.toISOString(); }

export async function checkAndIncrement(store, { identity, endpoint, tier }) {
  const lim = LIMITS[tier]?.[endpoint];
  if (!lim) return { allowed: true, tier };

  const dayKey = `rl:${identity}:${endpoint}:d:${dayUTC()}`;
  const monKey = `rl:${identity}:${endpoint}:m:${monthUTC()}`;
  const dUsed = await store.get(dayKey);
  const mUsed = await store.get(monKey);

  if (dUsed >= lim.day)
    return { allowed: false, reason: 'daily', used: dUsed, limit: lim.day, tier, resetsAt: nextMidnightUTC() };
  if (mUsed >= lim.month)
    return { allowed: false, reason: 'monthly', used: mUsed, limit: lim.month, tier, resetsAt: nextMonthUTC() };

  await store.incr(dayKey);
  await store.incr(monKey);
  return {
    allowed: true,
    tier,
    day: { used: dUsed + 1, limit: lim.day },
    month: { used: mUsed + 1, limit: lim.month },
  };
}

export async function peek(store, { identity, endpoint, tier }) {
  const lim = LIMITS[tier]?.[endpoint];
  if (!lim) return { tier, endpoint, limited: false };
  const dUsed = await store.get(`rl:${identity}:${endpoint}:d:${dayUTC()}`);
  const mUsed = await store.get(`rl:${identity}:${endpoint}:m:${monthUTC()}`);
  return {
    tier,
    endpoint,
    day: { used: dUsed, limit: lim.day, remaining: Math.max(0, lim.day - dUsed) },
    month: { used: mUsed, limit: lim.month, remaining: Math.max(0, lim.month - mUsed) },
  };
}

// ---- Tier resolver (STUB). NEVER trust the client to declare its own tier in
// production. Wire this to RevenueCat server-side, reusing Timbre's pattern
// (timbre_voice_journal/ai-proxy/src/index.js → resolveTier): GET the subscriber
// by app_user_id == identity, map an active entitlement → 'paid'.
// For local testing only, an `X-Tier: paid` header is honored.
export async function resolveTier(identity, headers = {}) {
  const claimed = headers['x-tier'];
  if (claimed === 'paid' || claimed === 'free') return claimed; // DEV ONLY
  return 'free';
}
