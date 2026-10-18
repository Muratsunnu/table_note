import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Apple ile giris yapan kisi hesabini silerken Apple'in verdigi izinler de
// iptal edilmelidir (App Store 5.1.1(v)). Uygulama silmeden hemen once
// Apple'dan tek kullanimlik bir kod alir; bu fonksiyon kodu Apple'da
// jetona cevirir ve jetonu iptal eder. Hesabin kendisini delete_my_account
// siler.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
};

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function base64UrlEncode(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function base64UrlDecode(text: string): Uint8Array {
  const base64 = text.replace(/-/g, "+").replace(/_/g, "/");
  const padded = base64 + "=".repeat((4 - (base64.length % 4)) % 4);
  return Uint8Array.from(atob(padded), (char) => char.charCodeAt(0));
}

/** Apple'in istedigi client_secret: "Apple ile Giris" anahtariyla imzali JWT. */
async function clientSecret(clientId: string): Promise<string> {
  const teamId = Deno.env.get("APPLE_TEAM_ID") ?? "J4VK5R263R";
  const keyId = Deno.env.get("APPLE_SIGNIN_KEY_ID");
  const privateKey = Deno.env.get("APPLE_SIGNIN_PRIVATE_KEY");
  if (!keyId || !privateKey) throw new Error("Apple ile Giris anahtari tanimli degil");
  // .p8 dosyasinin icerigi; satir sonlari "\n" olarak da yapistirilmis olabilir.
  const body = privateKey
    .replace(/\\n/g, "\n")
    .replace(/-----(BEGIN|END) PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  const key = await crypto.subtle.importKey(
    "pkcs8",
    Uint8Array.from(atob(body), (char) => char.charCodeAt(0)),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const now = Math.floor(Date.now() / 1000);
  const encode = (value: unknown) =>
    base64UrlEncode(new TextEncoder().encode(JSON.stringify(value)));
  const input = `${encode({ alg: "ES256", kid: keyId })}.${
    encode({ iss: teamId, iat: now, exp: now + 300, aud: "https://appleid.apple.com", sub: clientId })
  }`;
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(input),
  );
  return `${input}.${base64UrlEncode(new Uint8Array(signature))}`;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const authorization = request.headers.get("Authorization") ?? "";
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const { data: userData, error: userError } = await admin.auth.getUser(
      authorization.replace(/^Bearer\s+/i, ""),
    );
    if (userError || !userData.user) return json({ error: "Unauthorized" }, 401);

    const body = await request.json();
    const code = String(body.authorizationCode ?? "");
    if (!code) return json({ error: "Missing authorization code" }, 400);

    const clientId = Deno.env.get("APPLE_CLIENT_ID") ?? "com.muratstudio.tablenote";
    const secret = await clientSecret(clientId);
    const form = (fields: Record<string, string>) => ({
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams(fields),
    });

    const tokenResponse = await fetch(
      "https://appleid.apple.com/auth/token",
      form({
        client_id: clientId,
        client_secret: secret,
        code,
        grant_type: "authorization_code",
      }),
    );
    if (!tokenResponse.ok) {
      const detail = await tokenResponse.text();
      console.error("Apple kodu kabul etmedi", tokenResponse.status, detail.slice(0, 300));
      return json({ error: "Apple token exchange failed" }, 400);
    }
    const tokens = await tokenResponse.json();

    // Kod bu hesabin Apple kimligine mi ait? Baskasinin Apple izinleri bu
    // yoldan iptal edilemesin.
    const parts = String(tokens.id_token ?? "").split(".");
    const appleSubject = parts.length === 3
      ? JSON.parse(new TextDecoder().decode(base64UrlDecode(parts[1]))).sub
      : null;
    const appleIdentity = (userData.user.identities ?? []).find(
      (identity) => identity.provider === "apple",
    );
    const linkedSubject = appleIdentity?.identity_data?.sub ?? appleIdentity?.id;
    if (!appleSubject || appleSubject !== linkedSubject) {
      console.error("Apple kimligi hesapla eslesmedi");
      return json({ error: "Apple identity mismatch" }, 403);
    }

    const token = tokens.refresh_token ?? tokens.access_token;
    const revokeResponse = await fetch(
      "https://appleid.apple.com/auth/revoke",
      form({
        client_id: clientId,
        client_secret: secret,
        token,
        token_type_hint: tokens.refresh_token ? "refresh_token" : "access_token",
      }),
    );
    if (!revokeResponse.ok) {
      const detail = await revokeResponse.text();
      console.error("Apple iptali reddetti", revokeResponse.status, detail.slice(0, 300));
      return json({ error: "Apple revoke failed" }, 400);
    }
    return json({ revoked: true });
  } catch (error) {
    console.error("Apple iptal hatasi", error instanceof Error ? error.message : String(error));
    return json({ error: "Revoke failed" }, 500);
  }
});
