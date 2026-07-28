interface FirebaseServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

/** Base64url-encode (no padding) — JWT segments use this, not plain base64. */
function base64url(input: ArrayBuffer | string): string {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : new Uint8Array(input);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const pemBody = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const binary = atob(pemBody);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);

  return crypto.subtle.importKey(
    "pkcs8",
    bytes.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

/**
 * Exchanges a self-signed JWT (service-account credentials) for a Google
 * OAuth2 access token scoped to FCM send — the same flow the Firebase Admin
 * SDK does server-side, done by hand here since there's no Node `googleapis`
 * package in the Workers runtime. Token is short-lived (1h); callers should
 * fetch one per invocation rather than trying to cache it across requests.
 */
async function getAccessToken(account: FirebaseServiceAccount): Promise<string> {
  const nowSeconds = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const claims = {
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: nowSeconds,
    exp: nowSeconds + 3600,
  };

  const unsigned = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(claims))}`;
  const key = await importPrivateKey(account.private_key);
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${base64url(signature)}`;

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!response.ok) {
    throw new Error(`Failed to get Google access token: ${response.status} ${await response.text()}`);
  }
  const data = (await response.json()) as { access_token: string };
  return data.access_token;
}

export interface ReminderPush {
  token: string;
  title: string;
  body: string;
}

/**
 * Sends one FCM v1 message per push. Returns per-token success so the
 * caller can decide whether to prune dead tokens — not done automatically
 * here since a single delivery failure isn't necessarily a permanently
 * invalid token (see the caller in index.ts for the actual policy).
 */
export async function sendReminders(
  account: FirebaseServiceAccount,
  pushes: ReminderPush[],
): Promise<Array<{ token: string; ok: boolean; error?: string }>> {
  if (pushes.length === 0) return [];

  const accessToken = await getAccessToken(account);
  const endpoint = `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`;

  const results = await Promise.all(
    pushes.map(async (push) => {
      const response = await fetch(endpoint, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token: push.token,
            notification: { title: push.title, body: push.body },
          },
        }),
      });

      if (response.ok) return { token: push.token, ok: true };
      return { token: push.token, ok: false, error: await response.text() };
    }),
  );

  return results;
}

export type { FirebaseServiceAccount };
