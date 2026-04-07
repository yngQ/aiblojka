---
name: Cloudflare Worker API contract
description: Request/response schema between Flutter Web and the Cloudflare Worker proxy (Workers AI backend), plus allowed origins and error codes
type: project
---

The AiBlojka Cloudflare Worker lives at `cloudflare/worker.js` and is deployed via the Cloudflare Dashboard (paste-and-deploy, no CLI required for normal workflow).

**Backend:** Cloudflare Workers AI — model `@cf/black-forest-labs/flux-1-schnell`.
Requires a Workers AI binding named `AI` (`env.AI.run`). No external API key needed.

**Allowed origins:**
- `https://yngq.github.io` — production (GitHub Pages, real domain for this project)
- `http://localhost:*` — any local dev port

**Flutter → Worker request body:**
```json
{ "prompt": "...", "format": "long|short", "referenceImageBase64": "...", "referenceMimeType": "image/jpeg" }
```
- `prompt` is the raw user concept (with optional style prefix from Remote Config). The Worker wraps it internally with format instructions and quality requirements.
- `referenceImageBase64` is optional; raw base64, no data URI prefix; max ~10 MB decoded
- `referenceMimeType` is required when `referenceImageBase64` is present; one of: `image/jpeg`, `image/png`, `image/webp`
- Note: `referenceImageBase64` is accepted but currently ignored by `flux-1-schnell` (text-to-image only)

**Worker → Flutter success body:**
```json
{ "imageBase64": "...", "mimeType": "image/jpeg" }
```

**Worker → Flutter error body:**
```json
{ "error": { "code": "ERROR_CODE", "message": "..." } }
```

**Error code map:**
| HTTP | code | Trigger |
|------|------|---------|
| 400 | INVALID_REQUEST | Bad JSON / missing fields / bad format / prompt too long / missing referenceMimeType |
| 400 | BAD_REQUEST | Workers AI rejected request |
| 403 | FORBIDDEN_ORIGIN | Origin not in allowlist |
| 405 | METHOD_NOT_ALLOWED | Non-POST |
| 422 | NO_IMAGE_GENERATED | Workers AI responded but no image found |
| 429 | QUOTA_EXCEEDED | Workers AI quota hit |
| 451 | SAFETY_BLOCK | Content safety block |
| 500 | CONFIGURATION_ERROR | Workers AI binding (`env.AI`) not configured |
| 502 | UPSTREAM_ERROR | Workers AI error |

**Limits:** max body 12 MB, max prompt 2000 chars.

**Why:** API key / AI binding must never reach the browser; Worker is the trust boundary.
**How to apply:** When implementing the Flutter GenerationService, POST to the Worker URL with the schema above and handle all error codes listed.
