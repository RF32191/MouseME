#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
AVAIL=$(df -g /System/Volumes/Data | awk 'NR==2 {print $4}')
if [[ "${AVAIL}" -lt 5 ]]; then
  echo "ERROR: Less than 5 GB free (${AVAIL} GB). Clean DerivedData before archiving."
  exit 1
fi
if find "$ROOT/MouseMe" -name '*.py' | grep -q .; then
  echo "ERROR: Remove .py files from MouseMe/ (use Server/ only)"
  exit 1
fi
echo "Pre-upload checks passed (${AVAIL} GB free)."
