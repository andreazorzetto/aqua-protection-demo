# Secure AI demo target.
# Makes outbound TLS calls to AI providers so Secure AI raises an AI finding.
# Harmless: just HTTPS requests to public AI APIs (no key required to trigger).
FROM python:3.12-slim

COPY trigger.py /trigger.py

# Secure AI only inspects TLS traffic, so ensure CA certs are present.
ENTRYPOINT ["python3", "/trigger.py"]
