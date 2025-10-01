# ─────────────────────────────────────────────────────────────────────────────
# FILE: Dockerfile
# ─────────────────────────────────────────────────────────────────────────────
FROM docker:27-cli
RUN apk add --no-cache curl jq tzdata
WORKDIR /app

# why: build-time metadata (visible in OCI labels)
ARG VERSION=dev
ARG VCS_REF=local

COPY healthwatch.sh /app/healthwatch.sh
RUN chmod +x /app/healthwatch.sh

# OCI labels for traceability
LABEL org.opencontainers.image.title="docker-healthwatch" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}"

ENTRYPOINT ["/bin/sh", "/app/healthwatch.sh"]
