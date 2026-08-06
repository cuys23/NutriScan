const API_KEY = "AIzaSyDyJZZEkmWI8lndY-ssMdvsZCiXlZ0JvJc";
const EMAIL = "eval_test@nutriscan.com";
const PASSWORD = process.env.EVAL_TEST_PASSWORD;
if (!PASSWORD) {
  throw new Error(
    "EVAL_TEST_PASSWORD env var not set — export the eval_test@nutriscan.com password before running this script."
  );
}

export async function getEvalIdToken() {
  const res = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${API_KEY}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        email: EMAIL,
        password: PASSWORD,
        returnSecureToken: true,
      }),
    }
  );

  const data = await res.json();
  if (!data.idToken) {
    throw new Error(
      `Failed to get EVAL_ID_TOKEN: ${JSON.stringify(data.error ?? data)}`
    );
  }
  return data.idToken;
}

if (process.argv[1]?.endsWith("get_eval_token.mjs")) {
  getEvalIdToken()
    .then((token) => {
      console.log(token);
    })
    .catch((err) => {
      console.error(err);
      process.exit(1);
    });
}
