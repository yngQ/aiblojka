# AiBlojka — Cloudflare Worker (Workers AI)

This Worker is the API proxy between the Flutter Web PWA (GitHub Pages) and
Cloudflare Workers AI image generation.

It keeps the same API contract for Flutter:

- request: `POST` JSON with `prompt`, `format`, optional `referenceImageBase64` (requires `referenceMimeType`)
- success: `{ "imageBase64": "...", "mimeType": "image/png" }`

---

## Files

| File | Purpose |
|------|---------|
| `worker.js` | Worker source code (ES Module) |
| `wrangler.toml` | Wrangler config with Workers AI binding |
| `README.md` | This guide |

---

## Deploy via Cloudflare Dashboard

### Step 1 — Create or open the Worker

1. Go to [dash.cloudflare.com](https://dash.cloudflare.com).
2. Open **Workers & Pages**.
3. Create/open Worker `aiblojka-proxy`.

### Step 2 — Paste code and deploy

1. Open **Edit code**.
2. Replace the code with `worker.js` from this folder.
3. Click **Deploy**.

### Step 3 — Add Workers AI binding

1. Open Worker **Settings** → **Bindings**.
2. Click **Add binding** → **Workers AI**.
3. Set variable name to `AI`.
4. Save and deploy again.

No `GEMINI_API_KEY` secret is required in this version.

### Step 4 — Set Worker URL in Firebase Remote Config

Set key `cloudflare_worker_url` to:

`https://aiblojka-proxy.<your-subdomain>.workers.dev`

Then publish Remote Config changes.

---

## Deploy via Wrangler CLI

```bash
npm install -g wrangler
wrangler login
cd cloudflare
wrangler deploy
```

`wrangler.toml` already includes:

```toml
[ai]
binding = "AI"
```

---

## Allowed Origins

- `https://yngq.github.io` (production)
- `http://localhost:*` (local Flutter development)

Requests from other origins get `403 FORBIDDEN_ORIGIN`.

---

## Known Behavior

- The selected model is `@cf/black-forest-labs/flux-2-klein-4b`.
- Image dimensions are set by `format`: `long` → 1024×576 (16:9), `short` → 576×1024 (9:16).
- `referenceImageBase64` + `referenceMimeType` are forwarded to the model as
  `input_image_0` multipart input when provided.

---

## Troubleshooting

**Getting `CONFIGURATION_ERROR` (500)**
The Workers AI binding `AI` is not configured. Go to Worker **Settings → Bindings**,
add a Workers AI binding, and set the variable name to `AI`. Redeploy.

**Getting `FORBIDDEN_ORIGIN` (403) during local development**
Make sure Flutter is running with `fvm flutter run -d chrome` — this sends a
proper `http://localhost:<port>` Origin header. Direct `curl` calls without an
Origin header will also be blocked.

**Getting `NO_IMAGE_GENERATED` (422)**
The model did not produce an image. Simplify or rephrase the prompt description.

**Request times out**
Cloudflare Workers have a 30-second CPU wall-clock limit on the free plan.
If image generation consistently times out, consider upgrading to the Workers
Paid plan which removes the wall-clock limit.
