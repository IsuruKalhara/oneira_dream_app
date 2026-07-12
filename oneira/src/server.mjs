// Minimal zero-dependency HTTP server exposing the dream API, with usage
// metering + quota enforcement (the paid-app money-safety layer).
//   GET  /health           → provider + limits status
//   GET  /usage            → this user's remaining quota (for the app's UI)
//   POST /explain {dream}  → interpretation JSON (quota-enforced → 429 over cap)
// Ports to a Cloudflare Worker later (same request/response + quota contract).
import http from 'node:http';
import { config } from './config.mjs';
import { explainDream } from './explain.mjs';
import {
  createMemoryStore,
  resolveTier,
  checkAndIncrement,
  peek,
  estimateCostUsd,
  LIMITS,
} from './usage.mjs';

// Dev store. In production this is Cloudflare KV or a Durable Object.
const store = createMemoryStore();

// Anonymous per-device identity (the app generates a UUID once and reuses it).
const identityOf = (req) => req.headers['x-device-token'] || 'anon-dev';

function json(res, code, obj) {
  res.writeHead(code, { 'content-type': 'application/json' });
  res.end(JSON.stringify(obj, null, 2));
}

function readJson(req) {
  return new Promise((resolve, reject) => {
    let d = '';
    req.on('data', (c) => {
      d += c;
      if (d.length > 1e6) req.destroy();
    });
    req.on('end', () => {
      try {
        resolve(d ? JSON.parse(d) : {});
      } catch {
        reject(new Error('invalid JSON body'));
      }
    });
    req.on('error', reject);
  });
}

const server = http.createServer(async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'content-type, x-device-token, x-tier');
  res.setHeader('Access-Control-Allow-Methods', 'POST, GET, OPTIONS');
  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    return res.end();
  }

  const url = new URL(req.url, 'http://localhost');
  const identity = identityOf(req);

  if (req.method === 'GET' && url.pathname === '/health') {
    return json(res, 200, {
      ok: true,
      llm: config.llmProvider,
      embeddings: config.embeddingsProvider,
      limits: LIMITS,
    });
  }

  if (req.method === 'GET' && url.pathname === '/usage') {
    const tier = await resolveTier(identity, req.headers);
    return json(res, 200, await peek(store, { identity, endpoint: 'explain', tier }));
  }

  if (req.method === 'POST' && url.pathname === '/explain') {
    try {
      const body = await readJson(req);
      if (!body.dream) return json(res, 400, { error: 'missing "dream" field' });

      const tier = await resolveTier(identity, req.headers);
      const quota = await checkAndIncrement(store, { identity, endpoint: 'explain', tier });
      if (!quota.allowed) {
        return json(res, 429, {
          error: `${quota.reason} limit reached`,
          used: quota.used,
          limit: quota.limit,
          tier: quota.tier,
          resetsAt: quota.resetsAt,
          upgrade: quota.tier === 'free',
        });
      }

      const out = await explainDream(String(body.dream), { topK: body.topK });

      // TRACK: log the real cost so you can watch unit economics.
      const costUsd = estimateCostUsd(out._meta?.model, out._meta?.usage);
      console.log(
        JSON.stringify({
          t: 'usage',
          endpoint: 'explain',
          identity,
          tier: quota.tier,
          day: quota.day,
          month: quota.month,
          model: out._meta?.model || out.provider,
          costUsd: Number(costUsd.toFixed(6)),
        }),
      );

      return json(res, 200, { ...out, quota: { tier: quota.tier, day: quota.day, month: quota.month } });
    } catch (e) {
      return json(res, 500, { error: String(e?.message || e) });
    }
  }

  json(res, 404, { error: 'not found' });
});

server.listen(config.port, () => {
  console.log(
    `oneira → http://localhost:${config.port}  (llm=${config.llmProvider}, embeddings=${config.embeddingsProvider})`,
  );
});
