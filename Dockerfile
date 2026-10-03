# syntax=docker/dockerfile:1
#
# PlateVision API image — FastAPI + YOLO (ultralytics) + PaddleOCR.
#
# This image is the BACKEND only. The React frontend deploys separately to
# Vercel (see frontend/vercel.json); it is not copied in here. The image runs
# on any container host — Render, Railway, or Fly.io — with the same CMD.
#
# Local build & run:
#     docker build -t platevision-api .
#     docker run -p 8000:8000 -e CORS_ORIGINS='*' platevision-api
#     open http://localhost:8000/docs

FROM python:3.10-slim

# Runtime libs the wheels need on a slim image:
#   libgomp1     — OpenMP, required by torch and paddlepaddle CPU kernels.
#   libglib2.0-0 — pulled in by opencv.
#   libgl1       — provides libGL.so.1. We pin opencv-python-headless, but
#                  paddlex/ultralytics drag in full opencv-python transitively,
#                  and its cv2 fails to import without libGL. Cheap to include.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgomp1 libglib2.0-0 libgl1 \
    && rm -rf /var/lib/apt/lists/*

ENV PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    # Bake PaddleOCR weights into the image at build time and read them from a
    # writable cache at runtime, so a cold start never downloads ~21 MB into a
    # read-only $HOME. Matches app/config.py's paddle_model_dir / paddle_cache_dir.
    PADDLE_MODEL_DIR=/opt/paddle \
    PADDLE_CACHE_DIR=/tmp/paddle \
    # Cloud-ready defaults. DATA_DIR under /tmp so the app can create it even when
    # the host runs the container as a non-root user (e.g. Hugging Face Spaces),
    # where /app is root-owned. INLINE_IMAGES returns the annotated image as a
    # data URI — correct for an ephemeral/multi-instance container filesystem.
    DATA_DIR=/tmp/data \
    INLINE_IMAGES=true

WORKDIR /app

# Dependencies first, so the ~1 GB torch+paddle layer is cached across code
# changes. requirements-deploy.txt pins CPU-only torch (~200 MB) via its own
# --extra-index-url, not the 2 GB CUDA build from PyPI.
COPY requirements-deploy.txt ./
# Cache mount keeps the ~1 GB of wheels across rebuilds so only changed layers
# re-download. The cache lives in the mount, not the image layer, so the image
# stays small. Harmless on hosts without BuildKit cache (it just stays empty).
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements-deploy.txt

# Application code, build scripts, and the committed YOLO weights.
COPY app ./app
COPY scripts ./scripts
COPY model ./model

# Bake weights at build time:
#   fetch_model  — no-op here because model/best.pt is committed and copied above.
#   warm_paddle  — downloads the PaddleOCR mobile det/rec models into PADDLE_MODEL_DIR.
RUN python scripts/fetch_model.py \
    && python scripts/warm_paddle.py

# The host injects $PORT; default to 8000 for a plain `docker run`.
ENV PORT=8000
EXPOSE 8000

# Exec form via sh -c so ${PORT} still expands. One worker: the models load once
# per process and concurrent requests queue on the app's own inference pool
# (INFERENCE_WORKERS).
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT} --workers 1"]
