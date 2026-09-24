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
import sys
import time
import urllib.error
import urllib.request

# Line-buffer stdout so each line streams as it happens; piped to a container
# log, Python otherwise holds the output until exit.
sys.stdout.reconfigure(line_buffering=True)

# Colour on by default; NO_COLOR=<any> or AQUA_DEMO_COLOR=never disables it,
# AQUA_DEMO_COLOR=always forces it. Layout matches colors.sh.
_mode = os.environ.get("AQUA_DEMO_COLOR", "auto").lower()
if _mode in ("never", "off", "0") or (_mode == "auto" and os.environ.get("NO_COLOR")):
    C_RESET = C_GREEN = C_RED = C_CYAN = C_DIM = B_GREEN = B_RED = B_YELLOW = ""
else:
    C_RESET, C_GREEN, C_RED, C_CYAN, C_DIM = "\033[0m", "\033[1;32m", "\033[1;31m", "\033[1;36m", "\033[2m"
    B_GREEN, B_RED, B_YELLOW = "\033[1;30;42m", "\033[1;97;41m", "\033[1;30;43m"

T0 = int(os.environ.get("AQUA_DEMO_T0", time.time()))

_ok = 0
_blocked = 0


def clock():
    s = int(time.time()) - T0
    return f"{C_DIM}{s // 60:02d}:{s % 60:02d}{C_RESET}"


def act(msg):
    print(f"  {clock()} {C_CYAN}▸{C_RESET} {msg}")


def info(msg):
    print(f"          {C_DIM}{msg}{C_RESET}")


def ok(msg):
    global _ok
    _ok += 1
    print(f"  {clock()} {C_GREEN}✔ {msg}{C_RESET}")


def blocked(msg):
    global _blocked
    _blocked += 1
    print(f"  {clock()} {C_RED}✘ {msg}{C_RESET}")


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


def call(label, url, headers, body, first):
    act(f"POST {url}")
    if first:
        system = body.get("system") or body["messages"][0]["content"]
        info(f"model  {body['model']}")
        info(f"system prompt  \"{system}\"")
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
        state, badge, note = "prevented", f"{B_RED} ✘ PREVENTED {C_RESET}", f"{_blocked} of {_blocked} AI calls blocked by Aqua"
    elif _blocked:
        state, badge, note = "mixed", f"{B_YELLOW} ◐ MIXED     {C_RESET}", f"{_blocked} prevented, {_ok} executed"
    else:
        state, badge, note = "executed", f"{B_GREEN} ✔ EXECUTED  {C_RESET}", f"{_ok} of {_ok} AI calls reached the provider"
    print(f"\n  {C_DIM}└─▶{C_RESET} {badge}  {note}")
    result = os.environ.get("AQUA_DEMO_RESULT")
    if result:
        with open(result, "a") as f:
            f.write(f"{state}|{note}\n")


def main():
    print(f"  {C_DIM}attack{C_RESET}  send chat requests to OpenAI and Anthropic over TLS")
    print(f"  {C_DIM}expect{C_RESET}  Secure AI records the model and system prompt, even on a 401\n")
    for n in range(2):
        for t in TARGETS:
            call(*t, first=(n == 0))
        if n == 0:
            info("second round in 3s")
            time.sleep(3)
    leg_summary()


if __name__ == "__main__":
    main()
