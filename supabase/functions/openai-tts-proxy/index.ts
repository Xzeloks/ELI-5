import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";

console.log("OpenAI TTS Proxy function script started.");

serve(async (req: Request) => {
  console.log("OpenAI TTS Proxy function invoked.");

  // Handle preflight OPTIONS request for CORS
  if (req.method === "OPTIONS") {
    console.log("Handling OPTIONS request");
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { input: textToSynthesize, model = "tts-1", voice = "alloy" } = await req.json();
    console.log(`Received TTS request for text: "${textToSynthesize}", model: ${model}, voice: ${voice}`);

    const openaiApiKey = Deno.env.get("OPENAI_API_KEY");
    if (!openaiApiKey) {
      console.error("OPENAI_API_KEY is not set in environment variables.");
      return new Response(
        JSON.stringify({ error: "OpenAI API key not configured." }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 500,
        }
      );
    }

    const openaiTtsUrl = "https://api.openai.com/v1/audio/speech";

    console.log(`Sending request to OpenAI TTS API: ${openaiTtsUrl}`);
    const response = await fetch(openaiTtsUrl, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${openaiApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: model,
        input: textToSynthesize,
        voice: voice,
        response_format: "mp3", // Can also use opus, aac, flac
      }),
    });

    console.log(`OpenAI API response status: ${response.status}`);

    if (!response.ok) {
      const errorBody = await response.text();
      console.error("OpenAI API Error:", errorBody);
      return new Response(
        JSON.stringify({
          error: "Failed to generate speech from OpenAI.",
          details: errorBody,
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: response.status,
        }
      );
    }

    // Stream the audio data back to the client
    // The 'Content-Type' will be 'audio/mpeg' for mp3
    const responseHeaders = {
      ...corsHeaders,
      "Content-Type": response.headers.get("Content-Type") || "audio/mpeg",
      "Content-Disposition": 'attachment; filename="speech.mp3"', // Optional: suggests a filename to the client
    };
    
    console.log("Successfully generated speech. Streaming audio data.");
    return new Response(response.body, {
      headers: responseHeaders,
      status: 200,
    });

  } catch (error) {
    console.error("Error in TTS Edge Function:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      }
    );
  }
});

console.log("OpenAI TTS Proxy function script finished loading."); 