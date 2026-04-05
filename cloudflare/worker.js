/**
 * AiBlojka — Cloudflare Worker
 *
 * Proxy between the Flutter Web PWA (GitHub Pages) and the Gemini 2.5 Flash
 * Image API. Holds the GEMINI_API_KEY secret so it is never exposed to the
 * client.
 *
 * Environment variables (set in Cloudflare Dashboard → Workers → Settings →
 * Variables and Secrets):
 *   GEMINI_API_KEY  — encrypted secret, Gemini API key
 *
 * Allowed origins:
 *   https://yngq.github.io   — production (GitHub Pages)
 *   http://localhost:*        — any local dev port
 */

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const GEMINI_ENDPOINT =
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-preview-image-generation:generateContent";

/** Production GitHub Pages origin for this project. */
const PRODUCTION_ORIGIN = "https://yngq.github.io";

/** Maximum allowed request body size: 12 MB (10 MB image + JSON overhead). */
const MAX_BODY_BYTES = 12 * 1024 * 1024;

/** Maximum prompt length in characters. */
const MAX_PROMPT_LENGTH = 2000;

// Retry config for transient Gemini errors (429, 503).
const RETRY_ATTEMPTS = 3;
const RETRY_BASE_DELAY_MS = 1000;

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

export default {
  /**
   * Main fetch handler.
   *
   * @param {Request} request
   * @param {{ GEMINI_API_KEY: string }} env
   * @param {ExecutionContext} ctx
   * @returns {Promise<Response>}
   */
  async fetch(request, env, ctx) {
    // Handle CORS preflight.
    if (request.method === "OPTIONS") {
      return handlePreflight(request);
    }

    // Only POST is accepted for the generation endpoint.
    if (request.method !== "POST") {
      return errorResponse(405, "METHOD_NOT_ALLOWED", "Only POST is accepted.");
    }

    // Origin validation — the trust boundary.
    const origin = request.headers.get("Origin") ?? "";
    if (!isAllowedOrigin(origin)) {
      return errorResponse(
        403,
        "FORBIDDEN_ORIGIN",
        "Requests from this origin are not allowed."
      );
    }

    // Guard: API key must be configured.
    if (!env.GEMINI_API_KEY) {
      console.error("GEMINI_API_KEY secret is not configured.");
      return errorResponse(
        500,
        "CONFIGURATION_ERROR",
        "Server configuration error."
      );
    }

    // Parse and validate the incoming request body.
    let body;
    try {
      body = await parseAndValidateBody(request);
    } catch (err) {
      return errorResponse(400, "INVALID_REQUEST", err.message);
    }

    // Forward to Gemini with retry logic.
    let geminiResponse;
    try {
      geminiResponse = await callGeminiWithRetry(body, env.GEMINI_API_KEY);
    } catch (err) {
      console.error("Gemini call failed after retries:", err.message);
      return errorResponse(502, "UPSTREAM_ERROR", "Failed to reach Gemini API.");
    }

    // Map Gemini response to the client contract.
    return buildClientResponse(geminiResponse, origin);
  },
};

// ---------------------------------------------------------------------------
// Origin validation
// ---------------------------------------------------------------------------

/**
 * Returns true if the origin is allowed to call this Worker.
 *
 * @param {string} origin
 * @returns {boolean}
 */
function isAllowedOrigin(origin) {
  if (origin === PRODUCTION_ORIGIN) return true;
  // Allow any localhost port for local Flutter development.
  if (origin.startsWith("http://localhost:")) return true;
  // Also allow bare localhost without a port (rare but valid).
  if (origin === "http://localhost") return true;
  return false;
}

// ---------------------------------------------------------------------------
// CORS
// ---------------------------------------------------------------------------

/**
 * Builds the CORS headers for a given (allowed) origin.
 *
 * @param {string} origin
 * @returns {Record<string, string>}
 */
function corsHeaders(origin) {
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Max-Age": "86400",
  };
}

/**
 * Responds to CORS preflight requests.
 *
 * @param {Request} request
 * @returns {Response}
 */
function handlePreflight(request) {
  const origin = request.headers.get("Origin") ?? "";
  if (!isAllowedOrigin(origin)) {
    return new Response(null, { status: 403 });
  }
  return new Response(null, {
    status: 204,
    headers: corsHeaders(origin),
  });
}

// ---------------------------------------------------------------------------
// Request parsing & validation
// ---------------------------------------------------------------------------

/** Allowed MIME types for reference images. */
const ALLOWED_REFERENCE_MIME_TYPES = ["image/jpeg", "image/png", "image/webp"];

/**
 * Parses the request body JSON and validates required fields.
 *
 * @param {Request} request
 * @returns {Promise<{ prompt: string, format: string, referenceImageBase64?: string, referenceMimeType?: string }>}
 * @throws {Error} on validation failure
 */
async function parseAndValidateBody(request) {
  const contentType = request.headers.get("Content-Type") ?? "";
  if (!contentType.includes("application/json")) {
    throw new Error("Content-Type must be application/json.");
  }

  // Enforce body size limit before reading.
  const contentLength = parseInt(
    request.headers.get("Content-Length") ?? "0",
    10
  );
  if (contentLength > MAX_BODY_BYTES) {
    throw new Error(
      `Request body too large. Maximum allowed size is ${MAX_BODY_BYTES / (1024 * 1024)} MB.`
    );
  }

  let rawBody;
  try {
    // Clone so we can read; also check actual byte length.
    const arrayBuffer = await request.arrayBuffer();
    if (arrayBuffer.byteLength > MAX_BODY_BYTES) {
      throw new Error(
        `Request body too large. Maximum allowed size is ${MAX_BODY_BYTES / (1024 * 1024)} MB.`
      );
    }
    rawBody = new TextDecoder().decode(arrayBuffer);
  } catch (err) {
    throw new Error("Failed to read request body: " + err.message);
  }

  let parsed;
  try {
    parsed = JSON.parse(rawBody);
  } catch {
    throw new Error("Request body is not valid JSON.");
  }

  const { prompt, format, referenceImageBase64, referenceMimeType } = parsed;

  // --- prompt ---
  if (typeof prompt !== "string" || prompt.trim().length === 0) {
    throw new Error('Field "prompt" is required and must be a non-empty string.');
  }
  if (prompt.length > MAX_PROMPT_LENGTH) {
    throw new Error(
      `Field "prompt" exceeds the maximum length of ${MAX_PROMPT_LENGTH} characters.`
    );
  }

  // --- format ---
  if (format !== "long" && format !== "short") {
    throw new Error('Field "format" must be "long" or "short".');
  }

  // --- referenceImageBase64 (optional) ---
  const hasReference =
    typeof referenceImageBase64 === "string" && referenceImageBase64.length > 0;

  if (hasReference) {
    if (referenceImageBase64.startsWith("data:")) {
      throw new Error(
        'Field "referenceImageBase64" must not include the data URI prefix (e.g. "data:image/...;base64,"). Send only the raw base64 string.'
      );
    }

    // --- referenceMimeType (required when referenceImageBase64 is present) ---
    if (typeof referenceMimeType !== "string" || referenceMimeType.length === 0) {
      throw new Error(
        'Field "referenceMimeType" is required when "referenceImageBase64" is provided.'
      );
    }
    if (!ALLOWED_REFERENCE_MIME_TYPES.includes(referenceMimeType)) {
      throw new Error(
        `Field "referenceMimeType" must be one of: ${ALLOWED_REFERENCE_MIME_TYPES.join(", ")}.`
      );
    }
  }

  return {
    prompt: prompt.trim(),
    format,
    referenceImageBase64: hasReference ? referenceImageBase64 : undefined,
    referenceMimeType: hasReference ? referenceMimeType : undefined,
  };
}

// ---------------------------------------------------------------------------
// Gemini API call
// ---------------------------------------------------------------------------

/**
 * Builds the Gemini generateContent request body from validated client input.
 *
 * @param {{ prompt: string, format: string, referenceImageBase64?: string, referenceMimeType?: string }} input
 * @returns {object}
 */
function buildGeminiRequestBody(input) {
  const { prompt, format, referenceImageBase64, referenceMimeType } = input;

  // Assemble the text prompt (all Gemini prompts are in English).
  const formatInstruction =
    format === "long"
      ? "Create a horizontal YouTube video thumbnail at 1920x1080 resolution (16:9 aspect ratio)."
      : "Create a vertical video cover at 1080x1920 resolution (9:16 aspect ratio), suitable for TikTok, YouTube Shorts, and Instagram Reels.";

  const fullPrompt =
    `You are an expert video thumbnail and cover designer. Generate a high-quality, visually striking image for a video cover. ` +
    `${formatInstruction} ` +
    `Design requirements: ${prompt}. ` +
    `Technical requirements: high resolution, no compression artifacts, clean composition, professional quality. ` +
    `Do not add any watermarks, logos, or unintended text overlays unless explicitly requested.`;

  /** @type {Array<object>} */
  const parts = [{ text: fullPrompt }];

  // Include reference image if provided.
  if (referenceImageBase64 && referenceMimeType) {
    parts.push({
      inlineData: {
        mimeType: referenceMimeType,
        data: referenceImageBase64,
      },
    });
  }

  return {
    contents: [{ parts }],
    generationConfig: {
      responseModalities: ["IMAGE", "TEXT"],
    },
  };
}

/**
 * Calls the Gemini API with exponential backoff on 429 and 503 responses.
 *
 * @param {{ prompt: string, format: string, referenceImageBase64?: string }} input
 * @param {string} apiKey
 * @returns {Promise<Response>}
 * @throws {Error} after all retry attempts are exhausted
 */
async function callGeminiWithRetry(input, apiKey) {
  // Use the x-goog-api-key header so the key is not logged in Cloudflare
  // request logs (query params are included in the URL log; headers are not).
  const geminiBody = buildGeminiRequestBody(input);

  let lastError = null;

  for (let attempt = 0; attempt < RETRY_ATTEMPTS; attempt++) {
    if (attempt > 0) {
      // Exponential backoff: delays are 1s, 2s for attempts 2 and 3.
      const delay = RETRY_BASE_DELAY_MS * Math.pow(2, attempt - 1);
      await sleep(delay);
    }

    let response;
    try {
      response = await fetch(GEMINI_ENDPOINT, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": apiKey,
        },
        body: JSON.stringify(geminiBody),
      });
    } catch (networkErr) {
      // Network-level failure — retry.
      lastError = networkErr;
      console.warn(`Gemini network error on attempt ${attempt + 1}:`, networkErr.message);
      continue;
    }

    // Retry on 503 (Gemini overloaded) and 429 (per-minute rate limit — not
    // the daily quota, which won't recover in seconds regardless of retries).
    if (response.status === 429 || response.status === 503) {
      lastError = new Error(`Gemini returned ${response.status}`);
      console.warn(
        `Gemini transient error ${response.status} on attempt ${attempt + 1}; will retry.`
      );
      continue;
    }

    // Any other status (200, 400, 500, etc.) — return immediately.
    return response;
  }

  throw lastError ?? new Error("Gemini call failed after all retry attempts.");
}

// ---------------------------------------------------------------------------
// Response mapping
// ---------------------------------------------------------------------------

/**
 * Parses the Gemini response and maps it to the client contract.
 *
 * Success response to Flutter:
 *   { "imageBase64": "...", "mimeType": "image/png" }
 *
 * Error response to Flutter:
 *   { "error": { "code": "...", "message": "..." } }
 *
 * @param {Response} geminiResponse
 * @param {string} origin  — used to attach CORS headers
 * @returns {Promise<Response>}
 */
async function buildClientResponse(geminiResponse, origin) {
  const headers = {
    "Content-Type": "application/json",
    ...corsHeaders(origin),
  };

  // --- Handle Gemini-level errors ---
  if (!geminiResponse.ok) {
    let geminiError;
    try {
      geminiError = await geminiResponse.json();
    } catch {
      geminiError = null;
    }

    const status = geminiResponse.status;
    console.error(`Gemini error ${status}:`, JSON.stringify(geminiError));

    // 429 — quota exhausted; pass through as-is.
    if (status === 429) {
      return new Response(
        JSON.stringify({
          error: {
            code: "QUOTA_EXCEEDED",
            message:
              "Daily generation limit reached. Please try again tomorrow.",
          },
        }),
        { status: 429, headers }
      );
    }

    // 400 with a safety block → 451 (Unavailable For Legal Reasons is a
    // reasonable semantic fit for content-policy blocks).
    // Note: INVALID_ARGUMENT is intentionally excluded — it covers many non-safety
    // errors (bad inlineData, invalid fields, etc.). We only match on explicit
    // "safety" language in the error message.
    if (status === 400) {
      const isSafetyBlock =
        geminiError?.error?.message?.toLowerCase().includes("safety");

      if (isSafetyBlock) {
        return new Response(
          JSON.stringify({
            error: {
              code: "SAFETY_BLOCK",
              message:
                "The request was blocked by the content safety filter. Please modify your description and try again.",
            },
          }),
          { status: 451, headers }
        );
      }

      return new Response(
        JSON.stringify({
          error: {
            code: "BAD_REQUEST",
            message: "The request was rejected by the AI model.",
          },
        }),
        { status: 400, headers }
      );
    }

    // 5xx and anything else.
    return new Response(
      JSON.stringify({
        error: {
          code: "UPSTREAM_ERROR",
          message: "The AI service returned an error. Please try again later.",
        },
      }),
      { status: 502, headers }
    );
  }

  // --- Parse successful Gemini response ---
  let geminiData;
  try {
    geminiData = await geminiResponse.json();
  } catch {
    console.error("Failed to parse Gemini success response as JSON.");
    return new Response(
      JSON.stringify({
        error: {
          code: "PARSE_ERROR",
          message: "Unexpected response from AI service.",
        },
      }),
      { status: 502, headers }
    );
  }

  // Check for a safety block signalled via finishReason (200 OK response).
  // Gemini most commonly signals safety blocks this way rather than via a 400.
  const candidate = geminiData?.candidates?.[0];
  if (candidate?.finishReason === "SAFETY") {
    console.error("Gemini safety block (finishReason=SAFETY):", JSON.stringify(candidate.safetyRatings));
    return new Response(
      JSON.stringify({
        error: {
          code: "SAFETY_BLOCK",
          message:
            "The request was blocked by the content safety filter. Please modify your description and try again.",
        },
      }),
      { status: 451, headers }
    );
  }

  // Locate the image part in the response.
  const parts = candidate?.content?.parts ?? [];
  const imagePart = parts.find(
    (part) => part.inlineData && part.inlineData.mimeType?.startsWith("image/")
  );

  if (!imagePart) {
    // Gemini returned a text-only response or an empty candidate — this can
    // happen when the model soft-refuses without triggering a formal safety block.
    console.error(
      "Gemini response contained no image part. finishReason:",
      candidate?.finishReason,
      "Parts:",
      JSON.stringify(parts)
    );
    return new Response(
      JSON.stringify({
        error: {
          code: "NO_IMAGE_GENERATED",
          message:
            "The AI model did not generate an image. Please modify your description and try again.",
        },
      }),
      { status: 422, headers }
    );
  }

  return new Response(
    JSON.stringify({
      imageBase64: imagePart.inlineData.data,
      mimeType: imagePart.inlineData.mimeType,
    }),
    { status: 200, headers }
  );
}

// ---------------------------------------------------------------------------
// Error helpers
// ---------------------------------------------------------------------------

/**
 * Creates a structured JSON error response.
 *
 * @param {number} status
 * @param {string} code
 * @param {string} message
 * @returns {Response}
 */
function errorResponse(status, code, message) {
  return new Response(
    JSON.stringify({ error: { code, message } }),
    {
      status,
      headers: { "Content-Type": "application/json" },
    }
  );
}

// ---------------------------------------------------------------------------
// Utilities
// ---------------------------------------------------------------------------

/**
 * Returns a promise that resolves after `ms` milliseconds.
 *
 * @param {number} ms
 * @returns {Promise<void>}
 */
function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
