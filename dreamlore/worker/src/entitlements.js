/**
 * Maps a Google Play `purchases.subscriptionsv2` resource onto Dreamlore's
 * tiers. There is one paid tier — `paid` — sold as two products (monthly and
 * yearly) that grant exactly the same thing.
 *
 * Kept free of I/O and of Worker globals so it can be unit-tested directly
 * (see ../test/entitlements.test.mjs): everything here is a pure function of
 * the Play response plus the caller's product-id configuration.
 *
 * States reference:
 * https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.subscriptionsv2#SubscriptionState
 */

/** Product ids, matching Config in the Flutter app. */
export const DEFAULT_PRODUCT_IDS = {
  monthly: 'dreamlore_plus_monthly',
  yearly: 'dreamlore_plus_yearly',
};

/**
 * States in which the user still has what they paid for.
 *
 * CANCELED is deliberately included: it only means auto-renew is off, and the
 * user keeps access until `expiryTime` — cutting them off early would be
 * taking money for a period we didn't serve. PENDING is deliberately excluded:
 * a deferred payment that hasn't cleared is not a purchase yet.
 *
 * A free trial reports SUBSCRIPTION_STATE_ACTIVE with an expiryTime three days
 * out, so trials need no special case — they simply expire early if the user
 * cancels, and Play stops reporting them as active.
 */
const ENTITLED_STATES = new Set([
  'SUBSCRIPTION_STATE_ACTIVE',
  'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
  'SUBSCRIPTION_STATE_CANCELED',
]);

/**
 * @param {object} subscription  a purchases.subscriptionsv2 resource
 * @param {object} [options]
 * @param {{monthly: string, yearly: string}} [options.productIds]
 * @param {number} [options.nowMs]  injectable clock, for tests
 * @returns {{tier: 'free'|'paid', expiryMs: number, state: string,
 *            acknowledged: boolean}}
 */
export function entitlementFrom(subscription, options = {}) {
  const productIds = options.productIds || DEFAULT_PRODUCT_IDS;
  const nowMs = options.nowMs ?? Date.now();
  const state =
    subscription?.subscriptionState || 'SUBSCRIPTION_STATE_UNSPECIFIED';
  const acknowledged =
    subscription?.acknowledgementState === 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED';

  const none = { tier: 'free', expiryMs: 0, state, acknowledged };
  if (!ENTITLED_STATES.has(state)) return none;

  let expiryMs = 0;
  for (const item of subscription?.lineItems || []) {
    if (!isOurProduct(item?.productId, productIds)) continue;
    // An expiry in the past means Play hasn't caught up with its own state;
    // trust the timestamp, since that is what the user actually paid through.
    const itemExpiryMs = Date.parse(item?.expiryTime || '');
    if (!Number.isFinite(itemExpiryMs) || itemExpiryMs <= nowMs) continue;
    if (itemExpiryMs > expiryMs) expiryMs = itemExpiryMs;
  }

  if (expiryMs === 0) return none;
  return { tier: 'paid', expiryMs, state, acknowledged };
}

/** True when a Play product id is one of ours. */
export function isOurProduct(productId, productIds = DEFAULT_PRODUCT_IDS) {
  if (!productId) return false;
  return productId === productIds.monthly || productId === productIds.yearly;
}

/** Reads the configured product ids off the Worker env, with defaults. */
export function productIdsFromEnv(env) {
  return {
    monthly: env.PLAY_MONTHLY_PRODUCT_ID || DEFAULT_PRODUCT_IDS.monthly,
    yearly: env.PLAY_YEARLY_PRODUCT_ID || DEFAULT_PRODUCT_IDS.yearly,
  };
}

/** True once a stored entitlement's paid-through date has passed. */
export function isExpired(entitlement, nowMs = Date.now()) {
  if (!entitlement) return true;
  if (entitlement.tier !== 'paid') return true;
  return !(entitlement.expiryMs > nowMs);
}
