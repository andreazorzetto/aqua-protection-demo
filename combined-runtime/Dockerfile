# Combined runtime demo image — Drift + AMP + Secure AI in one container.
#
# The OLD Alpine tag is intentional: it also produces a vulnerability finding on
# scan, so a single image demonstrates 3 runtime controls + a vuln finding.
# Bump the tag if you want a clean scan instead.
FROM alpine:3.16

RUN apk add --no-cache bash ca-certificates curl python3

WORKDIR /app

COPY entrypoint.sh drift.sh amp.sh secure_ai.py colors.sh /app/
RUN chmod +x /app/entrypoint.sh /app/drift.sh /app/amp.sh /app/secure_ai.py

ENTRYPOINT ["/app/entrypoint.sh"]
