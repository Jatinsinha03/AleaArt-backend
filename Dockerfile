# syntax=docker/dockerfile:1

FROM python:3.11-slim AS runtime

# Keep Python lean and disable pip cache
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    HF_HOME=/var/huggingface

WORKDIR /app

# System deps (keep minimal). libgomp1 is required by PyTorch CPU wheels.
RUN apt-get update && apt-get install -y --no-install-recommends \
      libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Install dependencies in layers for better caching
COPY requirements.txt ./

# Install CPU-only PyTorch first to avoid pulling CUDA wheels
RUN python -m pip install --upgrade pip setuptools wheel && \
    pip install --no-cache-dir --index-url https://download.pytorch.org/whl/cpu torch && \
    pip install --no-cache-dir -r requirements.txt --extra-index-url https://download.pytorch.org/whl/cpu && \
    pip install --no-cache-dir gunicorn

# Copy application
COPY python_backend_simple.py ./

# Create Hugging Face cache directory (models will download at runtime)
RUN mkdir -p ${HF_HOME}

EXPOSE 8000

# Use gunicorn to serve Flask app; importing the module avoids running __main__ which installs packages
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "1", "--threads", "2", "--timeout", "120", "python_backend_simple:app"]
