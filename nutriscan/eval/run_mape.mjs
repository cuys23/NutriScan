/**
 * Offline MAPE job — Phase 3B, Exp A (fixed reference / match+scale correctness).
 *
 * For each golden_set.json item: fetch the FKB reference per_100g via `fkbGet`,
 * scale by portion_grams for ref_total, call `matchFood` with just the
 * food_name_hint + portion (isolating match+scale, no vision call involved),
 * and compare. Writes eval/reports/mape_<timestamp>.json.
 *
 * Run: node eval/run_mape.mjs
 *
 * Requires a Firebase Auth ID token (not a gcloud token — callable functions
 * check `request.auth`, which only a real Firebase Auth ID token populates):
 *   EVAL_ID_TOKEN=<token> node eval/run_mape.mjs
 *
 * Get a token: sign into the app (any provider) in debug mode, then in a
 * debug console run `await FirebaseAuth.instance.currentUser.getIdToken()`
 * (or the JS/iOS/Android equivalent), or use the Firebase Auth REST
 * `signInWithPassword` endpoint against a dedicated eval test account.
 *
 * Against the local emulator instead of prod, set:
 *   EVAL_FUNCTIONS_BASE_URL=http://127.0.0.1:5001/nutriscan-75d57/us-central1
 * and any non-empty EVAL_ID_TOKEN (the Functions emulator does not verify
 * Firebase Auth tokens against a real project unless the Auth emulator is
 * also running and the token came from it).
 */

import { readFile, mkdir, writeFile } from "fs/promises";
import { fileURLToPath } from "url";
import path from "path";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const PROJECT_ID = "nutriscan-75d57";
const REGION = "us-central1";
const BASE_URL =
  process.env.EVAL_FUNCTIONS_BASE_URL ??
  `https://${REGION}-${PROJECT_ID}.cloudfunctions.net`;

const NUTRIENT_KEYS = [
  "calories_kcal",
  "protein_g",
  "carbs_g",
  "fat_g",
  "fiber_g",
  "sugar_g",
  "sodium_mg",
];

const ZERO_NUTRIENTS = Object.fromEntries(NUTRIENT_KEYS.map((k) => [k, 0]));

function validateGoldenSet(items) {
  const errors = [];
  const seenIds = new Set();
  for (const item of items) {
    if (seenIds.has(item.id)) errors.push(`duplicate id: ${item.id}`);
    seenIds.add(item.id);
    if (!(item.portion_grams > 0)) {
      errors.push(`${item.id}: portion_grams must be > 0`);
    }
    if (!item.fdc_id && !item.food_id) {
      errors.push(`${item.id}: needs fdc_id or food_id`);
    }
  }
  return errors;
}

async function callFunction(idToken, name, data) {
  const response = await fetch(`${BASE_URL}/${name}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${idToken}`,
    },
    body: JSON.stringify({ data }),
  });
  const body = await response.json();
  if (!response.ok || body.error) {
    throw new Error(`${name} failed: ${JSON.stringify(body.error ?? body)}`);
  }
  return body.result.data;
}

function scale(per100g, portionGrams) {
  const factor = portionGrams / 100;
  return Object.fromEntries(
    NUTRIENT_KEYS.map((k) => [k, per100g[k] * factor])
  );
}

function ape(pred, ref) {
  const out = {};
  for (const k of NUTRIENT_KEYS) {
    out[k] = ref[k] > 0 ? (Math.abs(pred[k] - ref[k]) / ref[k]) * 100 : null;
  }
  return out;
}

async function main() {
  const goldenSetPath = path.join(__dirname, "golden_set.json");
  const goldenSet = JSON.parse(await readFile(goldenSetPath, "utf8"));

  const schemaErrors = validateGoldenSet(goldenSet);
  if (schemaErrors.length > 0) {
    console.error("golden_set.json failed validation:");
    for (const e of schemaErrors) console.error(`  - ${e}`);
    process.exit(1);
  }
  console.log(`golden_set.json: ${goldenSet.length} items, schema OK.`);

  if (process.argv.includes("--validate-only")) return;

  const idToken = process.env.EVAL_ID_TOKEN;
  if (!idToken) {
    console.error(
      "\nEVAL_ID_TOKEN is required to call fkbGet/matchFood — see the header comment in this file for how to get one."
    );
    process.exit(1);
  }

  console.log(`Running Exp A against ${BASE_URL} ...\n`);

  const items = [];
  let matchedCount = 0;
  let correctFoodIdCount = 0;
  const apeSums = Object.fromEntries(NUTRIENT_KEYS.map((k) => [k, 0]));
  const apeCounts = Object.fromEntries(NUTRIENT_KEYS.map((k) => [k, 0]));

  for (const gsItem of goldenSet) {
    const expectedFoodId = gsItem.food_id ?? `usda_${gsItem.fdc_id}`;
    try {
      const [refFood, matchResult] = await Promise.all([
        callFunction(idToken, "fkbGet", { food_id: expectedFoodId }),
        callFunction(idToken, "matchFood", {
          food_name: gsItem.food_name_hint,
          portion_grams: gsItem.portion_grams,
          ai_nutrients: ZERO_NUTRIENTS,
        }),
      ]);

      const refTotal = scale(refFood.nutrients_per_100g, gsItem.portion_grams);
      const predTotal = matchResult.nutrients_total;
      const itemApe = ape(predTotal, refTotal);

      const matched = matchResult.status === "verified";
      if (matched) matchedCount += 1;
      if (matched && matchResult.food_id === expectedFoodId) {
        correctFoodIdCount += 1;
      }

      for (const k of NUTRIENT_KEYS) {
        if (itemApe[k] !== null) {
          apeSums[k] += itemApe[k];
          apeCounts[k] += 1;
        }
      }

      items.push({
        id: gsItem.id,
        food_name_hint: gsItem.food_name_hint,
        expected_food_id: expectedFoodId,
        matched_food_id: matchResult.food_id,
        match_score: matchResult.match_score,
        status: matchResult.status,
        ref_total: refTotal,
        pred_total: predTotal,
        ape: itemApe,
      });

      console.log(`  ${gsItem.id} ${matched ? "✓" : "✗"} ${gsItem.food_name_hint}`);
    } catch (err) {
      console.error(`  ${gsItem.id} ERROR: ${err.message}`);
      items.push({ id: gsItem.id, food_name_hint: gsItem.food_name_hint, error: err.message });
    }
  }

  const mape = Object.fromEntries(
    NUTRIENT_KEYS.map((k) => [
      k,
      apeCounts[k] > 0 ? Number((apeSums[k] / apeCounts[k]).toFixed(2)) : null,
    ])
  );

  const report = {
    prompt_version: "exp_a_matcher_only",
    model: "n/a — matcher isolated, no vision call",
    match_rate: Number((matchedCount / goldenSet.length).toFixed(3)),
    food_id_accuracy: Number((correctFoodIdCount / goldenSet.length).toFixed(3)),
    mape,
    n: goldenSet.length,
    items,
  };

  const reportsDir = path.join(__dirname, "reports");
  await mkdir(reportsDir, { recursive: true });
  const stamp = new Date().toISOString().replace(/[-:]/g, "").slice(0, 13).replace("T", "_");
  const reportPath = path.join(reportsDir, `mape_${stamp}.json`);
  await writeFile(reportPath, JSON.stringify(report, null, 2));

  console.log(`\nmatch_rate=${report.match_rate} food_id_accuracy=${report.food_id_accuracy}`);
  console.log("mape:", report.mape);
  console.log(`\nReport written to ${path.relative(process.cwd(), reportPath)}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
