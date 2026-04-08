/**
 * AiBlojka — Cloudflare Worker
 *
 * Proxy between Flutter Web (GitHub Pages) and Cloudflare Workers AI.
 * Generates image covers with an edge model and returns base64 payload
 * expected by the Flutter app.
 *
 * Required Worker binding:
 *   AI  — Workers AI binding (env.AI.run)
 *   Configure in Dashboard → Worker → Settings → Bindings → Add Workers AI
 *   → set variable name to "AI" → Save + Redeploy.
 *
 * Allowed origins:
 *   https://yngq.github.io   — production (GitHub Pages)
 *   http://localhost:*        — any local dev port
 */

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/** Cloudflare Workers AI model id (supports width/height and reference images). */
const WORKERS_AI_MODEL = "@cf/black-forest-labs/flux-2-klein-4b";

/** Output image dimensions per format (px). */
const FORMAT_DIMENSIONS = {
  long:  { width: 1024, height: 576 },  // 16:9 landscape
  short: { width: 576,  height: 1024 }, // 9:16 portrait
};

/** Production GitHub Pages origin for this project. */
const PRODUCTION_ORIGIN = "https://yngq.github.io";

/** Maximum allowed request body size: 12 MB (10 MB image + JSON overhead). */
const MAX_BODY_BYTES = 12 * 1024 * 1024;

/** Maximum prompt length in characters. */
const MAX_PROMPT_LENGTH = 2000;

/** Output MIME type returned by FLUX.2 Klein payload image string. */
const OUTPUT_MIME_TYPE = "image/png";

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

export default {
  /**
   * Main fetch handler.
   *
   * @param {Request} request
   * @param {{ AI?: { run: (model: string, input: unknown) => Promise<unknown> } }} env
   * @returns {Promise<Response>}
   */
  async fetch(request, env) {
    // Handle CORS preflight.
    if (request.method === "OPTIONS") {
      return handlePreflight(request);
    }

    // Origin validation — the trust boundary.
    // Parsed early so CORS headers can be attached to all subsequent error responses.
    const origin = request.headers.get("Origin") ?? "";
    if (!isAllowedOrigin(origin)) {
      return errorResponse(
        403,
        "FORBIDDEN_ORIGIN",
        "Requests from this origin are not allowed."
      );
    }

    // Only POST is accepted for the generation endpoint.
    if (request.method !== "POST") {
      return errorResponseWithCors(405, "METHOD_NOT_ALLOWED", "Only POST is accepted.", origin);
    }

    // Guard: Workers AI binding must be configured.
    // Fix: Dashboard → Worker → Settings → Bindings → Add Workers AI → variable name "AI".
    if (!env.AI || typeof env.AI.run !== "function") {
      console.error(
        "Workers AI binding (env.AI) is not configured or missing .run().",
        "Available env keys:", Object.keys(env).join(", ") || "(none)"
      );
      return errorResponseWithCors(
        500,
        "CONFIGURATION_ERROR",
        "Server configuration error.",
        origin
      );
    }

    // Parse and validate the incoming request body.
    let body;
    try {
      body = await parseAndValidateBody(request);
    } catch (err) {
      return errorResponseWithCors(400, "INVALID_REQUEST", err.message, origin);
    }

    let input;
    try {
      input = buildWorkersAiInput(body);
    } catch (err) {
      if (isInvalidReferenceEncodingError(err)) {
        return errorResponseWithCors(
          400,
          "INVALID_REQUEST",
          "Invalid reference image encoding.",
          origin
        );
      }

      console.error("Failed to build Workers AI request payload:", normalizeErrorMessage(err));
      return errorResponseWithCors(
        500,
        "INTERNAL_ERROR",
        "Server failed to prepare the AI request.",
        origin
      );
    }

    let aiResult;
    try {
      aiResult = await env.AI.run(WORKERS_AI_MODEL, input);
    } catch (err) {
      return mapWorkersAiError(err, origin);
    }

    return buildClientSuccessResponse(aiResult, origin);
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
  if (origin.startsWith("http://localhost:")) return true;
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
 * @returns {Promise<{ prompt: string, format: "long" | "short", referenceImageBase64?: string, referenceMimeType?: string }>}
 */
async function parseAndValidateBody(request) {
  const contentType = request.headers.get("Content-Type") ?? "";
  if (!contentType.includes("application/json")) {
    throw new Error("Content-Type must be application/json.");
  }

  const contentLength = parseInt(request.headers.get("Content-Length") ?? "0", 10);
  if (contentLength > MAX_BODY_BYTES) {
    throw new Error(
      `Request body too large. Maximum allowed size is ${MAX_BODY_BYTES / (1024 * 1024)} MB.`
    );
  }

  let rawBody;
  try {
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

  if (typeof prompt !== "string" || prompt.trim().length === 0) {
    throw new Error('Field "prompt" is required and must be a non-empty string.');
  }
  if (prompt.length > MAX_PROMPT_LENGTH) {
    throw new Error(
      `Field "prompt" exceeds the maximum length of ${MAX_PROMPT_LENGTH} characters.`
    );
  }

  if (format !== "long" && format !== "short") {
    throw new Error('Field "format" must be "long" or "short".');
  }

  const hasReference =
    typeof referenceImageBase64 === "string" && referenceImageBase64.length > 0;

  if (hasReference) {
    if (referenceImageBase64.startsWith("data:")) {
      throw new Error(
        'Field "referenceImageBase64" must not include data URI prefix. Send only the raw base64 string.'
      );
    }

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
// Workers AI
// ---------------------------------------------------------------------------

/**
 * Builds the full prompt string from the parsed body.
 *
 * @param {{ prompt: string, format: "long" | "short", referenceImageBase64?: string }} body
 * @returns {string}
 */
function buildFullPrompt(body) {
  const formatInstruction =
    body.format === "long"
      ? "Create a horizontal YouTube thumbnail in 16:9 landscape composition."
      : "Create a vertical short-video cover in 9:16 portrait composition.";

  const referenceClause = body.referenceImageBase64
    ? "Use the provided reference image as a visual style and composition guide. "
    : "";

  return (
    `You are an expert video thumbnail designer. ` +
    `${formatInstruction} ` +
    `${referenceClause}` +
    `User concept: ${body.prompt}. ` +
    `Style requirements: high contrast, clear focal subject, clean composition, professional quality. ` +
    `Do not add watermarks, logos, or accidental text unless explicitly requested.`
  );
}

/**
 * Builds the Workers AI model input with the required multipart payload.
 *
 * FLUX.2 Klein models on Workers AI require `multipart` input even for
 * prompt-only requests.
 *
 * @param {{ prompt: string, format: "long" | "short", referenceImageBase64?: string, referenceMimeType?: string }} body
 * @returns {{ multipart: { body: ReadableStream<Uint8Array>, contentType: string } }}
 * @throws {DOMException} if referenceImageBase64 is not valid base64
 * @throws {Error} if the multipart payload cannot be serialized
 */
function buildWorkersAiInput(body) {
  const dimensions = FORMAT_DIMENSIONS[body.format];
  const form = new FormData();

  form.append("prompt", buildFullPrompt(body));
  form.append("width", String(dimensions.width));
  form.append("height", String(dimensions.height));

  if (body.referenceImageBase64) {
    // atob throws DOMException for invalid base64 — caught by the caller.
    const binaryStr = atob(body.referenceImageBase64);
    const bytes = new Uint8Array(binaryStr.length);
    for (let i = 0; i < binaryStr.length; i++) {
      bytes[i] = binaryStr.charCodeAt(i);
    }

    const mimeType = body.referenceMimeType;
    const extension =
      mimeType === "image/jpeg" ? "jpg" :
      mimeType === "image/png" ? "png" :
      mimeType === "image/webp" ? "webp" : "bin";

    form.append(
      "input_image_0",
      new Blob([bytes], { type: mimeType }),
      `reference.${extension}`
    );
  }

  // Create a real multipart body + boundary content type for the binding.
  // The resulting stream is single-use — it is consumed once by env.AI.run().
  const multipartResponse = new Response(form);
  const stream = multipartResponse.body;
  const contentType = multipartResponse.headers.get("content-type");

  if (!stream || !contentType) {
    throw new Error("Failed to build multipart payload for Workers AI.");
  }

  return {
    multipart: {
      body: stream,
      contentType,
    },
  };
}

/**
 * Maps Workers AI runtime error to API contract.
 *
 * @param {unknown} err
 * @param {string} origin
 * @returns {Response}
 */
function mapWorkersAiError(err, origin) {
  const rawMessage = normalizeErrorMessage(err);
  const { status, code, serviceCode } = extractWorkersAiErrorMetadata(err, rawMessage);

  // Prefer structured fields over text heuristics.
  if (status === 429 || code === "quota_exceeded" || code === "rate_limit_exceeded") {
    return errorResponseWithCors(
      429,
      "QUOTA_EXCEEDED",
      "Generation quota reached. Please try again later.",
      origin
    );
  }

  // Explicit known codes; broad substring matching avoided to prevent false positives.
  if (
    status === 451 ||
    code === "safety_block" ||
    code === "content_policy_violation" ||
    code === "safety_violation"
  ) {
    return errorResponseWithCors(
      451,
      "SAFETY_BLOCK",
      "The request was blocked by the content safety filter.",
      origin
    );
  }

  if (
    status === 400 ||
    code === "invalid_request" ||
    code === "bad_request" ||
    serviceCode === 5006
  ) {
    return errorResponseWithCors(400, "BAD_REQUEST", "The request was rejected by the AI model.", origin);
  }

  // The early returns above already handle all known structured error codes.
  // hasStructuredMetadata guards the legacy text-heuristic block below:
  // if any structured field is present, text matching is skipped entirely
  // to prevent message content from overriding structured status.
  const hasStructuredMetadata =
    status !== null || code.length > 0 || serviceCode !== null;

  // Legacy fallback: when upstream does not expose structured error metadata.
  if (!hasStructuredMetadata) {
    const message = rawMessage.toLowerCase();

    if (
      message.includes("quota") ||
      message.includes("rate limit") ||
      message.includes("too many requests") ||
      message.includes("resource exhausted")
    ) {
      return errorResponseWithCors(
        429,
        "QUOTA_EXCEEDED",
        "Generation quota reached. Please try again later.",
        origin
      );
    }

    if (message.includes("safety") || message.includes("policy")) {
      return errorResponseWithCors(
        451,
        "SAFETY_BLOCK",
        "The request was blocked by the content safety filter.",
        origin
      );
    }

    if (message.includes("invalid") || message.includes("bad request")) {
      return errorResponseWithCors(400, "BAD_REQUEST", "The request was rejected by the AI model.", origin);
    }
  }

  console.error("Workers AI invocation failed:", rawMessage);
  return errorResponseWithCors(
    502,
    "UPSTREAM_ERROR",
    "The AI service returned an error. Please try again later.",
    origin
  );
}

/**
 * Extracts structured metadata from Workers AI error objects.
 *
 * @param {unknown} err
 * @param {string} rawMessage
 * @returns {{ status: number | null, code: string, serviceCode: number | null }}
 */
function extractWorkersAiErrorMetadata(err, rawMessage) {
  /** @type {number | null} */
  let status = null;
  let code = "";

  /** @type {Array<Record<string, unknown>>} */
  const candidates = [];
  if (typeof err === "object" && err !== null) {
    candidates.push(err);

    const direct = /** @type {Record<string, unknown>} */ (err);
    if (typeof direct.error === "object" && direct.error !== null) {
      candidates.push(/** @type {Record<string, unknown>} */ (direct.error));
    }
    if (typeof direct.response === "object" && direct.response !== null) {
      candidates.push(/** @type {Record<string, unknown>} */ (direct.response));
    }
    if (typeof direct.cause === "object" && direct.cause !== null) {
      candidates.push(/** @type {Record<string, unknown>} */ (direct.cause));
    }
  }

  for (const candidate of candidates) {
    if (status === null) {
      const statusValue = candidate.status ?? candidate.statusCode;
      if (typeof statusValue === "number" && Number.isFinite(statusValue)) {
        status = statusValue;
      } else if (typeof statusValue === "string" && /^\d+$/.test(statusValue)) {
        status = Number.parseInt(statusValue, 10);
      }
    }

    if (code.length === 0) {
      const codeValue = candidate.code ?? candidate.errorCode;
      if (typeof codeValue === "string" && codeValue.trim().length > 0) {
        code = codeValue.trim().toLowerCase();
      }
    }
  }

  /** @type {number | null} */
  let serviceCode = null;
  const serviceCodeMatch = /^(\d{4,})\s*:/.exec(rawMessage.trim());
  if (serviceCodeMatch) {
    serviceCode = Number.parseInt(serviceCodeMatch[1], 10);
  }

  return { status, code, serviceCode };
}

/**
 * Builds success response from Workers AI output.
 *
 * @param {unknown} aiResult
 * @param {string} origin
 * @returns {Response}
 */
function buildClientSuccessResponse(aiResult, origin) {
  const imageBase64 = extractImageBase64(aiResult);
  if (!imageBase64) {
    console.error("Workers AI response contained no image:", JSON.stringify(aiResult));
    return errorResponseWithCors(
      422,
      "NO_IMAGE_GENERATED",
      "The AI model did not generate an image.",
      origin
    );
  }

  return new Response(
    JSON.stringify({
      imageBase64,
      mimeType: OUTPUT_MIME_TYPE,
    }),
    {
      status: 200,
      headers: {
        "Content-Type": "application/json",
        ...corsHeaders(origin),
      },
    }
  );
}

/**
 * Tries known result shapes for Workers AI image models.
 *
 * @param {unknown} aiResult
 * @returns {string | null}
 */
function extractImageBase64(aiResult) {
  if (typeof aiResult === "object" && aiResult !== null) {
    if (typeof aiResult.image === "string" && aiResult.image.length > 0) {
      return aiResult.image;
    }
    if (
      typeof aiResult.result === "object" &&
      aiResult.result !== null &&
      typeof aiResult.result.image === "string" &&
      aiResult.result.image.length > 0
    ) {
      return aiResult.result.image;
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Error helpers
// ---------------------------------------------------------------------------

/**
 * Creates a structured JSON error response without CORS headers.
 *
 * @param {number} status
 * @param {string} code
 * @param {string} message
 * @returns {Response}
 */
function errorResponse(status, code, message) {
  return new Response(JSON.stringify({ error: { code, message } }), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/**
 * Creates a structured JSON error response with CORS headers.
 *
 * @param {number} status
 * @param {string} code
 * @param {string} message
 * @param {string} origin
 * @returns {Response}
 */
function errorResponseWithCors(status, code, message, origin) {
  return new Response(JSON.stringify({ error: { code, message } }), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...corsHeaders(origin),
    },
  });
}

/**
 * Best-effort conversion of unknown errors to readable string.
 *
 * @param {unknown} err
 * @returns {string}
 */
function normalizeErrorMessage(err) {
  if (err instanceof Error && typeof err.message === "string") {
    return err.message;
  }
  if (typeof err === "string") {
    return err;
  }
  try {
    return JSON.stringify(err);
  } catch {
    return "Unknown error";
  }
}

/**
 * Returns true when error indicates an invalid base64 payload in reference image.
 *
 * @param {unknown} err
 * @returns {boolean}
 */
function isInvalidReferenceEncodingError(err) {
  if (typeof DOMException !== "undefined" && err instanceof DOMException) {
    return err.name === "InvalidCharacterError";
  }

  return err instanceof Error && err.name === "InvalidCharacterError";
}
