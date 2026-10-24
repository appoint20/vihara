// The offer link service — `docs/MONETISATION.md` step 2.
//
// Three routes and no database:
//
//   GET  /v1/offers   what can be sold against this part of the plan
//   GET  /go/:token   attaches the marker and redirects; this is the click
//   POST /v1/clicks   records the *tap*, which is a different event — see below
//
// The whole reason it exists is ADR-006: affiliate markers must not ship inside an
// iOS binary, because a binary cannot be changed when a programme terminates or a
// marker rotates, and App Review takes days. Here a marker is an environment
// variable.
//
// ── Why both /go/:token and POST /v1/clicks ────────────────────────────────────
// They measure different things and the gap between them is the funnel.
// `/go/:token` fires when the traveller actually arrives at the partner. The POST
// fires when they tap. Taps without arrivals are cancelled hand-offs, dead networks
// and partner apps swallowing the universal link — the attribution leak ADR-006
// warns about. Only logging the redirect would make that leak invisible.

import { PARTNERS, resolveRedirect } from './partners.js';
import { mint, verify, subIdFor } from './tokens.js';
import { productsForPlace, TRIP_PRODUCTS, TRANSFER_PRODUCTS } from './catalogue.js';

const JSON_HEADERS = {
  'content-type': 'application/json; charset=utf-8',
  // Offers carry prices and short-lived tokens. A cached offer is a stale price.
  'cache-control': 'no-store',
};

export default {
  /** @param {Request} request */
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    try {
      if (request.method === 'GET' && url.pathname === '/v1/offers') {
        return await handleOffers(url, env);
      }
      if (request.method === 'GET' && url.pathname.startsWith('/go/')) {
        return await handleRedirect(url, request, env, ctx);
      }
      if (request.method === 'POST' && url.pathname === '/v1/clicks') {
        return await handleClick(request, env, ctx);
      }
      if (request.method === 'GET' && url.pathname === '/health') {
        return json({ ok: true, partners: configuredPartners(env) });
      }
      return json({ message: 'not found' }, 404);
    } catch (error) {
      // The client degrades to no offers, which is a complete plan. Never a 500 with
      // a stack trace: this endpoint is public.
      console.error('offer service error', error);
      return json({ message: 'internal error' }, 500);
    }
  },
};

// ── GET /v1/offers ─────────────────────────────────────────────────────────────

async function handleOffers(url, env) {
  const secret = requireSecret(env);
  const params = url.searchParams;
  const type = params.get('type') ?? 'place';
  const trip = params.get('trip') ?? '';
  const slot = params.get('slot') ?? '';

  let products = [];
  let args = {};

  if (type === 'place') {
    const city = params.get('city') ?? '';
    products = productsForPlace({
      placeId: params.get('place') ?? '',
      requiresTicket: params.get('requires_ticket') === '1',
      city,
    });
    args = { query: [params.get('name'), city].filter(Boolean).join(' '), city };
  } else if (type === 'transfer') {
    const origin = params.get('origin') ?? '';
    const destination = params.get('destination') ?? '';
    products = TRANSFER_PRODUCTS;
    args = { origin, destination, query: destination };
  } else if (type === 'trip') {
    const city = params.get('city') ?? '';
    products = TRIP_PRODUCTS;
    args = { query: city, city, checkin: params.get('checkin') ?? undefined,
             checkout: params.get('checkout') ?? undefined };
  } else {
    return json({ message: 'unknown offer type' }, 400);
  }

  const offers = [];
  for (const product of products) {
    // A partner with no marker configured is not offered at all. Showing a link that
    // cannot earn is worse than showing nothing: it looks like it worked.
    const partner = PARTNERS[product.partner];
    if (!partner || !env[partner.markerEnv]) continue;

    const sub = await subIdFor({ trip, slot, partner: product.partner }, requireSalt(env));
    const token = await mint({
      partner: product.partner,
      args: { ...args, productPath: product.productPath, query: product.query ?? args.query },
      sub,
    }, secret);

    offers.push({
      id: `${product.partner}:${product.kind}:${sub}`,
      partner: product.partner,
      kind: product.kind,
      price_low: product.low ?? null,
      price_high: product.high ?? null,
      currency: 'EUR',
      // Always our own origin. The marker is attached at redirect time and never
      // appears in this response — the invariant the tests pin.
      url: new URL(`/go/${token}`, publicOrigin(env, url)).toString(),
    });
  }

  return json({ offers });
}

// ── GET /go/:token ─────────────────────────────────────────────────────────────

async function handleRedirect(url, request, env, ctx) {
  const token = url.pathname.slice('/go/'.length);
  const claims = await verify(token, requireSecret(env));
  if (!claims) return json({ message: 'link expired' }, 404);

  const target = resolveRedirect(claims, env);
  if (!target) return json({ message: 'link unavailable' }, 404);

  record(env, ctx, {
    event: 'arrival',
    partner: claims.partner,
    sub: claims.sub ?? null,
    at: new Date().toISOString(),
  });

  return new Response(null, {
    status: 302,
    headers: {
      location: target.toString(),
      // Never cache a redirect that carries attribution: a cached 302 is a click
      // that is never counted again.
      'cache-control': 'no-store',
      // The partner must not learn which plan the traveller came from.
      'referrer-policy': 'no-referrer',
    },
  });
}

// ── POST /v1/clicks ────────────────────────────────────────────────────────────

async function handleClick(request, env, ctx) {
  let body;
  try {
    body = await request.json();
  } catch {
    return json({ message: 'invalid json' }, 400);
  }

  // Only fields that describe the surface. Anything else is dropped rather than
  // stored: the client has no business sending a user id and this has no business
  // keeping one.
  record(env, ctx, {
    event: 'tap',
    partner: typeof body.partner === 'string' ? body.partner : null,
    kind: typeof body.kind === 'string' ? body.kind : null,
    sub: typeof body.sub === 'string' ? body.sub : null,
    at: new Date().toISOString(),
  });

  // 204: the client does not wait on this and has nothing to read.
  return new Response(null, { status: 204, headers: { 'cache-control': 'no-store' } });
}

// ── Plumbing ───────────────────────────────────────────────────────────────────

function record(env, ctx, row) {
  const write = async () => {
    if (env.CLICKS?.prepare) {
      await env.CLICKS
        .prepare('INSERT INTO clicks (event, partner, kind, sub, at) VALUES (?, ?, ?, ?, ?)')
        .bind(row.event, row.partner, row.kind ?? null, row.sub, row.at)
        .run();
    } else {
      // No database bound yet. The line still goes somewhere readable, so EPC can be
      // counted off the logs on day one.
      console.log(JSON.stringify({ click: row }));
    }
  };
  // Never make the traveller wait on our bookkeeping.
  if (ctx?.waitUntil) ctx.waitUntil(write()); else void write();
}

function configuredPartners(env) {
  return Object.entries(PARTNERS)
    .filter(([, partner]) => Boolean(env[partner.markerEnv]))
    .map(([name, partner]) => ({ name, confirmed: partner.confirmed }));
}

function publicOrigin(env, requestURL) {
  return env.PUBLIC_ORIGIN ?? requestURL.origin;
}

function requireSecret(env) {
  if (!env.LINK_SIGNING_SECRET) throw new Error('LINK_SIGNING_SECRET is not set');
  return env.LINK_SIGNING_SECRET;
}

function requireSalt(env) {
  if (!env.SUBID_SALT) throw new Error('SUBID_SALT is not set');
  return env.SUBID_SALT;
}

function json(body, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });
}
