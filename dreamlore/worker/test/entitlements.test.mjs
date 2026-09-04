// What Play says a purchase is worth is the only thing that grants a tier, so
// the mapping from its response to ours is worth pinning down — especially the
// states that look like "not subscribed" but aren't.
import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  entitlementFrom,
  isExpired,
  isOurProduct,
  DEFAULT_PRODUCT_IDS,
} from '../src/entitlements.js';

const NOW = Date.parse('2026-09-05T00:00:00Z');
const inDays = (n) =>
  new Date(NOW + n * 86400_000).toISOString();

const sub = (state, productId, expiryTime) => ({
  subscriptionState: state,
  acknowledgementState: 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',
  lineItems: [{ productId, expiryTime }],
});

test('an active yearly subscription grants paid', () => {
  const e = entitlementFrom(
    sub('SUBSCRIPTION_STATE_ACTIVE', DEFAULT_PRODUCT_IDS.yearly, inDays(365)),
    { nowMs: NOW },
  );
  assert.equal(e.tier, 'paid');
  assert.equal(e.expiryMs, Date.parse(inDays(365)));
});

test('a three-day free trial is just an active subscription', () => {
  const e = entitlementFrom(
    sub('SUBSCRIPTION_STATE_ACTIVE', DEFAULT_PRODUCT_IDS.yearly, inDays(3)),
    { nowMs: NOW },
  );
  assert.equal(e.tier, 'paid');
});

test('cancelled keeps what was paid for until it expires', () => {
  const e = entitlementFrom(
    sub('SUBSCRIPTION_STATE_CANCELED', DEFAULT_PRODUCT_IDS.monthly, inDays(12)),
    { nowMs: NOW },
  );
  assert.equal(e.tier, 'paid', 'auto-renew off is not the same as access off');
});

test('a grace period still counts as paid', () => {
  const e = entitlementFrom(
    sub('SUBSCRIPTION_STATE_IN_GRACE_PERIOD', DEFAULT_PRODUCT_IDS.monthly, inDays(2)),
    { nowMs: NOW },
  );
  assert.equal(e.tier, 'paid');
});

test('a payment that has not cleared grants nothing', () => {
  const e = entitlementFrom(
    sub('SUBSCRIPTION_STATE_PENDING', DEFAULT_PRODUCT_IDS.monthly, inDays(30)),
    { nowMs: NOW },
  );
  assert.equal(e.tier, 'free');
});

test('an expired line item grants nothing', () => {
  const e = entitlementFrom(
    sub('SUBSCRIPTION_STATE_ACTIVE', DEFAULT_PRODUCT_IDS.monthly, inDays(-1)),
    { nowMs: NOW },
  );
  assert.equal(e.tier, 'free');
});

test("someone else's product grants nothing", () => {
  const e = entitlementFrom(
    sub('SUBSCRIPTION_STATE_ACTIVE', 'some_other_app_sub', inDays(30)),
    { nowMs: NOW },
  );
  assert.equal(e.tier, 'free');
  assert.equal(isOurProduct('some_other_app_sub'), false);
});

test('configured product ids override the defaults', () => {
  const e = entitlementFrom(
    sub('SUBSCRIPTION_STATE_ACTIVE', 'custom_yearly', inDays(30)),
    { nowMs: NOW, productIds: { monthly: 'custom_monthly', yearly: 'custom_yearly' } },
  );
  assert.equal(e.tier, 'paid');
});

test('isExpired guards a cached entitlement', () => {
  assert.equal(isExpired(null), true);
  assert.equal(isExpired({ tier: 'free', expiryMs: 0 }), true);
  assert.equal(isExpired({ tier: 'paid', expiryMs: NOW - 1 }, NOW), true);
  assert.equal(isExpired({ tier: 'paid', expiryMs: NOW + 1 }, NOW), false);
});
