# AiBlojka — Cloudflare Worker (Workers AI)

This Worker is the API proxy between the Flutter Web PWA (GitHub Pages) and
Cloudflare Workers AI image generation.

It keeps the same API contract for Flutter:

- request: `POST` JSON with `prompt`, `format`, optional `referenceImageBase64`
- success: `{ "imageBase64": "...", "mimeType": "image/jpeg" }`

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

- The selected model is `@cf/black-forest-labs/flux-1-schnell`.
- `referenceImageBase64` is accepted by API contract, but currently ignored by
  this model (text-to-image generation only).

