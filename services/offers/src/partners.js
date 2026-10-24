// The partner registry: who we hand travellers to, and how the link is built.
//
// This file is the reason the service exists. ADR-006 says the client may not
// construct a payable URL, so every marker lives here, read from the environment and
// never returned to the client — `/v1/offers` hands back a link on our own origin and
// `/go/:token` is where the marker is attached, server side, at redirect time.
//
// ── A warning worth reading before going live ───────────────────────────────────
// `markerParam` below is the query parameter the partner attributes a booking on.
// Where it is marked CONFIRMED the name comes from that partner's own published
// documentation. Where it is marked UNCONFIRMED it is a placeholder and **must** be
// checked against the partner's dashboard before any traffic is sent.
//
// A wrong parameter name does not fail. The link works, the traveller books, the page
// looks exactly right — and the booking is unattributed, so nobody is paid. That is
// the worst failure mode in this whole document, because it is invisible.

/** @typedef {{ host: string, markerParam: string, markerEnv: string, confirmed: boolean, build: (args: any, marker: string) => URL }} Partner */

const encode = (value) => encodeURIComponent(String(value ?? ''));

/** Hosts we will ever redirect to. Defence in depth: see `resolveRedirect`. */
export const ALLOWED_HOSTS = new Set([
  'www.getyourguide.com',
  'www.booking.com',
  'www.viator.com',
  'www.thetrainline.com',
  'www.omio.com',
  'www.discovercars.com',
  'www.welcomepickups.com',
  'www.airalo.com',
]);

/** @type {Record<string, Partner>} */
export const PARTNERS = {
  // CONFIRMED: GetYourGuide's partner programme documents `partner_id`.
  getYourGuide: {
    host: 'www.getyourguide.com',
    markerParam: 'partner_id',
    markerEnv: 'GYG_PARTNER_ID',
    confirmed: true,
    build: ({ productPath, query }, marker) => {
      const url = new URL(productPath ? `https://www.getyourguide.com${productPath}`
                                      : 'https://www.getyourguide.com/s');
      if (!productPath) url.searchParams.set('q', query ?? '');
      url.searchParams.set('partner_id', marker);
      return url;
    },
  },

  // CONFIRMED: Booking.com attributes on `aid`.
  booking: {
    host: 'www.booking.com',
    markerParam: 'aid',
    markerEnv: 'BOOKING_AID',
    confirmed: true,
    build: ({ query, checkin, checkout }, marker) => {
      const url = new URL('https://www.booking.com/searchresults.html');
      url.searchParams.set('ss', query ?? '');
      if (checkin) url.searchParams.set('checkin', checkin);
      if (checkout) url.searchParams.set('checkout', checkout);
      url.searchParams.set('aid', marker);
      return url;
    },
  },

  // UNCONFIRMED. Viator attribution runs through Partner/Impact and the parameter
  // depends on which programme the account is on. Check the dashboard.
  viator: {
    host: 'www.viator.com',
    markerParam: 'pid',
    markerEnv: 'VIATOR_PID',
    confirmed: false,
    build: ({ productPath, query }, marker) => {
      const url = new URL(productPath ? `https://www.viator.com${productPath}`
                                      : 'https://www.viator.com/search');
      if (!productPath) url.searchParams.set('q', query ?? '');
      url.searchParams.set('pid', marker);
      return url;
    },
  },

  // UNCONFIRMED. Trainline runs through Awin, whose click parameter is `awc` and is
  // normally issued per-click by the network rather than held as a constant.
  trainline: {
    host: 'www.thetrainline.com',
    markerParam: 'awc',
    markerEnv: 'TRAINLINE_AWC',
    confirmed: false,
    build: ({ origin, destination }, marker) => {
      const url = new URL('https://www.thetrainline.com/search');
      url.searchParams.set('q', `${origin ?? ''} ${destination ?? ''}`.trim());
      url.searchParams.set('awc', marker);
      return url;
    },
  },

  // UNCONFIRMED. Welcome Pickups partner links are issued per partner.
  welcomePickups: {
    host: 'www.welcomepickups.com',
    markerParam: 'ref',
    markerEnv: 'WELCOME_REF',
    confirmed: false,
    build: ({ query }, marker) => {
      const url = new URL('https://www.welcomepickups.com/');
      url.searchParams.set('q', query ?? '');
      url.searchParams.set('ref', marker);
      return url;
    },
  },

  // UNCONFIRMED. Airalo runs through Impact, which issues a click id per click.
  airalo: {
    host: 'www.airalo.com',
    markerParam: 'irclickid',
    markerEnv: 'AIRALO_REF',
    confirmed: false,
    build: ({ query }, marker) => {
      const url = new URL('https://www.airalo.com/search');
      url.searchParams.set('q', query ?? '');
      url.searchParams.set('irclickid', marker);
      return url;
    },
  },
};

/**
 * Builds the partner URL for a minted token, with the marker attached.
 *
 * Two independent checks, because the signing key leaking must not become an open
 * redirect: the partner has to be one we know, and the host it produces has to be on
 * the allowlist. A token is signed data, not a trusted instruction.
 */
export function resolveRedirect(claims, env) {
  const partner = PARTNERS[claims.partner];
  if (!partner) return null;

  const marker = env[partner.markerEnv];
  // No marker configured means no commission. Sending the traveller anyway would be
  // worse than useless: it looks like it worked and earns nothing.
  if (!marker) return null;

  let url;
  try {
    url = partner.build(claims.args ?? {}, marker);
  } catch {
    return null;
  }
  if (!ALLOWED_HOSTS.has(url.host)) return null;

  // The sub-id rides along so the partner's own reporting can be joined back to the
  // surface that produced the click. Never a user id — see `subIdFor`.
  if (claims.sub) url.searchParams.set('utm_content', claims.sub);
  return url;
}

export { encode };
