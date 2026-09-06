#!/usr/bin/env bash
set -euo pipefail
exec uv run --script "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/shaping-ripple.py"
