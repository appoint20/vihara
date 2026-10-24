// Which places have something to sell, and through whom.
//
// This is the *output of the curation pass* (`docs/MONETISATION.md` step 3): while
// somebody builds the POI index for a region by hand, they attach the partner's
// product id to every ticketed place in the same pass. Doing it later means curating
// twice.
//
// A seed for the Bologna pilot. In production this is a table, not a literal — but
// the shape is the contract either way, so the worker is written against this and
// changes nothing when the table arrives.

/** @type {Record<string, { partner: string, kind: string, productPath?: string, low: number, high?: number }[]>} */
export const PRODUCTS_BY_PLACE = {
  'poi:bologna:asinelli': [
    {
      partner: 'getYourGuide',
      kind: 'ticket',
      productPath: '/bologna-l1005/',
      low: 18,
      high: 32,
    },
  ],
  'poi:bologna:archiginnasio': [
    { partner: 'getYourGuide', kind: 'ticket', productPath: '/bologna-l1005/', low: 12, high: 20 },
  ],
};

/** Offers that depend on the trip rather than on one stop. */
export const TRIP_PRODUCTS = [
  { partner: 'booking', kind: 'lodging', low: 68 },
  { partner: 'airalo', kind: 'esim', low: 9 },
];

export const TRANSFER_PRODUCTS = [
  { partner: 'trainline', kind: 'rail', low: 14 },
  { partner: 'welcomePickups', kind: 'transfer', low: 45, high: 70 },
];

/**
 * What a place can be sold.
 *
 * Falls back to a city-level search offer for anything ticketed we have not curated
 * a product id for, because "we know this needs a ticket and here is where to get
 * one" still beats a warning with nowhere to go. An unticketed place gets nothing —
 * the relevance rule, not a partner decision.
 */
export function productsForPlace({ placeId, requiresTicket, city }) {
  const curated = PRODUCTS_BY_PLACE[placeId];
  if (curated) return curated;
  if (!requiresTicket) return [];
  return [{ partner: 'getYourGuide', kind: 'ticket', query: city, low: 18, high: 32 }];
}
