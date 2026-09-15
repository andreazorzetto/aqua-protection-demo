#!/usr/bin/env python3
"""
Secure AI demo leg.

Aqua Secure AI performs client-side detection by inspecting *outgoing TLS
requests* from monitored workloads to known AI services (OpenAI, Anthropic,
Gemini, Bedrock, ...). It extracts the model and the first system prompt from
the request and raises an AI finding / incident.

Key facts from the docs that shape this script:
  * Detection is on TLS/SSL traffic only — plain HTTP is NOT detected, so we
    must call the real https:// endpoint.
  * The request itself is what's inspected, so a valid API key is NOT required
    (a 401 from the provider is fine — the outbound AI call already fired).
  * Metadata shown = model + system prompt from the first request in the
    session, so we send a realistic chat-completion body.
"""
import json
import os
import ssl
import time
import urllib.request
import urllib.error

# (label, url, headers, body) for each provider we want to light up.
API_KEY = os.environ.get("OPENAI_API_KEY", "sk-demo-not-a-real-key")

TARGETS = [
    (
        "OpenAI",
        "https://api.openai.com/v1/chat/completions",
        {"Authorization": f"Bearer {API_KEY}", "Content-Type": "application/json"},
        {
            "model": "gpt-3.5-turbo",
            "messages": [
                {"role": "system", "content": "You are a helpful assistant for the Aqua Secure AI demo."},
                {"role": "user", "content": "Say hello from a monitored container."},
            ],
        },
    ),
    (
        "Anthropic",
        "https://api.anthropic.com/v1/messages",
        {"x-api-key": os.environ.get("ANTHROPIC_API_KEY", "sk-ant-demo"),
         "anthropic-version": "2023-06-01", "Content-Type": "application/json"},
        {
            "model": "claude-3-haiku-20240307",
            "max_tokens": 32,
            "system": "You are a helpful assistant for the Aqua Secure AI demo.",
            "messages": [{"role": "user", "content": "Say hello from a monitored container."}],
        },
    ),
]


def call(label, url, headers, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")
    ctx = ssl.create_default_context()
    try:
        with urllib.request.urlopen(req, timeout=15, context=ctx) as r:
            print(f"[Secure AI demo] {label}: HTTP {r.status} (outbound TLS AI call sent)")
    except urllib.error.HTTPError as e:
        # 401/403 is expected with a demo key — the outbound AI request still fired.
        print(f"[Secure AI demo] {label}: HTTP {e.code} (expected without real key — call was made)")
    except Exception as e:
        print(f"[Secure AI demo] {label}: connection error: {e}")


def main():
    print("[Secure AI demo] issuing outbound TLS requests to AI providers...")
    for _ in range(3):
        for label, url, headers, body in TARGETS:
            call(label, url, headers, body)
        time.sleep(5)
    print("[Secure AI demo] done — Secure AI should show an AI finding (model + system prompt).")


if __name__ == "__main__":
    main()
