# AiBlojka — Cloudflare Worker: Deploy Guide

This Worker is the API proxy between the Flutter Web PWA (GitHub Pages) and
the Gemini 2.5 Flash Image API. It holds the Gemini API key so it is never
exposed to the browser.

---

## Files

| File | Purpose |
|------|---------|
| `worker.js` | Worker source code (ES Module) |
| `wrangler.toml` | Reference config for Wrangler CLI deployment |
| `README.md` | This guide |

---

## Deploy via Cloudflare Dashboard (recommended — no CLI needed)

### Step 1 — Create the Worker

1. Go to [dash.cloudflare.com](https://dash.cloudflare.com) and sign in.
2. In the left sidebar click **Workers & Pages**.
3. Click **Create** → **Create Worker**.
4. Give it a name, e.g. `aiblojka-proxy`.
5. Click **Deploy** (ignores the placeholder code for now).

### Step 2 — Paste the Worker code

1. On the Worker detail page click **Edit code**.
2. Delete all existing placeholder code in the editor.
3. Open `worker.js` from this repository, copy its entire contents, and paste
   it into the editor.
4. Click **Deploy** (top right).

### Step 3 — Add the Gemini API key as a secret

Secrets are encrypted at rest and never exposed in logs or the editor.

1. In the Worker detail page go to **Settings** → **Variables and Secrets**.
2. Under **Variables and Secrets** click **Add**.
3. Set:
   - **Type**: Secret
   - **Variable name**: `GEMINI_API_KEY`
   - **Value**: your Gemini API key from [aistudio.google.com](https://aistudio.google.com)
4. Click **Deploy** to apply.

### Step 4 — Note your Worker URL

After deploying you will see a URL like:

```
https://aiblojka-proxy.<your-subdomain>.workers.dev
```

Copy this URL — you will need it in the Flutter app's configuration so it
knows where to send generation requests.

---

## Update the Worker code

Whenever `worker.js` changes:

1. Open the Worker in the Dashboard → **Edit code**.
2. Replace the code and click **Deploy**.

The API key secret is preserved between code updates — you do not need to
re-enter it.

---

## Deploy via Wrangler CLI (alternative)

If you prefer the CLI workflow:

```bash
# Install Wrangler globally (requires Node.js)
npm install -g wrangler

# Authenticate
wrangler login

# Set the secret (paste your key when prompted)
wrangler secret put GEMINI_API_KEY

# Deploy from the cloudflare/ directory
cd cloudflare
wrangler deploy
```

See `wrangler.toml` for the full configuration reference.

---

## API Contract

### Request — Flutter → Worker

```
POST <worker-url>
Content-Type: application/json
Origin: https://yngQ.github.io
```

```json
{
  "prompt": "Dark cinematic background with a neon-lit cityscape",
  "format": "long",
  "referenceImageBase64": "<optional: raw base64 string, no data URI prefix>",
  "referenceMimeType": "image/jpeg"
}
```

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `prompt` | string | yes | Max 2000 characters. English or any language — the Worker wraps it in an English system prompt before sending to Gemini. |
| `format` | `"long"` or `"short"` | yes | `long` = 1920×1080 (YouTube); `short` = 1080×1920 (TikTok/Shorts/Reels) |
| `referenceImageBase64` | string | no | Raw base64 without the `data:image/...;base64,` prefix. Max ~10 MB decoded. |
| `referenceMimeType` | `"image/jpeg"` \| `"image/png"` \| `"image/webp"` | if `referenceImageBase64` present | Actual MIME type of the reference file. Required when sending a reference image. |

### Response — Worker → Flutter (success)

```json
{
  "imageBase64": "<raw base64 image data>",
  "mimeType": "image/png"
}
```

### Response — Worker → Flutter (error)

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable description."
  }
}
```

| HTTP status | `code` | Meaning |
|-------------|--------|---------|
| 400 | `INVALID_REQUEST` | Malformed JSON, missing fields, invalid `format`, prompt too long, missing `referenceMimeType` |
| 400 | `BAD_REQUEST` | Gemini rejected the request for a non-safety reason (e.g. malformed inlineData) |
| 403 | `FORBIDDEN_ORIGIN` | Request came from an origin not in the allowlist |
| 405 | `METHOD_NOT_ALLOWED` | Non-POST request |
| 422 | `NO_IMAGE_GENERATED` | Gemini returned a response but without an image part |
| 429 | `QUOTA_EXCEEDED` | Gemini per-minute or daily quota exhausted |
| 451 | `SAFETY_BLOCK` | Request blocked by Gemini content safety filter (via `finishReason=SAFETY` or error message) |
| 500 | `CONFIGURATION_ERROR` | `GEMINI_API_KEY` secret not set on the Worker |
| 502 | `UPSTREAM_ERROR` | Gemini returned 5xx or was unreachable after retries |

---

## Allowed Origins

| Origin | Purpose |
|--------|---------|
| `https://yngQ.github.io` | Production — GitHub Pages |
| `http://localhost:*` | Local Flutter development (`fvm flutter run -d chrome`) |

Requests from any other origin receive a `403 FORBIDDEN_ORIGIN` response.

---

## Retry Behaviour

The Worker automatically retries calls to Gemini on `429` and `503` responses
with exponential backoff (up to 3 attempts: 0s, 1s, 2s delays). This handles
brief Gemini rate spikes without surfacing transient errors to the user.

---

## Limits

| Parameter | Value |
|-----------|-------|
| Max request body | 12 MB (10 MB image + JSON overhead) |
| Max prompt length | 2000 characters |
| Cloudflare free tier | 100,000 requests/day |
| Gemini free tier | 500 image generations/day |
| Retry attempts | 3 (429 and 503 only) |

---

## Troubleshooting

**Getting `CONFIGURATION_ERROR` (500)**
The `GEMINI_API_KEY` secret is not set. Go to Settings → Variables and Secrets
and add it.

**Getting `FORBIDDEN_ORIGIN` (403) during local development**
Make sure Flutter is running with `fvm flutter run -d chrome` — this sends a
proper `http://localhost:<port>` Origin header. Direct `curl` calls without an
Origin header will also be blocked.

**Gemini returns no image (422)**
This usually means the model soft-refused the prompt without triggering a hard
safety block. Simplify or rephrase the description.

**Request times out**
Cloudflare Workers have a 30-second wall-clock limit on the free plan. Gemini
image generation can occasionally exceed this. If it becomes frequent, consider
upgrading to the Workers Paid plan (no wall-clock limit).
