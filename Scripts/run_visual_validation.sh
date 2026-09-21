#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export LUMORA_VISUAL_FULL="${LUMORA_VISUAL_FULL:-1}"
exec swift test -c release --filter LumoraVisualTestLab
