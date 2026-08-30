import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function distance(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number,
) {
  const R = 6371;

  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) *
      Math.cos(lat2 * Math.PI / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);

  return R * 2 * Math.atan2(
    Math.sqrt(a),
    Math.sqrt(1 - a),
  );
}

serve(async (req) => {
  // ============================================================
  // CORS
  // ============================================================

  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders,
    });
  }

  try {
    // ==========================================================
    // REQUEST DATA
    // ==========================================================

    const {
      message,
      history,
      lat,
      lng,
      language = "en",
    } = await req.json();

    console.log("CHAT REQUEST:", {
      language,
      lat,
      lng,
    });

    // ==========================================================
    // SUPABASE CLIENT
    // ==========================================================

    const projectUrl = Deno.env.get("PROJECT_URL");
    const serviceRoleKey =
      Deno.env.get("SERVICE_ROLE_KEY");

    if (!projectUrl || !serviceRoleKey) {
      console.error(
        "Missing Supabase environment variables",
      );

      return new Response(
        JSON.stringify({
          reply:
            "Server configuration error. Please try again later.",
        }),
        {
          status: 500,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        },
      );
    }

    const supabase = createClient(
      projectUrl,
      serviceRoleKey,
    );

    // ==========================================================
    // FETCH REPORTS
    // ==========================================================

    const { data: allReports, error: reportsError } =
      await supabase
        .from("reports")
        .select("*")
        .limit(50);

    if (reportsError) {
      console.error(
        "REPORT FETCH ERROR:",
        reportsError,
      );
    }

    const RADIUS_KM = 50;

    // ==========================================================
    // FILTER NEARBY REPORTS
    // ==========================================================

    let nearbyReports: any[] = [];

    if (lat != null && lng != null) {
      nearbyReports = (allReports || []).filter(
        (r) => {
          if (
            r.lat == null ||
            r.lng == null
          ) {
            return false;
          }

          return (
            distance(
              Number(lat),
              Number(lng),
              Number(r.lat),
              Number(r.lng),
            ) <= RADIUS_KM
          );
        },
      );
    } else {
      nearbyReports = allReports || [];
    }

    // ==========================================================
    // LANGUAGE
    // ==========================================================

    const languageInstruction =
      language === "hi"
        ? `
Respond entirely in Hindi (हिन्दी).
Use simple, clear Hindi that is easy for a general user
to understand.
Do not answer in English unless a technical term has
no suitable Hindi equivalent.
`
        : `
Respond entirely in English.
Use simple, clear English that is easy for a general user
to understand.
`;

    // ==========================================================
    // PROMPT
    // ==========================================================

    const prompt = `
You are the AapdaSetu AI Disaster Assistant.

${languageInstruction}

Your purpose is to help users with disaster safety,
emergency situations, nearby incidents and practical
safety guidance.

User location:
Latitude: ${lat ?? "unknown"}
Longitude: ${lng ?? "unknown"}

Nearby incidents within ${RADIUS_KM} km:
${JSON.stringify(nearbyReports)}

Conversation history:
${JSON.stringify(history || [])}

User message:
${message}

Instructions:
- Answer the user's current question directly.
- Focus on safety and practical actions.
- Use nearby incidents when relevant.
- Mention distance when useful.
- Do not unnecessarily repeat the conversation history.
- Keep responses short and actionable.
- If the situation appears dangerous, prioritize immediate
  safety instructions.
- Always respond in the requested language.
`;

    console.log(
      "REQUESTED LANGUAGE:",
      language,
    );

    // ==========================================================
    // GEMINI KEY
    // ==========================================================

    const key = Deno.env.get("GEMINI_KEY_1");

    if (!key) {
      console.error(
        "GEMINI_KEY_1 is missing",
      );

      return new Response(
        JSON.stringify({
          reply:
            language === "hi"
              ? "AI सेवा अभी उपलब्ध नहीं है। कृपया बाद में प्रयास करें।"
              : "AI service is currently unavailable. Please try again later.",
        }),
        {
          status: 500,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        },
      );
    }

    // ==========================================================
    // GEMINI REQUEST
    // ==========================================================

    const geminiUrl =
      "https://generativelanguage.googleapis.com/" +
      "v1beta/models/gemini-2.5-flash:generateContent?key=" +
      key;

    const geminiResponse = await fetch(
      geminiUrl,
      {
        method: "POST",

        headers: {
          "Content-Type": "application/json",
        },

        body: JSON.stringify({
          contents: [
            {
              parts: [
                {
                  text: prompt,
                },
              ],
            },
          ],
        }),
      },
    );

    const json = await geminiResponse.json();

    console.log(
      "GEMINI STATUS:",
      geminiResponse.status,
    );

    console.log(
      "GEMINI RESPONSE:",
      JSON.stringify(json),
    );

    // ==========================================================
    // GEMINI ERROR
    // ==========================================================

    if (!geminiResponse.ok) {
      const errorMessage =
        json?.error?.message ||
        "Unknown Gemini error";

      console.error(
        "GEMINI ERROR:",
        errorMessage,
      );

      return new Response(
        JSON.stringify({
          reply:
            language === "hi"
              ? "AI से जवाब प्राप्त नहीं हो सका। कृपया फिर से प्रयास करें।"
              : "Could not get a response from AI. Please try again.",
        }),
        {
          status: 500,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        },
      );
    }

    // ==========================================================
    // EXTRACT RESPONSE
    // ==========================================================

    const reply =
      json?.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!reply) {
      console.error(
        "NO GEMINI RESPONSE TEXT",
      );

      return new Response(
        JSON.stringify({
          reply:
            language === "hi"
              ? "AI से कोई जवाब नहीं मिला। कृपया फिर से प्रयास करें।"
              : "No response received from AI. Please try again.",
        }),
        {
          status: 500,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        },
      );
    }

    // ==========================================================
    // SUCCESS
    // ==========================================================

    return new Response(
      JSON.stringify({
        reply,
      }),
      {
        status: 200,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      },
    );
  } catch (e) {
    console.error(
      "CHATBOT FUNCTION ERROR:",
      e,
    );

    return new Response(
      JSON.stringify({
        reply:
          "Unable to process your request. Please try again.",
      }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      },
    );
  }
});