/**
 * Self-check for functions/src/fkb/search.ts's tokenize/scoreFood — the
 * punctuation-stripping bug this guards against silently dropped match_rate
 * to 26% in a real run (banana never scored above the 0.65 threshold
 * because "Bananas, raw" tokenized to {"bananas,", "raw"}).
 *
 * Run: cd functions && npm run build && cd .. && node eval/selfcheck_search_score.mjs
 */

import assert from "assert";
import { tokenize, scoreFood } from "../functions/lib/fkb/search.js";

assert.deepStrictEqual(
  [...tokenize("Bananas, raw")].sort(),
  ["bananas", "raw"],
  "punctuation must be stripped before splitting into words"
);

const banana = {
  food_id: "usda_173944",
  name_en: "Bananas, raw",
  name_vi: "Chuối",
  aliases: ["banana, raw", "chuối"],
  nutrients_per_100g: {
    calories_kcal: 89,
    protein_g: 1.09,
    carbs_g: 22.84,
    fat_g: 0.33,
    fiber_g: 2.6,
    sugar_g: 12.23,
    sodium_mg: 1,
  },
  source: "usda",
  source_ref: "173944",
  verified_at: new Date().toISOString(),
};

const query = "banana raw";
const queryTokens = tokenize(query);
const score = scoreFood(banana, query, queryTokens);

assert.ok(
  score >= 0.65,
  `"banana raw" against real production banana data must clear MATCH_THRESHOLD (0.65), got ${score}`
);

console.log(`search.scoreFood: banana query scores ${score} (>= 0.65). Check passed.`);
