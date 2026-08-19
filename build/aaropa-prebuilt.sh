#!/usr/bin/env bash
# Aaropa installer pre-build entrypoint.
#
# --local  Build Ananda-Aropa installer image with rootless Podman and emit
#          iso/install.sfs, initrd_lib/, boot_hybrid.img (what Android.mk wants).
# --fetch  Download the matching Ananda-Aropa GitHub release instead.
#
# --source=bliss|bass is an Ananda-Aropa installer flavor, not Bliss-Bass git
# forks. Bass builds on the Bliss-stable Calamares/base; branding overlays
# come from Ananda-Aropa calamares_branding_* (see aaropa.lock).
#
# Environment:
#   AAROPA_SOURCE    bliss|bass (default: lockfile default_source, currently bass)
#   AAROPA_BRANDING  overlay name (recorded in stamp; applied in later steps)
#   AAROPA_REBUILD=1 ignore stamp

set -euo pipefail

AAROPA_BUILD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AAROPA_ROOT="$(cd "${AAROPA_BUILD_DIR}/.." && pwd)"
# shellcheck source=lib.sh
source "${AAROPA_BUILD_DIR}/lib.sh"
# shellcheck source=00-fetch-release.sh
source "${AAROPA_BUILD_DIR}/00-fetch-release.sh"
# shellcheck source=01-fetch-sources.sh
source "${AAROPA_BUILD_DIR}/01-fetch-sources.sh"
# shellcheck source=04-image.sh
source "${AAROPA_BUILD_DIR}/04-image.sh"
# shellcheck source=05-export.sh
source "${AAROPA_BUILD_DIR}/05-export.sh"

AAROPA_MODE="${AAROPA_MODE:-local}"
AAROPA_SOURCE="${AAROPA_SOURCE:-}"
AAROPA_BRANDING="${AAROPA_BRANDING:-}"
AAROPA_REBUILD="${AAROPA_REBUILD:-0}"
AAROPA_INITRD_ONLY="${AAROPA_INITRD_ONLY:-0}"
AAROPA_DRY_RUN="${AAROPA_DRY_RUN:-0}"
AAROPA_CHECK_DEPS="${AAROPA_CHECK_DEPS:-0}"

show_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTION]...

Prepare Aaropa installer prebuilts for Android.mk (iso_img).

Options:
  --local              Build install.sfs locally with rootless Podman (default)
  --fetch              Fetch Ananda-Aropa GitHub release artifacts instead
  --source=bliss|bass  Ananda-Aropa installer flavor (default: ${default_hint})
  --branding=NAME      Ananda-Aropa branding overlay (stamp only until overlays land)
  --rebuild            Ignore stamp and refetch/rebuild
  --initrd-only        Only fetch and extract initrd_lib (--fetch)
  --dry-run            Print stamp and planned action; do not build or download
  --check-deps         Verify fetch + sandbox packages and print apt install if missing
  --help               Show this help and exit

Environment: AAROPA_SOURCE, AAROPA_BRANDING, AAROPA_REBUILD=1
EOF
}

default_hint="$(lock_top_get default_source)"
default_hint="${default_hint:-bass}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      show_help
      exit 0
      ;;
    --fetch)
      AAROPA_MODE=fetch
      shift
      ;;
    --local)
      AAROPA_MODE=local
      shift
      ;;
    --source=*)
      AAROPA_SOURCE="${1#*=}"
      shift
      ;;
    --branding=*)
      AAROPA_BRANDING="${1#*=}"
      shift
      ;;
    --rebuild)
      AAROPA_REBUILD=1
      shift
      ;;
    --initrd-only)
      AAROPA_INITRD_ONLY=1
      shift
      ;;
    --dry-run)
      AAROPA_DRY_RUN=1
      shift
      ;;
    --check-deps)
      AAROPA_CHECK_DEPS=1
      shift
      ;;
    *)
      aaropa_die "unknown option: $1 (see --help)"
      ;;
  esac
done

if [[ -z "$AAROPA_SOURCE" ]]; then
  AAROPA_SOURCE="$(lock_top_get default_source)"
  AAROPA_SOURCE="${AAROPA_SOURCE:-bass}"
fi

case "$AAROPA_SOURCE" in
  bliss|bass) ;;
  *) aaropa_die "--source must be bliss or bass Ananda-Aropa flavor (got '$AAROPA_SOURCE')" ;;
esac

if [[ "$AAROPA_CHECK_DEPS" == "1" ]]; then
  aaropa_check_deps all
  exit $?
fi

cd "$AAROPA_ROOT"

if [[ "$AAROPA_MODE" == "local" ]]; then
  aaropa_check_deps fetch || exit 1
  aaropa_check_deps sandbox || exit 1

  aaropa_fetch_sources

  if [[ "$AAROPA_REBUILD" != "1" ]] && aaropa_artifacts_ok "$AAROPA_INITRD_ONLY" && aaropa_stamp_matches; then
    aaropa_log "stamp matches (local ${AAROPA_SOURCE} ${AAROPA_RELEASE_TAG}); skipping"
    if [[ "$AAROPA_DRY_RUN" == "1" ]]; then
      aaropa_desired_stamp
      echo "action=skip"
    fi
    exit 0
  fi

  if [[ "$AAROPA_DRY_RUN" == "1" ]]; then
    aaropa_desired_stamp
    echo "action=local-build"
    echo "installer_src=${AAROPA_INSTALLER_SRC}"
    echo "image_tag=$(aaropa_image_tag)"
    exit 0
  fi

  aaropa_build_image
  aaropa_export_image
  aaropa_write_stamp
  aaropa_log "done"
  exit 0
fi

# --fetch
if ! aaropa_check_deps fetch; then
  exit 1
fi
if ! aaropa_check_deps sandbox warn; then
  echo "warning: sandbox packages are missing; --fetch can continue, but --local / Podman builds will not" >&2
fi

resolve_status=0
aaropa_resolve_release_tag || resolve_status=$?
if [[ "$resolve_status" -eq 2 ]]; then
  if [[ "$AAROPA_DRY_RUN" == "1" ]]; then
    aaropa_desired_stamp
    echo "action=keep-offline"
    exit 0
  fi
  exit 0
fi

if [[ "$AAROPA_REBUILD" != "1" ]] && aaropa_artifacts_ok "$AAROPA_INITRD_ONLY" && aaropa_stamp_matches; then
  aaropa_log "stamp matches (${AAROPA_SOURCE} ${AAROPA_MODE} ${AAROPA_RELEASE_TAG}); skipping"
  if [[ "$AAROPA_DRY_RUN" == "1" ]]; then
    aaropa_desired_stamp
    echo "action=skip"
  fi
  exit 0
fi

if [[ "$AAROPA_REBUILD" != "1" ]] && aaropa_artifacts_ok "$AAROPA_INITRD_ONLY"; then
  local_ver="$(tr -d '[:space:]' <"${AAROPA_ROOT}/version.txt" 2>/dev/null || true)"
  if [[ -n "$local_ver" && "$local_ver" == "$AAROPA_RELEASE_TAG" ]]; then
    aaropa_log "artifacts already at $local_ver; writing stamp"
    if [[ "$AAROPA_DRY_RUN" == "1" ]]; then
      aaropa_desired_stamp
      echo "action=stamp-only"
      exit 0
    fi
    aaropa_write_stamp
    exit 0
  fi
fi

if [[ "$AAROPA_DRY_RUN" == "1" ]]; then
  aaropa_desired_stamp
  echo "action=fetch"
  exit 0
fi

aaropa_fetch_release
aaropa_write_stamp
aaropa_log "done"
