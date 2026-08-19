#!/usr/bin/env bash
# Lunch-time compatibility wrapper.
# Historical download.sh always fetched Ananda-Aropa BlissOS installer releases.
# AAROPA_SOURCE=bass selects the Ananda-Aropa Bass flavor (not Bliss-Bass forks).
# New entrypoint: build/aaropa-prebuilt.sh (default source is bass).
#
# When build.sh --aaropa-local already prepared artifacts, skip so lunch does
# not overwrite a Bass fetch with the BlissOS release.

set -euo pipefail

if [[ "${AAROPA_LOCAL:-0}" == "1" || "${AAROPA_LOCAL:-}" == "true" ]]; then
  echo "Skipping Aaropa download.sh (AAROPA_LOCAL=${AAROPA_LOCAL}); using prebuilts from aaropa-prebuilt.sh"
  exit 0
fi

AAROPA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${AAROPA_ROOT}/build/aaropa-prebuilt.sh" --fetch --source="${AAROPA_SOURCE:-bliss}" "$@"
