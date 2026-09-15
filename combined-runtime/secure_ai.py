#!/usr/bin/env python3
"""
Secure AI leg.

Secure AI inspects OUTBOUND TLS requests to known AI services and extracts the
model + first system prompt. Two properties this script relies on:
  * It does NOT exit when OPENAI_API_KEY is missing. The detection is on the
    outbound request, not the response — a 401 still fires Secure AI. Bailing
    out with no key means no TLS call and no detection at all.
  * It hits more than one provider so the demo works regardless of which AI
    domains the policy is watching.
Plain HTTP is not detected by Secure AI, so we always use https://.
"""
import json
import os
import ssl
import time
import urllib.error
import urllib.request

TARGETS = [
    (
        "OpenAI",
        "https://api.openai.com/v1/chat/completions",
        {"Authorization": f"Bearer {os.environ.get('OPENAI_API_KEY', 'sk-demo-not-a-real-key')}",
         "Content-Type": "application/json"},
        {"model": "gpt-4o-mini",
         "messages": [
             {"role": "system", "content": "You are a helpful assistant for the Aqua Secure AI demo."},
             {"role": "user", "content": "hello from a monitored container"}]},
    ),
    (
        "Anthropic",
        "https://api.anthropic.com/v1/messages",
        {"x-api-key": os.environ.get("ANTHROPIC_API_KEY", "sk-ant-demo"),
         "anthropic-version": "2023-06-01", "Content-Type": "application/json"},
        {"model": "claude-3-haiku-20240307", "max_tokens": 16,
         "system": "You are a helpful assistant for the Aqua Secure AI demo.",
         "messages": [{"role": "user", "content": "hello from a monitored container"}]},
    ),
]


def call(label, url, headers, body):
    req = urllib.request.Request(url, data=json.dumps(body).encode(),
                                 headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=15, context=ssl.create_default_context()) as r:
            print(f"{label}: HTTP {r.status} (outbound TLS AI call sent)")
    except urllib.error.HTTPError as e:
        print(f"{label}: HTTP {e.code} (expected without a real key — the AI call still fired)")
    except Exception as e:  # noqa: BLE001
        print(f"{label}: connection error: {e}")


def main():
    print("Issuing outbound TLS requests to AI providers...")
    for _ in range(2):
        for t in TARGETS:
            call(*t)
        time.sleep(3)
    print("Secure AI: done.")


if __name__ == "__main__":
    main()
