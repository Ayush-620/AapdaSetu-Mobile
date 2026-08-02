import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "*",
};

// 🌍 Distance function (Haversine)
function distance(lat1: number, lon1: number, lat2: number, lon2: number) {
  const R = 6371;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) *
    Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) *
    Math.sin(dLon / 2);

  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

serve(async (req) => {

  // ✅ CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { message, history, lat, lng } = await req.json();

    const supabase = createClient(
      Deno.env.get("PROJECT_URL")!,
      Deno.env.get("SERVICE_ROLE_KEY")!
    );

    // 🔥 Fetch reports
    const { data: allReports } = await supabase
      .from("reports")
      .select("*")
      .limit(50);

    const RADIUS_KM = 50;

    // 🔥 Filter nearby reports
    let nearbyReports: any[] = [];

    if (lat && lng) {
      nearbyReports = (allReports || []).filter((r) => {
        if (!r.lat || !r.lng) return false;
        return distance(lat, lng, r.lat, r.lng) <= RADIUS_KM;
      });
    } else {
      nearbyReports = allReports || [];
    }

    // 🧠 Smart prompt
    const prompt = `
You are a disaster response AI assistant.

User location:
Lat: ${lat ?? "unknown"}, Lng: ${lng ?? "unknown"}

Nearby incidents (within ${RADIUS_KM} km):
${JSON.stringify(nearbyReports)}

Conversation history:
${JSON.stringify(history)}

User message:
${message}

Instructions:
- Focus on nearby dangers
- Mention distance if possible
- Give clear and practical safety steps
- Keep response short and actionable
`;

    const key = Deno.env.get("GEMINI_KEY_1");

    let reply = "AI unavailable";

    try {
      const res = await fetch(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=" + key,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            contents: [
              {
                parts: [{ text: prompt }],
              },
            ],
          }),
        }
      );

      const json = await res.json();

      console.log("GEMINI RESPONSE:", json);

      if (json.candidates && json.candidates.length > 0) {
        reply = json.candidates[0].content.parts[0].text;
      } else if (json.error) {
        reply = "Gemini Error: " + json.error.message;
      }

    } catch (e) {
      console.log("FETCH ERROR:", e);
      reply = "Network error contacting AI";
    }

    return new Response(JSON.stringify({ reply }), {
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
      },
    });

  } catch (e) {
    return new Response(JSON.stringify({ error: e.toString() }), {
      status: 500,
      headers: corsHeaders,
    });
  }
});