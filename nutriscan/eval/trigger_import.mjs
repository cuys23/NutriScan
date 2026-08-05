/**
 * Trigger FKB import jobs via Firebase callable functions.
 * Run: node eval/trigger_import.mjs
 *
 * Requires: firebase-admin SDK (already in functions/node_modules)
 */

import { initializeApp, cert } from "firebase-admin/app";
import { getFunctions, httpsCallable } from "firebase-admin/functions"; // Not available in admin SDK for callables

// For callable functions, we use the Firebase client SDK approach via HTTP
const PROJECT_ID = "nutriscan-75d57";
const REGION = "us-central1";

async function callFunction(name, data = {}) {
  // Use the REST endpoint for callable functions
  // We need an auth token - get it from gcloud
  const { execSync } = await import("child_process");

  let token;
  try {
    token = execSync("gcloud auth print-identity-token", { encoding: "utf8" }).trim();
  } catch {
    // Try application default credentials
    token = execSync("gcloud auth print-access-token", { encoding: "utf8" }).trim();
  }

  const url = `https://${REGION}-${PROJECT_ID}.cloudfunctions.net/${name}`;
  console.log(`Calling ${url}...`);

  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${token}`,
    },
    body: JSON.stringify({ data }),
  });

  const result = await response.json();
  if (!response.ok) {
    console.error(`Error ${response.status}:`, JSON.stringify(result, null, 2));
    return null;
  }

  return result;
}

async function main() {
  console.log("=== FKB Import Trigger ===\n");

  // 1. Import Vietnamese foods first (fast, no API calls needed)
  console.log("1. Importing Vietnamese foods (VN FCT)...");
  const vnResult = await callFunction("importVnFct");
  if (vnResult) {
    console.log("VN FCT result:", JSON.stringify(vnResult, null, 2));
  }

  console.log("");

  // 2. Import USDA seed foods (slower, calls USDA API)
  console.log("2. Importing USDA seed foods...");
  console.log("   (This may take 30-60 seconds...)");
  const usdaResult = await callFunction("importUsdaSeed");
  if (usdaResult) {
    console.log("USDA result:", JSON.stringify(usdaResult, null, 2));
  }

  console.log("\n=== Import complete ===");
}

main().catch(console.error);
