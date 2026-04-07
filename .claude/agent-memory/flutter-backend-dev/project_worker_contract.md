---
name: Cloudflare Worker API contract
description: Request/response schema between Flutter Web and the Cloudflare Worker proxy, plus allowed origins, error codes, and Gemini endpoint details
type: project
---

The AiBlojka Cloudflare Worker lives at `cloudflare/worker.js` and is deployed via the Cloudflare Dashboard (paste-and-deploy, no CLI required for normal workflow).

**Gemini endpoint:**
`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-preview-image-generation:generateContent`
API key passed as query param `?key=GEMINI_API_KEY`.

**Allowed origins:**
- `https://yngQ.github.io` — production (GitHub Pages, real domain for this project)
- `http://localhost:*` — any local dev port

**Flutter → Worker request body:**
```json
{ "prompt": "...", "format": "long|short", "referenceImageBase64": "...", "referenceMimeType": "image/jpeg" }
```
- `referenceImageBase64` is optional; raw base64, no data URI prefix; max ~10 MB decoded
- `referenceMimeType` is required when `referenceImageBase64` is present; one of: `image/jpeg`, `image/png`, `image/webp`

**Worker → Flutter success body:**
```json
{ "imageBase64": "...", "mimeType": "image/png" }
```

**Worker → Flutter error body:**
```json
{ "error": { "code": "ERROR_CODE", "message": "..." } }
```

**Error code map:**
| HTTP | code | Trigger |
|------|------|---------|
| 400 | INVALID_REQUEST | Bad JSON / missing fields / bad format / prompt too long / missing referenceMimeType |
| 400 | BAD_REQUEST | Gemini rejected request for non-safety reason (e.g. malformed inlineData) |
| 403 | FORBIDDEN_ORIGIN | Origin not in allowlist |
| 405 | METHOD_NOT_ALLOWED | Non-POST |
| 422 | NO_IMAGE_GENERATED | Gemini responded but no image part found |
| 429 | QUOTA_EXCEEDED | Gemini per-minute or daily quota hit |
| 451 | SAFETY_BLOCK | Gemini content safety block (finishReason=SAFETY or error message match) |
| 500 | CONFIGURATION_ERROR | GEMINI_API_KEY secret missing |
| 502 | UPSTREAM_ERROR | Gemini 5xx or network failure after retries |

**Limits:** max body 12 MB, max prompt 2000 chars, 3 retry attempts (exponential backoff) on 429/503.

**Why:** API key must never reach the browser; Worker is the trust boundary.
**How to apply:** When implementing the Flutter GenerationService, POST to the Worker URL with the schema above and handle all error codes listed.
