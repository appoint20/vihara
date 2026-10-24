import { test, describe } from 'node:test';
import assert from 'node:assert/strict';

import worker from '../src/worker.js';
import { mint, verify, subIdFor, constantTimeEquals } from '../src/tokens.js';
import { PARTNERS, ALLOWED_HOSTS, resolveRedirect } from '../src/partners.js';

const ENV = {
  LINK_SIGNING_SECRET: 'test-signing-secret-long-enough',
  SUBID_SALT: 'test-salt',
  PUBLIC_ORIGIN: 'https://offers.test',
  GYG_PARTNER_ID: 'GYG-123',
  BOOKING_AID: 'AID-456',
  AIRALO_REF: 'AIR-789',
};

const call = (url, init) => worker.fetch(new Request(url, init), ENV, {});

describe('tokens', () => {
  test('a minted token verifies and carries its claims', async () => {
    const token = await mint({ partner: 'getYourGuide', args: { query: 'Bologna' }, sub: 'abc' },
                             ENV.LINK_SIGNING_SECRET);
    const claims = await verify(token, ENV.LINK_SIGNING_SECRET);
    assert.equal(claims.partner, 'getYourGuide');
    assert.equal(claims.sub, 'abc');
  });

  test('a token signed with another key is refused', async () => {
    const token = await mint({ partner: 'getYourGuide', args: {} }, 'some-other-secret');
    assert.equal(await verify(token, ENV.LINK_SIGNING_SECRET), null);
  });

  test('a tampered payload is refused', async () => {
    const token = await mint({ partner: 'getYourGuide', args: {} }, ENV.LINK_SIGNING_SECRET);
    const [payload, signature] = token.split('.');
    const forged = `${payload.slice(0, -2)}XY.${signature}`;
    assert.equal(await verify(forged, ENV.LINK_SIGNING_SECRET), null);
  });

  test('an expired token is refused', async () => {
    const token = await mint({ partner: 'getYourGuide', args: {} },
                             ENV.LINK_SIGNING_SECRET, { ttlSeconds: -1 });
    assert.equal(await verify(token, ENV.LINK_SIGNING_SECRET), null);
  });

  test('malformed input is refused rather than thrown', async () => {
    for (const bad of ['', 'nodot', 'a.b.c', null, undefined, 42]) {
      assert.equal(await verify(bad, ENV.LINK_SIGNING_SECRET), null);
    }
  });

  test('the signature comparison does not short-circuit on length or content', () => {
    assert.equal(constantTimeEquals('abc', 'abc'), true);
    assert.equal(constantTimeEquals('abc', 'abd'), false);
    assert.equal(constantTimeEquals('abc', 'ab'), false);
    assert.equal(constantTimeEquals('abc', null), false);
  });
});

describe('sub-ids', () => {
  test('the same surface always produces the same sub-id', async () => {
    const args = { trip: 't1', slot: 'morning', partner: 'getYourGuide' };
    assert.equal(await subIdFor(args, 'salt'), await subIdFor(args, 'salt'));
  });

  test('a different surface produces a different sub-id', async () => {
    const morning = await subIdFor({ trip: 't1', slot: 'morning', partner: 'getYourGuide' }, 'salt');
    const evening = await subIdFor({ trip: 't1', slot: 'evening', partner: 'getYourGuide' }, 'salt');
    assert.notEqual(morning, evening);
  });

  // Staging and production must not merge their click data.
  test('the salt changes the result', async () => {
    const args = { trip: 't1', slot: 'morning', partner: 'getYourGuide' };
    assert.notEqual(await subIdFor(args, 'salt-a'), await subIdFor(args, 'salt-b'));
  });

  // ADR-006: the sub-id identifies a surface, never a person.
  test('the trip id is not recoverable from the sub-id', async () => {
    const sub = await subIdFor({ trip: 'trip-abcdef', slot: 'morning', partner: 'booking' }, 'salt');
    assert.ok(!sub.includes('trip'));
    assert.ok(!sub.includes('abcdef'));
    assert.equal(sub.length, 16);
  });
});

describe('partners', () => {
  // Catches a partner being added without being allowlisted, which would make its
  // links silently un-redirectable.
  test('every partner builds a URL on an allowlisted host', () => {
    for (const [name, partner] of Object.entries(PARTNERS)) {
      const url = partner.build({ query: 'Bologna', origin: 'A', destination: 'B' }, 'MARKER');
      assert.ok(ALLOWED_HOSTS.has(url.host), `${name} builds ${url.host}, which is not allowlisted`);
      assert.equal(url.searchParams.get(partner.markerParam), 'MARKER',
                   `${name} does not attach its marker`);
    }
  });

  test('a partner with no marker configured is not resolved', () => {
    const claims = { partner: 'viator', args: { query: 'Bologna' } };
    assert.equal(resolveRedirect(claims, ENV), null);
  });

  test('an unknown partner is not resolved', () => {
    assert.equal(resolveRedirect({ partner: 'evil', args: {} }, ENV), null);
  });

  test('the sub-id rides along to the partner', () => {
    const url = resolveRedirect(
      { partner: 'getYourGuide', args: { query: 'Bologna' }, sub: 'SUB123' }, ENV,
    );
    assert.equal(url.searchParams.get('utm_content'), 'SUB123');
  });
});

describe('GET /v1/offers', () => {
  test('a ticketed place is offered a ticket', async () => {
    const response = await call(
      'https://offers.test/v1/offers?type=place&place=poi:bologna:asinelli'
      + '&name=Torre&city=Bologna&requires_ticket=1&trip=t1&slot=afternoon',
    );
    assert.equal(response.status, 200);
    const { offers } = await response.json();

    assert.equal(offers.length, 1);
    assert.equal(offers[0].partner, 'getYourGuide');
    assert.equal(offers[0].kind, 'ticket');
    assert.equal(offers[0].price_low, 18);
    assert.equal(offers[0].currency, 'EUR');
  });

  test('a place that needs no ticket is offered nothing', async () => {
    const response = await call(
      'https://offers.test/v1/offers?type=place&place=poi:bologna:piazza&city=Bologna&trip=t1',
    );
    const { offers } = await response.json();
    assert.deepEqual(offers, []);
  });

  // The invariant the whole service exists for (ADR-006).
  test('no affiliate marker ever appears in the response', async () => {
    for (const url of [
      'https://offers.test/v1/offers?type=place&place=poi:bologna:asinelli&city=Bologna&requires_ticket=1',
      'https://offers.test/v1/offers?type=trip&city=Bologna&nights=3',
      'https://offers.test/v1/offers?type=transfer&origin=Bologna&destination=Ravenna',
    ]) {
      const body = await (await call(url)).text();
      for (const marker of ['GYG-123', 'AID-456', 'AIR-789', 'partner_id', 'aid=']) {
        assert.ok(!body.includes(marker), `${marker} leaked into ${url}`);
      }
    }
  });

  test('every offer URL is on our own origin', async () => {
    const { offers } = await (await call(
      'https://offers.test/v1/offers?type=trip&city=Bologna&nights=3',
    )).json();
    assert.ok(offers.length > 0);
    for (const offer of offers) {
      assert.ok(offer.url.startsWith('https://offers.test/go/'), offer.url);
    }
  });

  test('a partner with no marker configured is omitted entirely', async () => {
    const { offers } = await (await call(
      'https://offers.test/v1/offers?type=transfer&origin=Bologna&destination=Ravenna',
    )).json();
    // Neither Trainline nor Welcome Pickups has a marker in ENV.
    assert.deepEqual(offers, []);
  });

  test('a bed is offered for a trip, and data with it', async () => {
    const { offers } = await (await call(
      'https://offers.test/v1/offers?type=trip&city=Bologna&nights=3',
    )).json();
    assert.deepEqual(offers.map((offer) => offer.partner), ['booking', 'airalo']);
  });

  test('an unknown offer type is a 400', async () => {
    const response = await call('https://offers.test/v1/offers?type=nonsense');
    assert.equal(response.status, 400);
  });

  test('offers are never cached', async () => {
    const response = await call('https://offers.test/v1/offers?type=trip&city=Bologna');
    assert.equal(response.headers.get('cache-control'), 'no-store');
  });
});

describe('GET /go/:token', () => {
  async function offerURL(query) {
    const { offers } = await (await call(`https://offers.test/v1/offers?${query}`)).json();
    return offers[0].url;
  }

  test('a minted link redirects to the partner with the marker attached', async () => {
    const url = await offerURL('type=place&place=poi:bologna:asinelli&city=Bologna&requires_ticket=1&trip=t1&slot=afternoon');
    const response = await call(url);

    assert.equal(response.status, 302);
    const target = new URL(response.headers.get('location'));
    assert.equal(target.host, 'www.getyourguide.com');
    assert.equal(target.searchParams.get('partner_id'), 'GYG-123');
  });

  test('the redirect leaks no referrer and is never cached', async () => {
    const url = await offerURL('type=trip&city=Bologna');
    const response = await call(url);
    assert.equal(response.headers.get('referrer-policy'), 'no-referrer');
    assert.equal(response.headers.get('cache-control'), 'no-store');
  });

  test('a forged token does not redirect', async () => {
    const forged = await mint({ partner: 'getYourGuide', args: { query: 'x' } }, 'wrong-secret');
    const response = await call(`https://offers.test/go/${forged}`);
    assert.equal(response.status, 404);
  });

  // A signing key that leaked must not become an open redirect.
  test('a validly signed token for an unknown partner does not redirect', async () => {
    const token = await mint(
      { partner: 'attacker', args: { query: 'https://evil.test' } }, ENV.LINK_SIGNING_SECRET,
    );
    const response = await call(`https://offers.test/go/${token}`);
    assert.equal(response.status, 404);
    assert.equal(response.headers.get('location'), null);
  });

  test('garbage in the path is a 404, not a crash', async () => {
    assert.equal((await call('https://offers.test/go/')).status, 404);
    assert.equal((await call('https://offers.test/go/not-a-token')).status, 404);
  });
});

describe('POST /v1/clicks', () => {
  test('a tap is accepted with no body to read back', async () => {
    const response = await call('https://offers.test/v1/clicks', {
      method: 'POST',
      body: JSON.stringify({ partner: 'getYourGuide', kind: 'ticket', sub: 'abc' }),
    });
    assert.equal(response.status, 204);
  });

  test('invalid json is a 400', async () => {
    const response = await call('https://offers.test/v1/clicks', {
      method: 'POST', body: 'not json',
    });
    assert.equal(response.status, 400);
  });

  test('unknown fields are dropped rather than stored', async () => {
    // The client has no business sending a user id, and this has none keeping one.
    const response = await call('https://offers.test/v1/clicks', {
      method: 'POST',
      body: JSON.stringify({ partner: 'booking', user_id: 'should-be-dropped' }),
    });
    assert.equal(response.status, 204);
  });
});

describe('operational', () => {
  test('health reports which partners are actually configured', async () => {
    const body = await (await call('https://offers.test/health')).json();
    assert.equal(body.ok, true);
    const names = body.partners.map((partner) => partner.name);
    assert.deepEqual(names.sort(), ['airalo', 'booking', 'getYourGuide']);
    // The unconfirmed-parameter warning travels with the data.
    assert.equal(body.partners.find((p) => p.name === 'getYourGuide').confirmed, true);
    assert.equal(body.partners.find((p) => p.name === 'airalo').confirmed, false);
  });

  test('a missing signing secret fails closed', async () => {
    const response = await worker.fetch(
      new Request('https://offers.test/v1/offers?type=trip&city=Bologna'), {}, {},
    );
    assert.equal(response.status, 500);
    // Never a stack trace: this endpoint is public.
    assert.equal((await response.json()).message, 'internal error');
  });

  test('an unknown route is a 404', async () => {
    assert.equal((await call('https://offers.test/nope')).status, 404);
  });
});
