FROM python:3.11-slim AS dependencies

WORKDIR /build
COPY backend/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.11-slim AS runtime

ARG FABLE_UID=1000
ARG FABLE_GID=1000

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    FABLE_DB_PATH=/app/data/fable.sqlite3

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid "${FABLE_GID}" fable \
    && useradd --system --uid "${FABLE_UID}" --gid fable --home-dir /app --shell /usr/sbin/nologin fableuser \
    && mkdir -p /app/data \
    && chown -R fableuser:fable /app

COPY --from=dependencies /install/ /usr/local/
WORKDIR /app
COPY backend/ ./

USER fableuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD curl --fail --silent http://127.0.0.1:8000/api/v1/health || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
