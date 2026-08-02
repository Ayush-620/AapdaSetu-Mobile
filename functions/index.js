/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {setGlobalOptions} = require("firebase-functions");
const {onRequest} = require("firebase-functions/https");
const logger = require("firebase-functions/logger");


const functions = require("firebase-functions");
const admin = require("firebase-admin");
const fetch = require("node-fetch");

admin.initializeApp();

const GEMINI_KEYS = [
  process.env.GEMINI_KEY_1,
  process.env.GEMINI_KEY_2,
  process.env.GEMINI_KEY_3,
  process.env.GEMINI_KEY_4,
];

function getRandomKey() {
  return GEMINI_KEYS[Math.floor(Math.random() * GEMINI_KEYS.length)];
}

exports.chatbot = functions.https.onCall(async (data, context) => {
  const userId = context.auth?.uid;
  const userMessage = data.message;
  const lat = data.lat;
  const lng = data.lng;

  // 🔥 Fetch nearby reports
  const snapshot = await admin.firestore()
    .collection("reports")
    .limit(5)
    .get();

  const reports = snapshot.docs.map(d => d.data());

  // 🧠 Build context
  const systemPrompt = `
You are a disaster assistant.

Nearby reports:
${JSON.stringify(reports)}

User message:
${userMessage}

Give helpful, safety-focused advice.
`;

  const apiKey = getRandomKey();

  const response = await fetch(
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=" + apiKey,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: systemPrompt }] }]
      }),
    }
  );

  const json = await response.json();

  return {
    reply: json.candidates?.[0]?.content?.parts?.[0]?.text || "No response"
  };
});

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({ maxInstances: 10 });

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
