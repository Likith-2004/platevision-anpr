# Deployment

PlateVision deploys as **two services**:

| Part | What | Where | Why |
|------|------|-------|-----|
| **Backend** | FastAPI + YOLO + PaddleOCR (`app.main:app`) | A container host — **Render**, Railway, or Fly.io | PyTorch + PaddleOCR is >1 GB installed; it cannot fit a serverless/edge function. It needs a long-running container with ≥1 GB RAM. |
| **Frontend** | React + Vite static bundle (`frontend/`) | **Vercel** (or any static host) | Pure static assets; nothing to run server-side. |

The browser loads the frontend from Vercel and calls the backend directly over
HTTPS. The two live on different origins, so the backend enables **CORS** for the
frontend's domain.

```
            ┌─────────────┐        HTTPS /detect, /health        ┌──────────────────────┐
  Browser ─►│  Vercel      │ ───────────────────────────────────►│  Render (container)  │
            │  (frontend)  │   VITE_API_BASE = backend URL        │  FastAPI + YOLO + OCR │
            └─────────────┘   ◄── CORS_ORIGINS = vercel domain ──└──────────────────────┘
```

> **Single-host alternative.** The backend can also serve the frontend itself:
> `app/web/` holds a committed build, so `uvicorn app.main:app` serves the UI at
> `/` with no Vercel and no CORS. If you deploy only the container and skip
> Vercel, set `CORS_ORIGINS` empty and `VITE_API_BASE` empty, and rebuild the UI
> into `app/web/` with `npm --prefix frontend run build`. The rest of this guide
> covers the split deploy.

---

## Order of operations

The two services reference each other, so deploy in this order:

1. **Backend first** → gives you its URL.
2. **Frontend** with `VITE_API_BASE` = that URL → gives you the Vercel domain.
3. **Back to the backend** → set `CORS_ORIGINS` = the Vercel domain.

---

## 1. Backend → Render

`render.yaml` is a Blueprint, so Render reads the whole config from the repo.

1. Push the repo to GitHub.
2. Render dashboard → **New → Blueprint** → select the repo. It picks up
   `render.yaml` (Docker runtime, `Dockerfile`, health check `/health`).
3. **Choose an instance with ≥ 1 GB RAM.** The free 512 MB tier **OOMs** while
   loading torch + paddle.
4. Deploy. First build takes a while — it installs ~1 GB of wheels and bakes the
   YOLO + PaddleOCR weights into the image.
5. When live, note the URL, e.g. `https://platevision-api.onrender.com`.
6. Verify:
   - `https://<backend>/health` → `{"status":"ok","ready":true,...}` after the
     model finishes loading (~30 s; returns 200 with `ready:false` before that).
   - `https://<backend>/docs` → interactive API docs.

### Backend environment variables

Set in `render.yaml` or the Render dashboard. Defaults live in `app/config.py`.

| Variable | Set to | Why |
|----------|--------|-----|
| `API_PREFIX` | `""` (empty) | Routes stay at the root (`/health`, `/detect`). A prefix is only needed for a single-domain deploy that rewrites `/api/*`. |
| `INLINE_IMAGES` | `true` | Returns the annotated image as an inline data URI instead of a `/media/...` URL. Avoids a cross-origin media fetch and survives an ephemeral filesystem. |
| `CORS_ORIGINS` | your Vercel domain | Browser origin allowed to call the API, e.g. `https://platevision.vercel.app`. Comma-separated for several; `*` to allow any. **Set this in step 3, after the frontend is live.** |
| `PADDLE_MODEL_DIR` | `/opt/paddle` | Baked-in PaddleOCR weights (see `Dockerfile`). |
| `PADDLE_CACHE_DIR` | `/tmp/paddle` | Writable cache seeded from the baked weights at startup. |

### The detector weights

`model/best.pt` (~52 MB) is committed, so the container has the YOLO model on a
clean clone — no fetch needed. If you remove it from git instead, set `MODEL_URL`
(and ideally `MODEL_SHA256`); `scripts/fetch_model.py` downloads it at build time.

### Railway / Fly.io

The same `Dockerfile` runs unchanged. Point the platform at it, expose `$PORT`
(the image already honors it), set the env vars above, and use `/health` as the
health check.

---

## 2. Frontend → Vercel

1. Import the repo in Vercel.
2. **Settings → General → Root Directory = `frontend`.** (The Vite app lives
   there; `frontend/vercel.json` provides the build and SPA routing.)
3. **Settings → Environment Variables → add `VITE_API_BASE`** = your backend URL
   from step 1, e.g. `https://platevision-api.onrender.com`.
   - It is read at **build time** (Vite), so a change needs a redeploy.
   - Do **not** append `/api` — the backend runs with `API_PREFIX=""`.
   - A committed fallback lives in `frontend/.env.vercel`; the dashboard value
     overrides it.
4. Deploy. Note the domain, e.g. `https://platevision.vercel.app`.

---

## 3. Connect CORS

In Render → the service's environment → set **`CORS_ORIGINS`** to the Vercel
domain from step 2. Render redeploys. Reload the Vercel site and upload a plate —
the request should reach the backend and render the annotated result.

If an upload fails with a CORS error in the browser console, `CORS_ORIGINS` does
not exactly match the site's origin (scheme + host, no trailing slash).

---

## Local development

Backend (serves the committed UI at `/` as well):

```bash
pip install -r requirements.txt
uvicorn app.main:app --reload
# http://localhost:8000  (UI)   ·   http://localhost:8000/docs  (API)
```

Frontend with live reload against a local backend:

```bash
npm --prefix frontend install
npm --prefix frontend run dev        # http://localhost:5173, proxies to the API
```

Run the container exactly as it ships:

```bash
docker build -t platevision-api .
docker run -p 8000:8000 -e CORS_ORIGINS='*' -e INLINE_IMAGES=true platevision-api
```

Tests:

```bash
pytest
```

---

## Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/health` | Readiness probe. 200 with `ready:false` while models load. |
| POST | `/detect` | Detect + recognise plates in an uploaded image (form field `image`). |
| POST | `/detect/frame` | Same, tuned for a single live-camera frame (lower latency). |
| GET | `/media/{name}` | Annotated image, when `INLINE_IMAGES=false`. |
| GET | `/docs` | OpenAPI docs. |
