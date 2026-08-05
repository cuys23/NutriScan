/**
 * Self-check for the Phase 3C APE math in functions/src/fkb/validationLog.ts.
 * Pure-function check, no Firestore/network involved.
 *
 * Run: cd functions && npm run build && cd .. && node eval/selfcheck_validation_log.mjs
 */

import assert from "assert";
import { computeApe } from "../functions/lib/fkb/validationLog.js";

const nutrientsTotal = {
  calories_kcal: 100,
  protein_g: 10,
  carbs_g: 20,
  fat_g: 5,
  fiber_g: 2,
  sugar_g: 1,
  sodium_mg: 50,
};

// AI guessed 10% high on calories, exact on protein.
const aiNutrients = { ...nutrientsTotal, calories_kcal: 110 };

const verifiedApe = computeApe(aiNutrients, nutrientsTotal, true);
assert.strictEqual(verifiedApe.ape_calories_kcal, 10, "10% over should be ape=10");
assert.strictEqual(verifiedApe.ape_protein_g, 0, "exact match should be ape=0");

const estimatedApe = computeApe(aiNutrients, nutrientsTotal, false);
assert.strictEqual(estimatedApe.ape_calories_kcal, null, "no FKB truth -> ape must be null");
assert.strictEqual(estimatedApe.ape_protein_g, null, "no FKB truth -> ape must be null");

const zeroRefApe = computeApe(aiNutrients, { ...nutrientsTotal, sodium_mg: 0 }, true);
assert.strictEqual(zeroRefApe.ape_sodium_mg, null, "zero reference must not divide by zero");

console.log("validationLog.computeApe: all checks passed.");
