import { GoogleAuth } from "npm:google-auth-library@9.15.1";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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
    const purchaseToken = String(body.verificationData ?? "");
    // Yillik ve aylik paket. Ortam degiskeni virgulle ayrilmis bir liste
    // alir; eski tekil GOOGLE_PLAY_PRODUCT_ID de gecerli olmaya devam eder.
    const allowedProductIds = new Set(
      (Deno.env.get("GOOGLE_PLAY_PRODUCT_IDS") ??
        Deno.env.get("GOOGLE_PLAY_PRODUCT_ID") ??
        "table_note_premium_yearly,table_note_premium_monthly")
        .split(",")
        .map((id) => id.trim())
        .filter((id) => id.length > 0),
    );
    if (source !== "google_play" || !allowedProductIds.has(productId) || !purchaseToken) {
      return json({ error: "Invalid purchase data" }, 400);
    }

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
    if (!playResponse.ok) return json({ error: "Google Play verification failed" }, 400);

    const playPurchase = await playResponse.json();
    const matchingItem = (playPurchase.lineItems ?? []).find(
      (item: Record<string, unknown>) => item.productId === productId,
    );
    if (!matchingItem?.expiryTime) return json({ error: "Product mismatch" }, 400);

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
    const tokenBytes = new TextEncoder().encode(purchaseToken);
    const digest = await crypto.subtle.digest("SHA-256", tokenBytes);
    const tokenHash = Array.from(new Uint8Array(digest))
      .map((byte) => byte.toString(16).padStart(2, "0"))
      .join("");

    const { error: upsertError } = await admin.from("subscriptions").upsert({
      user_id: userData.user.id,
      platform: "google_play",
      product_id: productId,
      purchase_token_hash: tokenHash,
      status,
      expires_at: expiresAt.toISOString(),
      last_verified_at: new Date().toISOString(),
      store_payload: playPurchase,
    });
    if (upsertError) throw upsertError;

    return json({ isPremium, expiresAt: expiresAt.toISOString(), status });
  } catch (error) {
    console.error(error);
    return json({ error: "Verification failed" }, 500);
  }
});
