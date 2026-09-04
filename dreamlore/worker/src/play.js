/**
 * Google Play Developer API client for the Worker.
 *
 * Signs a service-account JWT with WebCrypto (Workers have no googleapis SDK),
 * exchanges it for an OAuth access token, and reads subscription purchases.
 * Used by /billing/verify so entitlements come from Play itself rather than
 * from whatever the client claims.
 *
 * Required bindings:
 *   env.PLAY_SERVICE_ACCOUNT_JSON   (secret) full service-account key JSON
 *   env.ANDROID_PACKAGE_NAME        (var)    e.g. com.bitfuzed.dreamlore
 */

const TOKEN_URL = 'https://oauth2.googleapis.com/token';
const SCOPE = 'https://www.googleapis.com/auth/androidpublisher';
const API_BASE = 'https://androidpublisher.googleapis.com/androidpublisher/v3';

/** Access tokens live an hour; refresh a little early to avoid edge misses. */
const TOKEN_TTL_SECONDS = 3000;
const TOKEN_CACHE_KEY = 'gtok:androidpublisher';

/** Raised for any Play-side failure so callers can tell it from a bug here. */
export class PlayApiError extends Error {
  constructor(message, status) {
    super(message);
    this.name = 'PlayApiError';
    this.status = status;
  }
}

/** True when the Worker has everything it needs to talk to Play. */
export function isPlayConfigured(env) {
  return Boolean(env.PLAY_SERVICE_ACCOUNT_JSON && env.ANDROID_PACKAGE_NAME);
}

/**
 * Fetches a `purchases.subscriptionsv2` resource for a purchase token.
 * Throws [PlayApiError] when Play rejects the token or the call fails.
 */
export async function getSubscription(env, purchaseToken) {
  const accessToken = await getAccessToken(env);
  const url =
    `${API_BASE}/applications/${encodeURIComponent(env.ANDROID_PACKAGE_NAME)}` +
    `/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`;

  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new PlayApiError(
      body?.error?.message || `Play API returned ${res.status}`,
      res.status,
    );
  }
  return body;
}

/**
 * Returns a cached-or-fresh OAuth access token. Cached in the KV namespace the
 * Worker already binds (it is a general-purpose short-lived cache, not only
 * rate-limit counters) so a burst of verifications doesn't re-sign a JWT and
 * round-trip to Google every time.
 */
export async function getAccessToken(env) {
  if (env.RATE_LIMIT) {
    const cached = await env.RATE_LIMIT.get(TOKEN_CACHE_KEY);
    if (cached) return cached;
  }

  const credentials = parseServiceAccount(env.PLAY_SERVICE_ACCOUNT_JSON);
  const assertion = await signJwt(credentials);

  const res = await fetch(TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok || !body.access_token) {
    throw new PlayApiError(
      body?.error_description || body?.error || 'Could not mint a Play access token',
      res.status,
    );
  }

  if (env.RATE_LIMIT) {
    await env.RATE_LIMIT.put(TOKEN_CACHE_KEY, body.access_token, {
      expirationTtl: TOKEN_TTL_SECONDS,
    });
  }
  return body.access_token;
}

function parseServiceAccount(raw) {
  let credentials;
  try {
    credentials = JSON.parse(raw);
  } catch {
    throw new PlayApiError('PLAY_SERVICE_ACCOUNT_JSON is not valid JSON', 500);
  }
  if (!credentials.client_email || !credentials.private_key) {
    throw new PlayApiError(
      'PLAY_SERVICE_ACCOUNT_JSON is missing client_email/private_key',
      500,
    );
  }
  return credentials;
}

/** Builds and RS256-signs the assertion Google exchanges for an access token. */
async function signJwt(credentials) {
  const issuedAt = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const claims = {
    iss: credentials.client_email,
    scope: SCOPE,
    aud: credentials.token_uri || TOKEN_URL,
    iat: issuedAt,
    exp: issuedAt + 3600,
  };

  const payload =
    `${base64Url(JSON.stringify(header))}.${base64Url(JSON.stringify(claims))}`;
  const key = await importPrivateKey(credentials.private_key);
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(payload),
  );
  return `${payload}.${base64UrlBytes(new Uint8Array(signature))}`;
}

async function importPrivateKey(pem) {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '');
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
}

function base64Url(text) {
  return base64UrlBytes(new TextEncoder().encode(text));
}

function base64UrlBytes(bytes) {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
