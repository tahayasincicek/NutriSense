FROM python:3.11.11-slim-bookworm@sha256:081075da77b2b55c23c088251026fb69a7b2bf92471e491ff5fd75c192fd38e5

RUN addgroup --system --gid 10001 mock \
    && adduser --system --uid 10001 --ingroup mock \
      --disabled-password --no-create-home mock
WORKDIR /app
COPY --chown=10001:10001 server.py /app/server.py
RUN chmod 0444 /app/server.py
USER 10001:10001
EXPOSE 8090
ENTRYPOINT ["python", "/app/server.py"]
