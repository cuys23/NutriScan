/**
 * USDA seed import job — fetches foods from the USDA FDC API and upserts
 * them into the `fkb_foods` Firestore collection.
 *
 * Callable as `importUsdaSeed` — requires authenticated user.
 * In production, restrict to admin UIDs or use a custom claim.
 *
 * Flow:
 *   1. Read seed list (hardcoded common foods)
 *   2. Fetch each from USDA FDC API in batches of 20
 *   3. Map nutrients → NutrientsPer100g
 *   4. Upsert to Firestore as FkbFood
 */

import { logger } from "firebase-functions";
import { getFood, getFoodsBatch, FdcFoodDetail } from "../usda/client";
import { mapUsdaDetailNutrients } from "../usda/mapNutrients";
import { FkbFood } from "../fkb/types";
import { upsertBatch, getFkbCount } from "../fkb/upsert";

/**
 * Hardcoded seed list of common food FDC IDs.
 * These are Foundation / SR Legacy entries — authoritative per-100g data.
 */
const SEED_FOODS: Array<{ fdcId: number; hint: string; nameVi?: string }> = [
  // ── Fruits ──
  { fdcId: 173944, hint: "Banana, raw", nameVi: "Chuối" },
  { fdcId: 171688, hint: "Apple, raw, with skin", nameVi: "Táo" },
  { fdcId: 167762, hint: "Orange, raw", nameVi: "Cam" },
  { fdcId: 167775, hint: "Grapes, red or green", nameVi: "Nho" },
  { fdcId: 170393, hint: "Mango, raw", nameVi: "Xoài" },
  { fdcId: 167764, hint: "Papaya, raw", nameVi: "Đu đủ" },
  { fdcId: 171890, hint: "Watermelon, raw", nameVi: "Dưa hấu" },
  { fdcId: 173945, hint: "Pineapple, raw", nameVi: "Dứa" },
  { fdcId: 174687, hint: "Strawberries, raw", nameVi: "Dâu tây" },
  { fdcId: 171711, hint: "Avocado, raw", nameVi: "Bơ" },
  { fdcId: 167748, hint: "Lemon, raw", nameVi: "Chanh vàng" },
  { fdcId: 174683, hint: "Blueberries, raw", nameVi: "Việt quất" },

  // ── Grains ──
  { fdcId: 170457, hint: "Rice, white, long-grain, cooked", nameVi: "Cơm trắng" },
  { fdcId: 169714, hint: "Rice, brown, long-grain, cooked", nameVi: "Cơm gạo lứt" },
  { fdcId: 168878, hint: "Bread, white", nameVi: "Bánh mì trắng" },
  { fdcId: 168873, hint: "Bread, whole-wheat", nameVi: "Bánh mì lúa mạch" },
  { fdcId: 168871, hint: "Noodles, egg, cooked", nameVi: "Mì trứng" },
  { fdcId: 170069, hint: "Oats, regular, cooked", nameVi: "Yến mạch" },
  { fdcId: 168880, hint: "Pasta, cooked", nameVi: "Mì Ý" },
  { fdcId: 170285, hint: "Corn, sweet, cooked", nameVi: "Bắp ngọt" },
  { fdcId: 172451, hint: "Wheat flour, all-purpose", nameVi: "Bột mì" },

  // ── Proteins ──
  { fdcId: 171057, hint: "Chicken breast, roasted", nameVi: "Ức gà nướng" },
  { fdcId: 174002, hint: "Chicken thigh, roasted", nameVi: "Đùi gà nướng" },
  { fdcId: 174032, hint: "Beef, ground, 80% lean, cooked", nameVi: "Thịt bò xay" },
  { fdcId: 175167, hint: "Pork, loin, cooked", nameVi: "Thịt heo thăn" },
  { fdcId: 175139, hint: "Salmon, Atlantic, cooked", nameVi: "Cá hồi" },
  { fdcId: 175159, hint: "Shrimp, cooked", nameVi: "Tôm" },
  { fdcId: 171287, hint: "Egg, whole, hard-boiled", nameVi: "Trứng luộc" },
  { fdcId: 172184, hint: "Tofu, firm", nameVi: "Đậu phụ" },
  { fdcId: 174288, hint: "Tuna, canned in water", nameVi: "Cá ngừ đóng hộp" },
  { fdcId: 173417, hint: "Turkey breast, cooked", nameVi: "Ức gà tây" },
  { fdcId: 175108, hint: "Tilapia, cooked", nameVi: "Cá rô phi" },
  { fdcId: 174230, hint: "Bacon, cooked", nameVi: "Thịt xông khói" },

  // ── Dairy ──
  { fdcId: 170903, hint: "Milk, whole", nameVi: "Sữa nguyên kem" },
  { fdcId: 170906, hint: "Milk, 2% fat", nameVi: "Sữa ít béo" },
  { fdcId: 170886, hint: "Cheese, cheddar", nameVi: "Phô mai cheddar" },
  { fdcId: 170899, hint: "Yogurt, plain, whole milk", nameVi: "Sữa chua" },
  { fdcId: 170855, hint: "Butter, salted", nameVi: "Bơ mặn" },

  // ── Vegetables ──
  { fdcId: 170407, hint: "Potato, boiled", nameVi: "Khoai tây luộc" },
  { fdcId: 169228, hint: "Broccoli, cooked", nameVi: "Bông cải xanh" },
  { fdcId: 170440, hint: "Spinach, raw", nameVi: "Rau chân vịt" },
  { fdcId: 169230, hint: "Carrot, raw", nameVi: "Cà rốt" },
  { fdcId: 170050, hint: "Tomato, red, raw", nameVi: "Cà chua" },
  { fdcId: 169986, hint: "Onion, raw", nameVi: "Hành tây" },
  { fdcId: 169251, hint: "Cucumber, raw", nameVi: "Dưa chuột" },
  { fdcId: 170417, hint: "Bell pepper, green", nameVi: "Ớt chuông xanh" },
  { fdcId: 169985, hint: "Garlic, raw", nameVi: "Tỏi" },
  { fdcId: 169226, hint: "Cabbage, raw", nameVi: "Bắp cải" },
  { fdcId: 170471, hint: "Mushroom, white, raw", nameVi: "Nấm" },
  { fdcId: 170399, hint: "Peas, green, cooked", nameVi: "Đậu Hà Lan" },
  { fdcId: 170464, hint: "Cauliflower, cooked", nameVi: "Súp lơ trắng" },

  // ── Nuts & Seeds ──
  { fdcId: 170567, hint: "Peanut butter", nameVi: "Bơ đậu phộng" },
  { fdcId: 170178, hint: "Almonds, raw", nameVi: "Hạnh nhân" },
  { fdcId: 170187, hint: "Cashew nuts", nameVi: "Hạt điều" },

  // ── Oils ──
  { fdcId: 174833, hint: "Olive oil", nameVi: "Dầu ô liu" },
  { fdcId: 171028, hint: "Coconut oil", nameVi: "Dầu dừa" },

  // ── Eggs ──
  { fdcId: 171285, hint: "Egg, whole, raw", nameVi: "Trứng gà sống" },

  // ── Sweeteners ──
  { fdcId: 174608, hint: "Honey", nameVi: "Mật ong" },
  { fdcId: 169655, hint: "Sugar, white", nameVi: "Đường trắng" },

  // ── Legumes ──
  { fdcId: 173530, hint: "Beans, black, cooked", nameVi: "Đậu đen" },
  { fdcId: 175198, hint: "Lentils, cooked", nameVi: "Đậu lăng" },
  { fdcId: 172421, hint: "Soybeans, cooked", nameVi: "Đậu nành" },

  // ── Beverages ──
  { fdcId: 174832, hint: "Coffee, brewed", nameVi: "Cà phê" },
  { fdcId: 171917, hint: "Tea, brewed", nameVi: "Trà" },

  // ── Condiments ──
  { fdcId: 170474, hint: "Soy sauce", nameVi: "Nước tương" },
  { fdcId: 169409, hint: "Salt, table", nameVi: "Muối" },

  // ── Desserts & Prepared ──
  { fdcId: 173959, hint: "Ice cream, vanilla", nameVi: "Kem vani" },
  { fdcId: 167587, hint: "Chocolate, dark", nameVi: "Sô cô la đen" },
];

/**
 * Convert a USDA FDC detail response into an FkbFood object.
 */
function fdcToFkbFood(
  detail: FdcFoodDetail,
  seed?: { hint: string; nameVi?: string }
): FkbFood {
  const nutrients = mapUsdaDetailNutrients(detail.foodNutrients ?? []);

  const nameEn = detail.description || seed?.hint || "Unknown";
  const nameVi = seed?.nameVi || nameEn;

  // Build aliases from the hint (often more readable than USDA description)
  const aliases: string[] = [];
  if (seed?.hint && seed.hint.toLowerCase() !== nameEn.toLowerCase()) {
    aliases.push(seed.hint.toLowerCase());
  }
  if (seed?.nameVi) {
    aliases.push(seed.nameVi.toLowerCase());
  }

  return {
    food_id: `usda_${detail.fdcId}`,
    name_en: nameEn,
    name_vi: nameVi,
    aliases,
    nutrients_per_100g: nutrients,
    source: "usda",
    source_ref: String(detail.fdcId),
    data_type: detail.dataType,
    verified_at: new Date().toISOString(),
    verified_by: "import_usda_v1",
  };
}

/**
 * Run the USDA seed import.
 *
 * Fetches foods in batches of 20 from USDA, maps to FkbFood,
 * and upserts to Firestore.
 *
 * @param apiKey  USDA FDC API key (from Secret Manager)
 * @returns Summary of import results
 */
export async function runUsdaSeedImport(apiKey: string): Promise<{
  requested: number;
  fetched: number;
  written: number;
  errors: string[];
}> {
  const errors: string[] = [];
  const allFoods: FkbFood[] = [];

  // Build lookup map for seed metadata
  const seedMap = new Map(SEED_FOODS.map((s) => [s.fdcId, s]));

  // Deduplicate FDC IDs
  const uniqueIds = [...new Set(SEED_FOODS.map((s) => s.fdcId))];

  logger.info(`Starting USDA seed import: ${uniqueIds.length} unique foods`);

  // Fetch in batches of 20 (USDA batch limit)
  for (let i = 0; i < uniqueIds.length; i += 20) {
    const batchIds = uniqueIds.slice(i, i + 20);

    try {
      const details = await getFoodsBatch(batchIds, apiKey);

      for (const detail of details) {
        try {
          const seed = seedMap.get(detail.fdcId);
          const fkbFood = fdcToFkbFood(detail, seed);

          // Sanity check: calories should be present
          if (fkbFood.nutrients_per_100g.calories_kcal === 0) {
            logger.warn(`Zero calories for ${fkbFood.food_id} (${fkbFood.name_en})`);
          }

          allFoods.push(fkbFood);
        } catch (err) {
          const msg = `Failed to map fdcId=${detail.fdcId}: ${err}`;
          logger.error(msg);
          errors.push(msg);
        }
      }
    } catch (err) {
      // If batch fails, try individual fetches as fallback
      logger.warn(`Batch fetch failed for ids ${batchIds.join(",")}, trying individually`);
      for (const fdcId of batchIds) {
        try {
          const detail = await getFood(fdcId, apiKey);
          const seed = seedMap.get(fdcId);
          allFoods.push(fdcToFkbFood(detail, seed));
        } catch (innerErr) {
          const msg = `Failed to fetch fdcId=${fdcId}: ${innerErr}`;
          logger.error(msg);
          errors.push(msg);
        }
      }
    }

    // Small delay between batches to respect rate limits
    if (i + 20 < uniqueIds.length) {
      await new Promise((r) => setTimeout(r, 200));
    }
  }

  // Upsert all collected foods to Firestore
  let written = 0;
  if (allFoods.length > 0) {
    written = await upsertBatch(allFoods);
  }

  const countAfter = await getFkbCount();
  logger.info(
    `USDA seed import complete: requested=${uniqueIds.length}, fetched=${allFoods.length}, written=${written}, totalFkb=${countAfter}, errors=${errors.length}`
  );

  return {
    requested: uniqueIds.length,
    fetched: allFoods.length,
    written,
    errors,
  };
}
