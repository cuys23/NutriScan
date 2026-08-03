/**
 * Firestore upsert helpers for the FKB (Food Knowledge Base).
 *
 * Collection: `fkb_foods`, document id = `food_id`.
 * Uses merge writes so re-imports update without losing curator additions.
 */

import { getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { FkbFood, buildSearchTokens } from "./types";

const FKB_COLLECTION = "fkb_foods";

/**
 * Upsert a single FkbFood document into Firestore.
 * Automatically builds search_tokens from name + aliases.
 */
export async function upsertFkbFood(food: FkbFood): Promise<void> {
  const db = getFirestore();
  const docRef = db.collection(FKB_COLLECTION).doc(food.food_id);

  const dataWithTokens: FkbFood = {
    ...food,
    search_tokens: buildSearchTokens(food),
  };

  await docRef.set(dataWithTokens, { merge: true });
}

/**
 * Upsert a batch of FkbFood documents.
 * Firestore batch limit is 500 writes; this function handles chunking.
 *
 * @returns Number of documents written.
 */
export async function upsertBatch(foods: FkbFood[]): Promise<number> {
  const db = getFirestore();
  const BATCH_SIZE = 450; // Leave some margin under 500 limit
  let written = 0;

  for (let i = 0; i < foods.length; i += BATCH_SIZE) {
    const chunk = foods.slice(i, i + BATCH_SIZE);
    const batch = db.batch();

    for (const food of chunk) {
      const docRef = db.collection(FKB_COLLECTION).doc(food.food_id);
      const dataWithTokens: FkbFood = {
        ...food,
        search_tokens: buildSearchTokens(food),
      };
      batch.set(docRef, dataWithTokens, { merge: true });
    }

    await batch.commit();
    written += chunk.length;
    logger.info(`FKB upsert batch: wrote ${written}/${foods.length}`);
  }

  return written;
}

/**
 * Get the total count of documents in the fkb_foods collection.
 * Uses a count aggregation query (Firestore v2).
 */
export async function getFkbCount(): Promise<number> {
  const db = getFirestore();
  const snapshot = await db.collection(FKB_COLLECTION).count().get();
  return snapshot.data().count;
}
