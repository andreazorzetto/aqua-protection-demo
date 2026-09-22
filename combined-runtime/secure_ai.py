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

Colour semantics match the shell legs (see colors.sh): a call that reaches the
provider (any HTTP status, even 401) is EXECUTED (green); a connection reset /
error means Secure AI enforced and PREVENTED the outbound call (red).
"""
import json
import os
import ssl
import time
import urllib.error
import urllib.request

# Colour on by default; NO_COLOR=<any> or AQUA_DEMO_COLOR=never disables it,
# AQUA_DEMO_COLOR=always forces it.
_mode = os.environ.get("AQUA_DEMO_COLOR", "auto").lower()
if _mode in ("never", "off", "0") or (_mode == "auto" and os.environ.get("NO_COLOR")):
    C_RESET = C_GREEN = C_RED = C_DIM = ""
else:
    C_RESET, C_GREEN, C_RED, C_DIM = "\033[0m", "\033[1;32m", "\033[1;31m", "\033[2m"

_ok = 0
_blocked = 0


def info(msg):
    print(f"{C_DIM}{msg}{C_RESET}")


def ok(msg):
    global _ok
    _ok += 1
    print(f"{C_GREEN}  ✔ {msg}{C_RESET}")


def blocked(msg):
    global _blocked
    _blocked += 1
    print(f"{C_RED}  ✘ {msg}{C_RESET}")


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
            ok(f"{label}: outbound TLS AI call reached provider (HTTP {r.status})")
    except urllib.error.HTTPError as e:
        # A status code means the request left the container and was answered —
        # the AI call fired. Expected (e.g. 401) without a real key.
        ok(f"{label}: outbound TLS AI call reached provider (HTTP {e.code}, no valid key)")
    except Exception as e:  # noqa: BLE001
        # No response at all -> the connection was cut before it completed.
        blocked(f"{label}: outbound TLS AI call prevented ({type(e).__name__})")


def leg_summary():
    if _blocked and not _ok:
        print(f"{C_RED}  → {_blocked} prevented, 0 executed — Aqua blocked this leg{C_RESET}")
    elif _blocked:
        print(f"{C_GREEN}  → {_ok} executed{C_RESET}, {C_RED}{_blocked} prevented{C_RESET}")
    else:
        print(f"{C_GREEN}  → {_ok} executed, 0 prevented — nothing stopped this leg{C_RESET}")


def main():
    info("Issuing outbound TLS requests to AI providers...")
    for _ in range(2):
        for t in TARGETS:
            call(*t)
        time.sleep(3)
    leg_summary()


if __name__ == "__main__":
    main()
