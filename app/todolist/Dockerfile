# ==============================================================================
# Build image for todolist application
# Python 3.13-slim (Debian trixie) — psycopg2-binary 2.9.10 já tem wheel p/ 3.13
# ==============================================================================

FROM python:3.13-slim

WORKDIR /app

# System dependencies mínimas (apenas libpq para psycopg2, já inclui o driver)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Python dependencies (versões com CVEs corrigidas: psycopg2 2.9.10, requests 2.32.3)
# Corrigir msgpack/setuptools antes do build (versões com CVEs corrigidas)
RUN pip install --no-cache-dir --force-reinstall msgpack==1.2.2 setuptools==84.0.0

COPY requirements.txt .
RUN pip install --no-cache-dir --force-reinstall -r requirements.txt

# Copy application code
COPY app.py .

# Run as non-root user
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# Expose port
EXPOSE 5000

# Healthcheck
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:5000/healthz || exit 1

# Run with gunicorn for production
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--threads", "2", "--timeout", "60", "app:app"]