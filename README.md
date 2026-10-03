<div align="center">

# 🚗 PlateVision

### Automatic Indian Number-Plate Recognition

A fine-tuned **YOLO** detector finds the plate, **PaddleOCR** reads it, and a
format resolver turns raw OCR text into a real Indian plate number —
**or honestly admits when it can't.**

<br>

![Python](https://img.shields.io/badge/Python-3.10+-3776AB?logo=python&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-0.116-009688?logo=fastapi&logoColor=white)
![React](https://img.shields.io/badge/React%20+%20TypeScript-61DAFB?logo=react&logoColor=black)
![Vite](https://img.shields.io/badge/Vite-5-646CFF?logo=vite&logoColor=white)
![YOLO](https://img.shields.io/badge/Ultralytics-YOLO-111F68)
![PaddleOCR](https://img.shields.io/badge/OCR-PaddleOCR-0062FF)
![Tests](https://img.shields.io/badge/tests-122%20passing-brightgreen)
![License](https://img.shields.io/badge/License-MIT-green)

<br>

[**Features**](#features) • [**Quick Start**](#installation) • [**Usage**](#usage) • [**API**](#api-reference) • [**Config**](#configuration)

</div>

---

## Overview

**PlateVision** is a full-stack system that detects and reads Indian vehicle
number plates from an image or a live camera feed. It pairs a fine-tuned YOLO
detector with PaddleOCR, then — crucially — **validates every reading against
real Indian plate formats** instead of blindly trusting the highest-confidence
text. The result is a plate number you can rely on, each one tagged with a
`valid` flag that tells you whether it truly matched a known format.

The React frontend is pre-built into the backend, so **one command runs the
entire app** — no Node required to use it.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Demo](#demo)
- [How It Works](#how-it-works)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Installation](#installation)
- [Usage](#usage)
- [API Reference](#api-reference)
- [Configuration](#configuration)
- [Testing](#testing)
- [Measuring Accuracy](#measuring-accuracy)
- [Known Limitations](#known-limitations)
- [License](#license)

## Features

- 🎯 **Accurate detection** — a fine-tuned Ultralytics YOLO model locates plates at 0.8–0.9 confidence.
- 🧾 **Format-aware OCR** — readings are resolved against the **1988 series** (`MH12AB1234`) and **Bharat series** (`22BH6517AA`), with real state-code validation.
- ✅ **A trustworthy `valid` flag** — a reading that matches a known format wins over a higher-confidence one that doesn't; garbage is flagged, never faked.
- 🔀 **Swappable OCR engines** — PaddleOCR (default, fast + accurate) or EasyOCR, behind a single setting.
- 🧠 **Smart confusion repair** — fixes `O`↔`0`, `I`↔`1`, `S`↔`5` mistakes, capped at 30% of the string so it can never fabricate a plate.
- 🪜 **Adaptive OCR cascade** — cheap native pass first; only hard crops pay for upscaling, bounded by a time budget.
- 🖥️ **Polished web UI** — drag-and-drop upload **and** live-camera scanning, built in React + TypeScript.
- 🔌 **Clean JSON API** — uniform response + error schema, auto-documented at `/docs`.
- ⚡ **One-command run** — the frontend is pre-built into the backend; `uvicorn app.main:app` serves everything.
- 🧪 **Well tested** — 120+ unit tests plus a real-weights integration suite.

## Demo

> 💡 **Add a screenshot or GIF here** to make this section shine — drop an image
> in a `docs/` folder and reference it:
>
> ```markdown
> ![PlateVision in action](docs/demo.gif)
> ```

| Upload an image | Live camera |
|---|---|
| Drag a photo in → get the plate, confidence, and an annotated result. | Point your webcam → plates are read in real time. |

## How It Works

```
┌────────────┐   ┌─────────────┐   ┌──────────────┐   ┌────────────────────┐
│  Image /   │──►│  YOLO        │──►│  PaddleOCR /  │──►│  Format resolver    │
│  camera    │   │  detect box  │   │  EasyOCR read │   │  + confusion repair │
└────────────┘   └─────────────┘   └──────────────┘   └─────────┬──────────┘
                                                                  │
                                              ┌───────────────────▼───────────────────┐
                                              │  valid = true  → confirmed plate        │
                                              │  valid = false → flagged, returned as-is │
                                              └─────────────────────────────────────────┘
```

### Why the `valid` flag matters

OCR on a plate crop returns whatever it finds — the plate, dealer watermarks,
the word "IND", partial reads. Picking the highest-confidence string gets this
wrong: on one sample, OCR reads a watermark `alam` at **97.6%** and the actual
plate `22BH6517` at **43.4%**. Confidence alone would return `ALAM`.

So every reading is matched against real Indian plate formats. A format match
beats raw confidence, and each result is tagged:

| `valid` | Meaning |
|:---:|---|
| `true`  | Matched a known plate format — **trustworthy**. |
| `false` | OCR produced something unrecognisable — returned **as-is**, flagged, never presented as confirmed. |

The pipeline never invents characters to force a match — confusion repair is
capped at 30% of the string, so `QQQQQQQQ` is rejected rather than mangled into
a valid-looking plate.

### Choosing an OCR engine

Two backends ship behind one setting, `OCR_ENGINE`. Measured on the sample
plates (same YOLO crops, single pass):

| | EasyOCR | **PaddleOCR mobile** (default) |
|---|---|:---:|
| Load time | 12.2 s | **19.6 s** |
| Per plate | 1.4–3.1 s | **0.29–0.41 s** |
| Clean plate | `22BH6517` 82% ✓ | **`22BH6517A` 99% ✓** |
| Low-res plate | ✗ invalid, 23% | **`HR26D0555` 99% ✓** |

PaddleOCR mobile is **4–8× faster and more accurate** here — and it reads the
trailing Bharat-series letter EasyOCR drops. Switch anytime with
`OCR_ENGINE=easyocr`; nothing else changes.

## Tech Stack

| Layer | Technologies |
|---|---|
| **Backend** | FastAPI · Pydantic v2 · Uvicorn · Python 3.10 |
| **Detection** | Ultralytics YOLO (fine-tuned `best.pt`) · PyTorch (CPU) |
| **OCR** | PaddleOCR (PP-OCRv5 mobile) · EasyOCR (fallback) |
| **Imaging** | OpenCV (headless) · NumPy · Pillow |
| **Frontend** | React · TypeScript · Vite |
| **Testing** | pytest |

## Project Structure

```
PlateVision/
├── app/                    FastAPI backend
│   ├── config.py           Typed settings (pydantic-settings), validated at startup
│   ├── schemas.py          Pydantic response models — the API contract
│   ├── plates.py           Format resolution, confusion repair, OCR cascade
│   ├── ocr.py              PaddleOCR / EasyOCR behind one interface
│   ├── inference.py        YOLO + OCR, loaded once, lock-serialised
│   ├── storage.py          Artifact writing (UUID names) + retention pruning
│   ├── routes.py           HTTP endpoints
│   ├── main.py             App factory, lifespan model loading, error handlers
│   └── web/                Pre-built React bundle (generated — see frontend/)
├── frontend/               React + TypeScript source
│   └── src/
│       ├── App.tsx         Layout, health polling, request flow
│       ├── api.ts          Typed client with a uniform ApiError
│       ├── types.ts        Mirrors app/schemas.py
│       └── components/     UploadPanel · CameraPanel · Results · PlateCard · About
├── tests/                  pytest suite + sample fixture images
├── scripts/
│   └── benchmark.py        Accuracy + latency over a labelled set
├── model/best.pt           Fine-tuned YOLO weights (via Git LFS)
├── requirements.txt        Runtime dependencies
└── pyproject.toml          Packaging + dev extras
```

> `app/plates.py` has **no** FastAPI, settings, or model imports — it takes OCR
> tuples in and returns dicts out, so the core logic is unit-testable in
> milliseconds without loading 52 MB of weights.

## Installation

### Prerequisites

- **Python 3.10+**
- **Git LFS** (the YOLO weights, ~52 MB, are stored via LFS) — install from
  [git-lfs.com](https://git-lfs.com), then `git lfs install` once.

### 1. Clone

```bash
git clone https://github.com/Likith-2004/platevision-anpr.git
cd platevision-anpr
git lfs pull          # ensures model/best.pt is the real file, not a pointer
```

### 2. Create a virtual environment

**Linux / macOS**
```bash
python -m venv .venv
source .venv/bin/activate
```

**Windows (CMD)**
```bat
python -m venv .venv
.venv\Scripts\activate
```

### 3. Install dependencies

```bash
pip install -r requirements.txt
```

> ⏳ This pulls PyTorch + PaddleOCR (~1.5 GB) and can take several minutes on the
> first run.

### 4. Run

```bash
uvicorn app.main:app
```

Then open **<http://localhost:8000>** for the UI, or **<http://localhost:8000/docs>**
for interactive API docs.

> First launch takes ~20–50 s while the models load. The server answers
> immediately and `/health` reports `ready: false` until loading finishes, so the
> UI shows a *"loading models"* state instead of failing.

### Developing the frontend (optional)

The UI is pre-built into `app/web/`, so you only need Node to **change** it:

```bash
npm --prefix frontend install
npm --prefix frontend run dev      # localhost:5173, proxies the API to :8000
npm --prefix frontend run build    # rebuilds app/web/
```

Edit `frontend/src` — `app/web/` is generated output and hand-edits there are
lost on the next build.

## Usage

### Web UI

1. Open <http://localhost:8000>.
2. **Upload** a vehicle image, or switch to **Live Camera** to scan in real time.
3. See the detected plate(s), confidence, the `valid` flag, and an annotated image.

### Command line

```bash
curl -F "image=@car.jpg" http://localhost:8000/detect
```

### Python

```python
import requests

with open("car.jpg", "rb") as f:
    r = requests.post("http://localhost:8000/detect", files={"image": f})

for plate in r.json()["plates"]:
    status = "✓" if plate["valid"] else "✗ (unverified)"
    print(f"{plate['number']}  {plate['confidence']}%  {status}")
```

## API Reference

Full interactive schema at **`/docs`** (generated from `app/schemas.py`).

### `POST /detect`

Multipart upload, field name `image`.

```json
{
  "plates": [
    {
      "number": "22BH6517A",
      "confidence": 99.23,
      "detection_confidence": 83.8,
      "valid": true,
      "format": "bh_series",
      "state": null,
      "corrections": 0,
      "variant": "clahe",
      "passes": 1,
      "votes": 1,
      "box": { "x1": 40, "y1": 30, "x2": 398, "y2": 169 }
    }
  ],
  "image_url": "/media/8d2f...c1.jpg",
  "source_width": 429,
  "source_height": 254,
  "elapsed_ms": 612.4
}
```

### Endpoints

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/detect` | Detect + read plates in an uploaded image. |
| `POST` | `/detect/frame` | Same, tuned for live-camera frames (one fast OCR pass, no file written). |
| `GET`  | `/media/{name}` | Fetch the annotated image from a `/detect` call. |
| `GET`  | `/health` | Readiness probe — `200` with `ready:false` while models load. |
| `GET`  | `/docs` | Interactive OpenAPI documentation. |

### Error format

Every non-2xx response has the same shape, with a stable machine-readable code:

```json
{
  "error": "unsupported_media_type",
  "detail": "Unsupported file type \".md\".",
  "allowed": [".bmp", ".jpeg", ".jpg", ".png", ".webp"]
}
```

| Status | `error` | Cause |
|---|---|---|
| 400 | `empty_file` / `undecodable_image` | Not a decodable image |
| 413 | `payload_too_large` | Exceeds `MAX_UPLOAD_MB` |
| 415 | `unsupported_media_type` | Extension not allowed |
| 422 | `validation_error` | Missing the `image` field |
| 503 | `not_ready` | Models still loading |

## Configuration

All settings come from environment variables (or a `.env` file), validated by
`app/config.py` at startup. See [.env.example](.env.example) for the annotated list.

| Variable | Default | Purpose |
|---|---|---|
| `HOST` / `PORT` | `127.0.0.1` / `8000` | Bind address |
| `MODEL_PATH` | `model/best.pt` | YOLO weights |
| `DATA_DIR` | `data` | Uploads and annotated output |
| `MAX_UPLOAD_MB` | `10` | Upload ceiling |
| `RETENTION_HOURS` | `24` | Prune artifacts older than this; `0` disables |
| `OCR_ENGINE` | `paddleocr` | `paddleocr` or `easyocr` |
| `PADDLE_DETECTION_MODEL` | `PP-OCRv5_mobile_det` | Paddle detector (mobile tier) |
| `PADDLE_RECOGNITION_MODEL` | `PP-OCRv5_mobile_rec` | Paddle recogniser (mobile tier) |
| `DETECTION_CONFIDENCE` | `0.5` | YOLO threshold that a region *is* a plate |
| `MAX_INFERENCE_EDGE` | `1280` | Downscale longest edge before detection |
| `CROP_PADDING_RATIO` | `0.06` | Crop margin as a fraction of the box's longer side |
| `OCR_MIN_CONFIDENCE` | `0.1` | Floor for text matching **no** format |
| `OCR_ACCEPT_CONFIDENCE` | `0.70` | Confidence that ends the cascade early |
| `OCR_MAX_PASSES` | `3` | Preprocessing passes; `1` = single native pass |
| `OCR_TIME_BUDGET` | `4.0` | Seconds ceiling on OCR per plate |

## Testing

```bash
pip install -e ".[dev]"

pytest -m "not slow"    # ~120 tests, ~9s, no model required
pytest -m slow          # integration tests against the real weights
pytest                  # everything

npm --prefix frontend run typecheck   # frontend types
```

The fast suite stubs the recognizer, covering validation, error handling, and
response shape without loading a model. The slow suite auto-skips when weights
are absent.

## Measuring Accuracy

The figures in this README come from a handful of sample images — an anecdote,
not a benchmark. To measure properly, build a labelled set and run:

```bash
python scripts/benchmark.py --images data/eval --labels data/eval/labels.csv
```

```csv
filename,plate
car01.jpg,MH12AB1234
car02.jpg,22BH6517AA
```

It reports exact-match accuracy plus latency, so a threshold or preprocessing
change can be judged rather than assumed. Roughly 50–100 labelled images makes
the numbers meaningful.

## Known Limitations

- **Accuracy is unquantified.** Format validity is verified; exact-match accuracy against ground truth awaits a labelled set.
- **Single-line Latin plates only.** Two-line plates are recombined, but stacked/vertical layouts and non-Latin scripts are untested.
- **No perspective correction.** Plates at a sharp angle read poorly — deskewing is an obvious next step.
- **No rate limiting or authentication** — add both before exposing `/detect` publicly, since each call costs seconds of CPU.

## License

Distributed under the **MIT License**. You're free to use, modify, and
distribute this project with attribution.

---

<div align="center">

**Built with YOLO, PaddleOCR, and a healthy distrust of raw OCR confidence.**

⭐ Star this repo if you found it useful!

</div>
