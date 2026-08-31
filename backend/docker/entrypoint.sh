#!/bin/sh
set -eu

migration_mode="${MIGRATION_STARTUP_MODE:-verify}"

case "$migration_mode" in
  verify)
    python -m scripts.check_migrations
    ;;
  apply)
    if [ "${APP_ENVIRONMENT:-local}" = "prod" ]; then
      echo "error: production migrations must run as a dedicated pre-deploy job"
      exit 1
    fi
    alembic upgrade head
    python -m scripts.check_migrations
    ;;
  skip)
    case "${APP_ENVIRONMENT:-local}" in
      prod|staging)
        echo "error: migration verification cannot be skipped in staging/prod"
        exit 1
        ;;
    esac
    ;;
  *)
    echo "error: MIGRATION_STARTUP_MODE must be verify, apply or skip"
    exit 1
    ;;
esac

exec uvicorn app.main:app \
  --host 0.0.0.0 \
  --port "${PORT:-8000}" \
  --workers "${WEB_CONCURRENCY:-1}" \
  --timeout-graceful-shutdown "${GRACEFUL_SHUTDOWN_TIMEOUT_SECONDS:-30}" \
  --no-access-log
