ARG PYTHON_IMAGE=python:3.11-slim-bookworm@sha256:528257d48c1da0dcecc2e725d1ae34498d60c965f1241e39cd6a85a8859bdf84

FROM ${PYTHON_IMAGE} AS wheels

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /build
COPY requirements.lock requirements-dev.lock ./
RUN python -m pip wheel \
      --require-hashes \
      --wheel-dir /wheels \
      --requirement requirements-dev.lock

FROM ${PYTHON_IMAGE} AS production

ARG BUILD_VERSION=0.0.0-local
ARG BUILD_REVISION=unknown
ARG BUILD_CREATED=unknown

LABEL org.opencontainers.image.title="NutriSense backend" \
      org.opencontainers.image.version="${BUILD_VERSION}" \
      org.opencontainers.image.revision="${BUILD_REVISION}" \
      org.opencontainers.image.created="${BUILD_CREATED}" \
      org.opencontainers.image.source="https://github.com/tahayasincicek/NutriSense"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPYCACHEPREFIX=/tmp/pycache \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    APP_VERSION=${BUILD_VERSION} \
    BUILD_REVISION=${BUILD_REVISION}

RUN addgroup --system --gid 10001 nutrisense \
    && adduser --system --uid 10001 --ingroup nutrisense \
      --disabled-password --no-create-home nutrisense

WORKDIR /app
COPY --from=wheels /wheels /wheels
COPY requirements.lock ./
RUN python -m pip install \
      --no-index \
      --find-links=/wheels \
      --require-hashes \
      --requirement requirements.lock \
    && rm -rf /wheels

# Temel imajla gelen paketleme araçları çalışma zamanında kullanılmıyor ama
# zafiyet taramasında görünüyor. Uygulama için gereksiz olduklarından
# kaldırılır; bu hem bulguyu hem saldırı yüzeyini ortadan kaldırır.
RUN python -m pip uninstall --yes setuptools wheel

COPY --chown=10001:10001 app ./app
COPY --chown=10001:10001 migrations ./migrations
COPY --chown=10001:10001 alembic.ini ./
COPY --chown=10001:10001 docker/entrypoint.sh ./docker/entrypoint.sh
COPY --chown=10001:10001 scripts/check_migrations.py ./scripts/check_migrations.py
COPY --chown=10001:10001 scripts/fetch_ml_artifact.py ./scripts/fetch_ml_artifact.py
RUN chmod 0555 /app/docker/entrypoint.sh \
    && find /app -type d -exec chmod 0555 {} \; \
    && find /app -type f ! -path /app/docker/entrypoint.sh -exec chmod 0444 {} \;

USER 10001:10001
EXPOSE 8000
STOPSIGNAL SIGTERM
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health/live', timeout=3)"]
ENTRYPOINT ["/app/docker/entrypoint.sh"]

FROM production AS test

USER root
COPY requirements-dev.lock ./
COPY --from=wheels /wheels /wheels
RUN python -m pip install \
      --no-index \
      --find-links=/wheels \
      --require-hashes \
      --requirement requirements-dev.lock \
    && rm -rf /wheels
COPY --chown=10001:10001 tests ./tests
COPY --chown=10001:10001 scripts ./scripts
USER 10001:10001
