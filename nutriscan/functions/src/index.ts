import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { logger } from "firebase-functions";
import { z } from "zod";
import { runUsdaSeedImport } from "./jobs/importUsdaSeed";
import { runVnFctImport } from "./jobs/importVnFct";
import { searchFkbFoods } from "./fkb/search";
import { getFkbFood } from "./fkb/get";
import { matchFood as matchFoodImpl } from "./fkb/match";
import { NutrientsPer100gSchema } from "./fkb/types";

initializeApp();
const db = getFirestore();

const GROQ_API_KEY = defineSecret("GROQ_API_KEY");
const USDA_FDC_API_KEY = defineSecret("USDA_FDC_API_KEY");
const GROQ_BASE_URL = "https://api.groq.com/openai/v1/chat/completions";

// Real backstop for AI-call abuse — the client's "coin" balance is only a UX gate,
// this is what actually stops someone from running unlimited billed Groq requests.
const DAILY_GROQ_CALL_LIMIT = 100;

/**
 * Increments today's call counter for `uid` in a transaction and throws
 * resource-exhausted if the daily cap is already reached.
 */
async function enforceDailyRateLimit(uid: string): Promise<void> {
  const today = new Date().toISOString().slice(0, 10); // YYYY-MM-DD, UTC
  const ref = db.collection("rateLimits").doc(uid);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.exists ? snap.data() : undefined;

    const count = data?.date === today ? (data?.count ?? 0) : 0;
    if (count >= DAILY_GROQ_CALL_LIMIT) {
      throw new HttpsError(
        "resource-exhausted",
        "Daily AI request limit reached. Please try again tomorrow.",
      );
    }

    tx.set(ref, { date: today, count: count + 1 }, { merge: true });
  });
}

interface GroqChatCompletionRequest {
  model: string;
  messages: unknown[];
  temperature?: number;
  top_p?: number;
  max_tokens?: number;
  receiveTimeoutMs?: number;
}

function isValidGroqRequest(data: unknown): data is GroqChatCompletionRequest {
  if (typeof data !== "object" || data === null) return false;
  const d = data as Record<string, unknown>;
  return typeof d.model === "string" && Array.isArray(d.messages);
}

/**
 * Callable proxy for all Groq chat-completion calls made by the app
 * (food analysis, meal plans, insights, health coach chat).
 *
 * Keeps the real Groq API key out of the client entirely and enforces a
 * real per-user daily cap — the mobile app no longer talks to api.groq.com
 * directly. Client passes through the same request body it used to send
 * straight to Groq; this function just forwards it with the real key attached.
 */
export const groqChatCompletion = onCall(
  { secrets: [GROQ_API_KEY], timeoutSeconds: 120, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }
    if (!isValidGroqRequest(request.data)) {
      throw new HttpsError("invalid-argument", "Malformed Groq request body.");
    }

    await enforceDailyRateLimit(request.auth.uid);

    const { receiveTimeoutMs, ...groqBody } = request.data;
    const controller = new AbortController();
    const timeout = setTimeout(
      () => controller.abort(),
      receiveTimeoutMs ?? 30_000,
    );

    try {
      const response = await fetch(GROQ_BASE_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${GROQ_API_KEY.value()}`,
        },
        body: JSON.stringify(groqBody),
        signal: controller.signal,
      });

      const json = await response.json();
      if (!response.ok) {
        logger.warn("Groq API error", { status: response.status, json });
        throw new HttpsError(
          response.status === 429 ? "resource-exhausted" : "internal",
          `Groq API request failed with status ${response.status}`,
        );
      }
      return json;
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      if ((err as Error).name === "AbortError") {
        throw new HttpsError("deadline-exceeded", "Groq request timed out.");
      }
      logger.error("Unexpected error calling Groq", err);
      throw new HttpsError("internal", "Failed to reach the AI service.");
    } finally {
      clearTimeout(timeout);
    }
  },
);

// ---------------------------------------------------------------------------
// IAP receipt verification
// ---------------------------------------------------------------------------

/**
 * NOTE: fill these in from App Store Connect (Users and Access > Integrations
 * > In-App Purchase) before deploying. Needed for the App Store Server API
 * JWT used to verify iOS transactions server-side.
 */
const APPLE_ISSUER_ID = defineSecret("APPLE_ISSUER_ID");
const APPLE_KEY_ID = defineSecret("APPLE_KEY_ID");
const APPLE_PRIVATE_KEY = defineSecret("APPLE_PRIVATE_KEY");
const APPLE_BUNDLE_ID = "com.nutriscan.app";

/**
 * NOTE: fill this in with a Google Cloud service-account JSON that has the
 * "Pub/Sub" + Play Android Developer API access granted in Play Console
 * (Setup > API access) before deploying. Needed to verify Android purchases
 * server-side via the Play Developer API.
 */
const GOOGLE_PLAY_SERVICE_ACCOUNT_JSON = defineSecret(
  "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON",
);
const ANDROID_PACKAGE_NAME = "com.nutriscan.app";

interface VerifyPurchaseRequest {
  platform: "ios" | "android";
  productId: string;
  verificationData: string;
}

function isValidVerifyRequest(data: unknown): data is VerifyPurchaseRequest {
  if (typeof data !== "object" || data === null) return false;
  const d = data as Record<string, unknown>;
  return (
    (d.platform === "ios" || d.platform === "android") &&
    typeof d.productId === "string" &&
    typeof d.verificationData === "string"
  );
}

async function verifyAppleTransaction(
  transactionId: string,
): Promise<{ isActive: boolean; expiryDate: number | null }> {
  const jwt = await import("jsonwebtoken");
  const token = jwt.sign(
    {
      iss: APPLE_ISSUER_ID.value(),
      iat: Math.floor(Date.now() / 1000),
      exp: Math.floor(Date.now() / 1000) + 300,
      aud: "appstoreconnect-v1",
      bid: APPLE_BUNDLE_ID,
    },
    APPLE_PRIVATE_KEY.value(),
    { algorithm: "ES256", keyid: APPLE_KEY_ID.value() },
  );

  // Production App Store Server API. Swap to the sandbox host
  // (api.storekit-sandbox.itunes.apple.com) while testing with sandbox testers.
  const response = await fetch(
    `https://api.storekit.itunes.apple.com/inApps/v1/transactions/${transactionId}`,
    { headers: { Authorization: `Bearer ${token}` } },
  );

  if (!response.ok) {
    throw new HttpsError(
      "permission-denied",
      `Apple transaction verification failed with status ${response.status}`,
    );
  }

  const body = (await response.json()) as { signedTransactionInfo: string };
  // signedTransactionInfo is a JWS; decode without verifying the signature here
  // since it was fetched directly from Apple's server over TLS. Payload carries
  // expiresDate (ms since epoch) and revocationDate when applicable.
  const payloadB64 = body.signedTransactionInfo.split(".")[1];
  const payload = JSON.parse(Buffer.from(payloadB64, "base64").toString());

  const expiryDate: number | null = payload.expiresDate ?? null;
  const isActive =
    !payload.revocationDate && (!expiryDate || expiryDate > Date.now());

  return { isActive, expiryDate };
}

async function verifyGooglePlaySubscription(
  productId: string,
  purchaseToken: string,
): Promise<{ isActive: boolean; expiryDate: number | null }> {
  const { GoogleAuth } = await import("google-auth-library");
  const credentials = JSON.parse(GOOGLE_PLAY_SERVICE_ACCOUNT_JSON.value());
  const auth = new GoogleAuth({
    credentials,
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  });
  const client = await auth.getClient();
  const accessToken = (await client.getAccessToken()).token;

  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/` +
    `${ANDROID_PACKAGE_NAME}/purchases/subscriptions/${productId}/tokens/${purchaseToken}`;

  const response = await fetch(url, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  if (!response.ok) {
    throw new HttpsError(
      "permission-denied",
      `Play subscription verification failed with status ${response.status}`,
    );
  }

  const body = (await response.json()) as {
    expiryTimeMillis: string;
    paymentState?: number;
    cancelReason?: number;
  };
  const expiryDate = parseInt(body.expiryTimeMillis, 10);
  const isActive = expiryDate > Date.now();

  return { isActive, expiryDate };
}

/**
 * Callable that verifies an in-app purchase server-side before granting
 * premium. This is the only path allowed to write `subscription` on
 * `/users/{uid}` — firestore.rules already blocks the client from writing
 * that field directly, so no rules change is needed; the Admin SDK used here
 * bypasses Security Rules by design.
 */
export const verifyPurchase = onCall(
  {
    secrets: [
      APPLE_ISSUER_ID,
      APPLE_KEY_ID,
      APPLE_PRIVATE_KEY,
      GOOGLE_PLAY_SERVICE_ACCOUNT_JSON,
    ],
    timeoutSeconds: 30,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }
    if (!isValidVerifyRequest(request.data)) {
      throw new HttpsError("invalid-argument", "Malformed purchase payload.");
    }

    const { platform, productId, verificationData } = request.data;
    const uid = request.auth.uid;

    // ponytail: no Apple Developer / Play Console account yet, so the real
    // App Store/Play server verification below can't authenticate. Trusts the
    // client-reported purchase instead. Flip IAP_TEST_MODE to false once real
    // APPLE_ISSUER_ID/KEY_ID/PRIVATE_KEY or GOOGLE_PLAY_SERVICE_ACCOUNT_JSON
    // are set from a real account, and redeploy.
    const IAP_TEST_MODE = true;
    const result = IAP_TEST_MODE
      ? { isActive: true, expiryDate: Date.now() + 30 * 24 * 60 * 60 * 1000 }
      : platform === "ios"
        ? await verifyAppleTransaction(verificationData)
        : await verifyGooglePlaySubscription(productId, verificationData);

    if (!result.isActive) {
      throw new HttpsError(
        "failed-precondition",
        "Purchase could not be verified as an active subscription.",
      );
    }

    const subscriptionType = productId.toLowerCase().includes("year")
      ? "yearly"
      : "monthly";

    await db.collection("users").doc(uid).set(
      {
        subscription: {
          isSubscribed: true,
          subscriptionType,
          expiryDate: result.expiryDate,
          verifiedAt: FieldValue.serverTimestamp(),
        },
      },
      { merge: true },
    );

    return { isSubscribed: true, subscriptionType, expiryDate: result.expiryDate };
  },
);

// ---------------------------------------------------------------------------
// FKB (Food Knowledge Base) import callables
// ---------------------------------------------------------------------------

/**
 * Import seed foods from USDA FoodData Central into the `fkb_foods`
 * Firestore collection. Should be run once to populate the initial FKB,
 * then again whenever new seeds are added to the list.
 *
 * Requires authentication. In production, restrict to admin UIDs.
 */
export const importUsdaSeed = onCall(
  {
    secrets: [USDA_FDC_API_KEY],
    timeoutSeconds: 300,
    memory: "512MiB",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }

    logger.info(`importUsdaSeed called by uid=${request.auth.uid}`);

    try {
      const result = await runUsdaSeedImport(USDA_FDC_API_KEY.value());
      return { ok: true, data: result };
    } catch (err) {
      logger.error("importUsdaSeed failed", err);
      throw new HttpsError("internal", `Import failed: ${err}`);
    }
  },
);

/**
 * Import curated Vietnamese foods into the `fkb_foods` collection.
 * These are hand-entered entries for common VN dishes.
 */
export const importVnFct = onCall(
  {
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }

    logger.info(`importVnFct called by uid=${request.auth.uid}`);

    try {
      const result = await runVnFctImport();
      return { ok: true, data: result };
    } catch (err) {
      logger.error("importVnFct failed", err);
      throw new HttpsError("internal", `Import failed: ${err}`);
    }
  },
);

// ---------------------------------------------------------------------------
// FKB (Food Knowledge Base) query callables
// ---------------------------------------------------------------------------

const FkbSearchRequestSchema = z.object({
  query: z.string().min(1),
  locale: z.string().optional(),
  limit: z.number().int().min(1).max(50).optional(),
});

/**
 * Search verified foods in `fkb_foods` by name/alias. See
 * `functions/src/fkb/search.ts` for the ranking algorithm.
 */
export const fkbSearch = onCall(
  { timeoutSeconds: 15, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }

    const parsed = FkbSearchRequestSchema.safeParse(request.data);
    if (!parsed.success) {
      throw new HttpsError("invalid-argument", "Malformed fkbSearch request.");
    }

    try {
      const items = await searchFkbFoods(parsed.data.query, parsed.data.limit ?? 10);
      return { ok: true, data: { items } };
    } catch (err) {
      logger.error("fkbSearch failed", err);
      throw new HttpsError("internal", "FKB search failed.");
    }
  },
);

const FkbGetRequestSchema = z.object({
  food_id: z.string().min(1),
});

/** Fetch a single verified food by `food_id` from `fkb_foods`. */
export const fkbGet = onCall(
  { timeoutSeconds: 15, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }

    const parsed = FkbGetRequestSchema.safeParse(request.data);
    if (!parsed.success) {
      throw new HttpsError("invalid-argument", "Malformed fkbGet request.");
    }

    const food = await getFkbFood(parsed.data.food_id);
    if (!food) {
      throw new HttpsError("not-found", `No FKB food with id ${parsed.data.food_id}`);
    }

    return { ok: true, data: food };
  },
);

const MatchFoodRequestSchema = z.object({
  food_name: z.string().min(1),
  portion_grams: z.number().positive().nullable().optional(),
  locale: z.string().optional(),
  ai_nutrients: NutrientsPer100gSchema,
});

/**
 * After AI vision identifies a food, decide verified (FKB per_100g × grams)
 * vs estimated (AI passthrough). See functions/src/fkb/match.ts and
 * docs/plan.md Phase 1C — the threshold/edge-case rules live there, not here.
 */
export const matchFood = onCall(
  { timeoutSeconds: 15, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }

    const parsed = MatchFoodRequestSchema.safeParse(request.data);
    if (!parsed.success) {
      throw new HttpsError("invalid-argument", "Malformed matchFood request.");
    }

    try {
      const { food_name, portion_grams, ai_nutrients } = parsed.data;
      const result = await matchFoodImpl(food_name, portion_grams, ai_nutrients);
      return { ok: true, data: result };
    } catch (err) {
      // Fail soft to estimated rather than failing the whole scan — the AI
      // macros are still usable even if the FKB lookup itself broke.
      logger.error("matchFood failed, falling back to estimated", err);
      return {
        ok: true,
        data: {
          status: "estimated" as const,
          food_id: null,
          match_score: 0,
          nutrients_total: parsed.data.ai_nutrients,
          source_label: "AI estimate",
        },
      };
    }
  },
);
