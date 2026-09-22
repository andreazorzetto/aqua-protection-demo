#!/usr/bin/env bash
# Drift Prevention leg.
# Drift = executing something that was NOT part of the original image. We create
# a brand-new executable at runtime and run it. With a runtime policy that has
# "Executables blocked" / drift prevention enabled, this raises a drift incident
# (and is blocked if the policy is set to enforce).
set -uo pipefail

# shellcheck source=colors.sh
. "$(dirname "$0")/colors.sh"

target="/tmp/not-in-the-image.sh"

cat > "${target}" <<'EOF'
#!/bin/sh
echo "I am a binary that did not exist in the image — this is drift."
EOF

chmod +x "${target}"
info "Executing runtime-created binary: ${target}"
attempt "runtime-created binary ${target}" "${target}"
leg_summary
