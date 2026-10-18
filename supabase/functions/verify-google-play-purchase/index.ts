import { GoogleAuth } from "npm:google-auth-library@9.15.1";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Adi tarihsel: ilk once yalnizca Google Play vardi. Artik App Store
// satin almalarini da dogrular; istemci ayni fonksiyonu cagirir.

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

/** Magazanin onayladigi abonelik: tabloya yazilacak her sey. */
type Verified = {
  productId: string;
  /** Satin almayi kalici olarak taniyan deger; ozeti tabloda tekildir. */
  tokenKey: string;
  expiresAt: Date;
  isPremium: boolean;
  status: "active" | "grace_period" | "canceled" | "expired";
  payload: unknown;
};

/** Magazanin reddettigi durum: istemciye donecek cevap. */
type Rejected = { error: string; status: number; detail?: Record<string, unknown> };

function allowedProductIds(): Set<string> {
  // Yillik ve aylik paket; iki magazada da ayni kimlikler. Ortam degiskeni
  // virgulle ayrilmis bir liste alir; eski tekil GOOGLE_PLAY_PRODUCT_ID de
  // gecerli olmaya devam eder.
  return new Set(
    (Deno.env.get("GOOGLE_PLAY_PRODUCT_IDS") ??
      Deno.env.get("GOOGLE_PLAY_PRODUCT_ID") ??
      "table_note_premium_yearly,table_note_premium_monthly")
      .split(",")
      .map((id) => id.trim())
      .filter((id) => id.length > 0),
  );
}

// ============== GOOGLE PLAY ==============

async function verifyGooglePlay(
  productId: string,
  purchaseToken: string,
): Promise<Verified | Rejected> {
  const credentials = JSON.parse(Deno.env.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON") ?? "{}");
  const auth = new GoogleAuth({
    credentials,
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  });
  const accessToken = await auth.getAccessToken();
  const packageName = Deno.env.get("GOOGLE_PLAY_PACKAGE_NAME") ??
    "com.muratstudio.tablenote";
  const endpoint =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`;
  const playResponse = await fetch(endpoint, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!playResponse.ok) {
    // Google'in cevabi gizli deger icermez; nedeni (yetki, paket adi,
    // gecersiz token) gormek icin kayda yazilir.
    const detail = await playResponse.text();
    console.error("Google Play reddetti", playResponse.status, detail.slice(0, 500));
    return {
      error: "Google Play verification failed",
      status: 400,
      detail: { playStatus: playResponse.status },
    };
  }

  const playPurchase = await playResponse.json();
  const matchingItem = (playPurchase.lineItems ?? []).find(
    (item: Record<string, unknown>) => item.productId === productId,
  );
  if (!matchingItem?.expiryTime) {
    console.error("Urun eslesmedi", productId, playPurchase.subscriptionState);
    return { error: "Product mismatch", status: 400 };
  }

  const expiresAt = new Date(matchingItem.expiryTime);
  const state = String(playPurchase.subscriptionState ?? "");
  const premiumStates = new Set([
    "SUBSCRIPTION_STATE_ACTIVE",
    "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
    "SUBSCRIPTION_STATE_CANCELED",
  ]);
  const isPremium = premiumStates.has(state) && expiresAt > new Date();
  const status = state === "SUBSCRIPTION_STATE_IN_GRACE_PERIOD"
    ? "grace_period"
    : isPremium
    ? "active"
    : state === "SUBSCRIPTION_STATE_CANCELED"
    ? "canceled"
    : "expired";
  return {
    productId,
    tokenKey: purchaseToken,
    expiresAt,
    isPremium,
    status,
    payload: playPurchase,
  };
}

// ============== APP STORE ==============

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

/** JWS'in govdesi. Imza burada denetlenmez: icerik Apple'a sorularak dogrulanir. */
function jwsPayload(jws: unknown): Record<string, unknown> | null {
  const parts = String(jws ?? "").split(".");
  if (parts.length !== 3) return null;
  try {
    return JSON.parse(new TextDecoder().decode(base64UrlDecode(parts[1])));
  } catch {
    return null;
  }
}

/** App Store Server API icin kisa omurlu imzali anahtar (ES256). */
async function appStoreToken(bundleId: string): Promise<string> {
  const issuerId = Deno.env.get("APP_STORE_ISSUER_ID");
  const keyId = Deno.env.get("APP_STORE_KEY_ID");
  const privateKey = Deno.env.get("APP_STORE_PRIVATE_KEY");
  if (!issuerId || !keyId || !privateKey) {
    throw new Error("App Store anahtari tanimli degil");
  }
  // .p8 dosyasinin icerigi; gizli degere satir sonlari "\n" olarak da
  // yapistirilmis olabilir.
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
  const input = `${encode({ alg: "ES256", kid: keyId, typ: "JWT" })}.${
    encode({ iss: issuerId, iat: now, exp: now + 300, aud: "appstoreconnect-v1", bid: bundleId })
  }`;
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(input),
  );
  return `${input}.${base64UrlEncode(new Uint8Array(signature))}`;
}

async function verifyAppStore(
  allowed: Set<string>,
  signedTransaction: string,
): Promise<Verified | Rejected> {
  const bundleId = Deno.env.get("APP_STORE_BUNDLE_ID") ?? "com.muratstudio.tablenote";
  // Uygulamanin gonderdigi imzali islemden yalnizca numara alinir; aboneligin
  // gercek durumu Apple'a sorulur. Yenileme ve iade de boylece gorunur.
  const claimed = jwsPayload(signedTransaction);
  const transactionId = String(claimed?.originalTransactionId ?? claimed?.transactionId ?? "");
  if (!/^\d+$/.test(transactionId)) {
    console.error("Gecersiz App Store islemi");
    return { error: "Invalid purchase data", status: 400 };
  }

  const token = await appStoreToken(bundleId);
  // TestFlight ve Apple incelemesi deneme ortaminda satin alir: islem gercek
  // ortamda yoksa deneme ortamina bakilir.
  const hosts = [
    "https://api.storekit.itunes.apple.com",
    "https://api.storekit-sandbox.itunes.apple.com",
  ];
  for (const host of hosts) {
    const response = await fetch(`${host}/inApps/v1/subscriptions/${transactionId}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (response.status === 404) continue;
    if (!response.ok) {
      const detail = await response.text();
      console.error("App Store reddetti", response.status, detail.slice(0, 500));
      return {
        error: "App Store verification failed",
        status: 400,
        detail: { storeStatus: response.status },
      };
    }

    const statuses = await response.json();
    if (statuses.bundleId !== bundleId) {
      console.error("Paket kimligi eslesmedi", statuses.bundleId);
      return { error: "Product mismatch", status: 400 };
    }
    const latest = (statuses.data ?? []).flatMap(
      (group: Record<string, unknown>) => (group.lastTransactions as unknown[]) ?? [],
    ) as Record<string, unknown>[];
    const entry = latest.find((item) => String(item.originalTransactionId) === transactionId) ??
      latest[0];
    const transaction = jwsPayload(entry?.signedTransactionInfo);
    const renewal = jwsPayload(entry?.signedRenewalInfo);
    const productId = String(transaction?.productId ?? "");
    if (!entry || !transaction || !allowed.has(productId)) {
      console.error("Urun eslesmedi", productId);
      return { error: "Product mismatch", status: 400 };
    }

    // 1 etkin, 2 bitti, 3 odeme yeniden deneniyor, 4 ek sure, 5 iade edildi.
    const appleStatus = Number(entry.status);
    const graceEnds = Number(renewal?.gracePeriodExpiresDate ?? 0);
    const expiresAt = new Date(
      appleStatus === 4 && graceEnds > 0 ? graceEnds : Number(transaction.expiresDate ?? 0),
    );
    const revoked = transaction.revocationDate != null || appleStatus === 5;
    const isPremium = !revoked && (appleStatus === 1 || appleStatus === 4) &&
      expiresAt > new Date();
    const status = isPremium
      ? appleStatus === 4 ? "grace_period" : "active"
      : revoked
      ? "canceled"
      : "expired";
    return {
      productId,
      tokenKey: `app_store:${transactionId}`,
      expiresAt,
      isPremium,
      status,
      payload: {
        environment: statuses.environment,
        status: appleStatus,
        transaction,
        renewal,
      },
    };
  }
  console.error("App Store islemi bulunamadi");
  return { error: "App Store verification failed", status: 400, detail: { storeStatus: 404 } };
}

// ============== ISTEK ==============

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const authorization = request.headers.get("Authorization") ?? "";
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const admin = createClient(supabaseUrl, serviceRoleKey);
    const { data: userData, error: userError } = await admin.auth.getUser(
      authorization.replace(/^Bearer\s+/i, ""),
    );
    if (userError || !userData.user) return json({ error: "Unauthorized" }, 401);

    const body = await request.json();
    const productId = String(body.productId ?? "");
    const source = String(body.source ?? "");
    const verificationData = String(body.verificationData ?? "");
    const allowed = allowedProductIds();
    if (
      (source !== "google_play" && source !== "app_store") ||
      !allowed.has(productId) || !verificationData
    ) {
      console.error("Gecersiz satin alma verisi", {
        source,
        productId,
        hasToken: !!verificationData,
      });
      return json({ error: "Invalid purchase data" }, 400);
    }

    const result = source === "google_play"
      ? await verifyGooglePlay(productId, verificationData)
      : await verifyAppStore(allowed, verificationData);
    if ("error" in result) {
      return json({ error: result.error, ...result.detail }, result.status);
    }

    const tokenBytes = new TextEncoder().encode(result.tokenKey);
    const digest = await crypto.subtle.digest("SHA-256", tokenBytes);
    const tokenHash = Array.from(new Uint8Array(digest))
      .map((byte) => byte.toString(16).padStart(2, "0"))
      .join("");

    const { error: upsertError } = await admin.from("subscriptions").upsert({
      user_id: userData.user.id,
      platform: source,
      product_id: result.productId,
      purchase_token_hash: tokenHash,
      status: result.status,
      expires_at: result.expiresAt.toISOString(),
      last_verified_at: new Date().toISOString(),
      store_payload: result.payload,
    });
    if (upsertError) throw upsertError;

    return json({
      isPremium: result.isPremium,
      expiresAt: result.expiresAt.toISOString(),
      status: result.status,
    });
  } catch (error) {
    // Anahtar bozuksa ya da magazadan erisim jetonu alinamazsa buraya
    // duser; hata metni gizli deger icermez.
    console.error("Dogrulama hatasi", error instanceof Error ? error.message : String(error));
    return json({ error: "Verification failed" }, 500);
  }
});
