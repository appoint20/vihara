// Opaque, signed references to a partner link.
//
// `/v1/offers` returns `https://<service>/go/<token>` and nothing else. The token
// carries what the redirect needs and is signed, so the service can rebuild the
// partner URL at click time without storing anything — and so a crafted token cannot
// make us redirect somewhere we did not choose.
//
// Stateless on purpose. A link service that needed a row per offer would need a
// database before it could serve its first request, and the point of this step is to
// be the smallest useful backend.

const encoder = new TextEncoder();

export function base64url(bytes) {
  let binary = '';
  const view = new Uint8Array(bytes);
  for (const byte of view) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function fromBase64url(text) {
  const padded = text.replace(/-/g, '+').replace(/_/g, '/')
    .padEnd(Math.ceil(text.length / 4) * 4, '=');
  const binary = atob(padded);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

async function hmacKey(secret) {
  return crypto.subtle.importKey(
    'raw', encoder.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'],
  );
}

async function signature(secret, payload) {
  const key = await hmacKey(secret);
  return base64url(await crypto.subtle.sign('HMAC', key, encoder.encode(payload)));
}

/** @param {{partner: string, args: object, sub?: string}} claims */
export async function mint(claims, secret, { ttlSeconds = 60 * 60 * 24 * 14 } = {}) {
  const body = { ...claims, exp: Math.floor(Date.now() / 1000) + ttlSeconds };
  const payload = base64url(encoder.encode(JSON.stringify(body)));
  return `${payload}.${await signature(secret, payload)}`;
}

/**
 * Verifies and decodes. Returns `null` for anything that is not exactly right —
 * tampered, truncated, signed with another key, or expired.
 *
 * The comparison is constant-time. A timing oracle on an HMAC is how a signing key
 * gets forged one byte at a time, and "it is only an affiliate link" stops being true
 * the moment the forged link is an open redirect in a phishing mail.
 */
export async function verify(token, secret) {
  if (typeof token !== 'string') return null;
  const parts = token.split('.');
  if (parts.length !== 2) return null;
  const [payload, provided] = parts;

  const expected = await signature(secret, payload);
  if (!constantTimeEquals(expected, provided)) return null;

  let claims;
  try {
    claims = JSON.parse(new TextDecoder().decode(fromBase64url(payload)));
  } catch {
    return null;
  }
  // A link that outlives its campaign keeps earning for a programme we may have left.
  if (typeof claims.exp !== 'number' || claims.exp < Math.floor(Date.now() / 1000)) {
    return null;
  }
  return claims;
}

export function constantTimeEquals(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string' || a.length !== b.length) return false;
  let difference = 0;
  for (let index = 0; index < a.length; index += 1) {
    difference |= a.charCodeAt(index) ^ b.charCodeAt(index);
  }
  return difference === 0;
}

/**
 * The sub-id a click is attributed to.
 *
 * A salted hash of `(trip, slot, partner)` and nothing else. It must identify the
 * *surface* — which block, which partner — so earnings can be joined back to the part
 * of the plan that produced them, and it must identify no person: no account id, no
 * device id, nothing re-identifiable. ADR-006 is explicit about this, and the salt is
 * what stops the same trip id producing the same sub-id across environments.
 */
export async function subIdFor({ trip, slot, partner }, salt) {
  const material = `${salt}|${trip ?? ''}|${slot ?? ''}|${partner ?? ''}`;
  const digest = await crypto.subtle.digest('SHA-256', encoder.encode(material));
  // 16 base64url characters is 96 bits — far beyond collision risk at any volume this
  // service will see, and short enough to survive a partner's parameter limits.
  return base64url(digest).slice(0, 16);
}
