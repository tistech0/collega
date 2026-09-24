# syntax=docker/dockerfile:1
# Étape 1 : dépendances Python installées depuis poetry.lock dans un venv autonome.
FROM python:3.11-slim AS builder

ENV PIP_NO_CACHE_DIR=1 PIP_DISABLE_PIP_VERSION_CHECK=1
RUN pip install "poetry==2.5.1" "poetry-plugin-export==1.9.0"

WORKDIR /build
COPY pyproject.toml poetry.lock ./
RUN poetry export --only main -f requirements.txt -o requirements.txt \
    && python -m venv /opt/venv \
    && /opt/venv/bin/pip install -r requirements.txt \
    && find /opt/venv -name '__pycache__' -type d -prune -exec rm -rf {} +

# Étape 2 : image d'exécution, sans poetry ni outils de build.
FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    tesseract-ocr \
    tesseract-ocr-fra \
    poppler-utils \
    && rm -rf /var/lib/apt/lists/* /usr/share/doc/* /usr/share/man/*

# uid 1000 : le dossier bind des PDFs sur le NAS (/mnt/user/appdata/collega/pdfs)
# doit appartenir à cet uid (chown fait au déploiement du chantier 3).
RUN useradd --uid 1000 --create-home --shell /usr/sbin/nologin collega \
    && mkdir -p /tmp/collega_pdfs && chown collega:collega /tmp/collega_pdfs

COPY --from=builder /opt/venv /opt/venv
ENV PATH=/opt/venv/bin:$PATH PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1

WORKDIR /app
COPY --chown=collega:collega alembic.ini ./
COPY --chown=collega:collega alembic ./alembic
COPY --chown=collega:collega app ./app
COPY --chown=collega:collega scripts ./scripts

USER collega

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
