FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app
COPY requirements.txt requirements-dev.txt ./
RUN python -m pip install --upgrade \
        pip \
        "setuptools>=83.0.0" \
        "wheel>=0.46.2" \
        "jaraco.context>=6.1.0" \
    && pip install -r requirements.txt
COPY . .
RUN chmod +x /app/docker/entrypoint.sh

FROM runtime AS test
RUN pip install -r requirements-dev.txt flake8

FROM runtime AS production
EXPOSE 8000
ENTRYPOINT ["/app/docker/entrypoint.sh"]
