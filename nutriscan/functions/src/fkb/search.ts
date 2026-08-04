/**
 * FKB search — ranks `fkb_foods` against a free-text query.
 *
 * MVP candidate generation (docs/plan.md Phase 1B): the collection is small
 * (seed import, low hundreds of docs), so we load it into the function
 * instance and score in memory rather than building Firestore compound
 * indexes for partial-text search. Revisit (Postgres + pg_trgm, or a search
 * service) once the collection is too large to read on every call — see
 * ADR-002.
 */

import { getFirestore } from "firebase-admin/firestore";
import { FkbFood } from "./types";

const FKB_COLLECTION = "fkb_foods";

export interface FkbSearchHit {
  food_id: string;
  name_en: string;
  name_vi: string;
  score: number;
  nutrients_per_100g: FkbFood["nutrients_per_100g"];
  source: FkbFood["source"];
  source_ref: string;
}

/** Trim, lowercase, collapse whitespace. */
function normalize(text: string): string {
  return text.toLowerCase().trim().replace(/\s+/g, " ");
}

function tokenize(text: string): Set<string> {
  return new Set(normalize(text).split(" ").filter((w) => w.length >= 2));
}

function jaccard(a: Set<string>, b: Set<string>): number {
  if (a.size === 0 || b.size === 0) return 0;
  let intersection = 0;
  for (const t of a) if (b.has(t)) intersection++;
  const union = a.size + b.size - intersection;
  return union === 0 ? 0 : intersection / union;
}

/**
 * Score a single food against the normalized query per plan.md Phase 1B:
 *   exact name_en or name_vi = 1.0
 *   alias exact               = 0.95
 *   token Jaccard on names     = 0.0–0.9
 */
function scoreFood(food: FkbFood, normalizedQuery: string, queryTokens: Set<string>): number {
  if (
    normalize(food.name_en) === normalizedQuery ||
    normalize(food.name_vi) === normalizedQuery
  ) {
    return 1.0;
  }

  if (food.aliases.some((alias) => normalize(alias) === normalizedQuery)) {
    return 0.95;
  }

  const nameTokens = new Set<string>([
    ...tokenize(food.name_en),
    ...tokenize(food.name_vi),
    ...food.aliases.flatMap((a) => [...tokenize(a)]),
  ]);

  return jaccard(queryTokens, nameTokens) * 0.9;
}

/**
 * Search `fkb_foods` for foods matching `query`, ranked by score descending.
 * Returns at most `limit` hits with score > 0.
 */
export async function searchFkbFoods(
  query: string,
  limit = 10
): Promise<FkbSearchHit[]> {
  const normalizedQuery = normalize(query);
  if (normalizedQuery.length < 2) return [];

  const queryTokens = tokenize(query);
  const db = getFirestore();
  const snapshot = await db.collection(FKB_COLLECTION).get();

  const scored: FkbSearchHit[] = [];
  snapshot.forEach((doc) => {
    const food = doc.data() as FkbFood;
    const score = scoreFood(food, normalizedQuery, queryTokens);
    if (score > 0) {
      scored.push({
        food_id: food.food_id,
        name_en: food.name_en,
        name_vi: food.name_vi,
        score,
        nutrients_per_100g: food.nutrients_per_100g,
        source: food.source,
        source_ref: food.source_ref,
      });
    }
  });

  scored.sort((a, b) => b.score - a.score);
  return scored.slice(0, limit);
}
