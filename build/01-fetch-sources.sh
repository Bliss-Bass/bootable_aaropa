# Clone/update Ananda-Aropa installer recipe + branding overlay into .src/.
# Sourced by aaropa-prebuilt.sh after lib.sh.

aaropa_git_checkout() {
  local url="$1" ref="$2" dir="$3"
  command -v git >/dev/null 2>&1 || aaropa_die "git is required to clone installer sources"
  mkdir -p "$(dirname "$dir")"

  if [[ ! -d "${dir}/.git" ]]; then
    aaropa_log "cloning $url into $dir"
    git clone "$url" "$dir"
  else
    aaropa_log "updating $dir"
    git -C "$dir" remote set-url origin "$url"
    # Drop local edits (vendor patches are re-applied after fetch) so --rebuild
    # cannot abort on "local changes would be overwritten by checkout".
    git -C "$dir" reset --hard HEAD >/dev/null 2>&1 || true
    git -C "$dir" clean -fd >/dev/null 2>&1 || true
  fi
  git -C "$dir" fetch origin
  git -C "$dir" checkout -f --detach "$ref"
}

aaropa_fetch_sources() {
  local recipe url ref brand_url brand_ref installer_short branding_short source_url source_ref source_short

  if [[ -z "${AAROPA_BRANDING:-}" ]]; then
    AAROPA_BRANDING="$(lock_get "flavor.${AAROPA_SOURCE}" branding)"
    AAROPA_BRANDING="${AAROPA_BRANDING:-$AAROPA_SOURCE}"
  fi

  recipe="$(lock_get "flavor.${AAROPA_SOURCE}" image_from)"
  recipe="${recipe:-$AAROPA_SOURCE}"
  AAROPA_IMAGE_RECIPE="$recipe"

  url="$(lock_get_required "flavor.${recipe}" installer.url)"
  ref="$(lock_get_required "flavor.${recipe}" installer.ref)"
  aaropa_git_checkout "$url" "$ref" "${AAROPA_SRC_DIR}/installer"
  AAROPA_INSTALLER_SRC="${AAROPA_SRC_DIR}/installer"
  AAROPA_SOURCE_INSTALLER_SRC="$AAROPA_INSTALLER_SRC"

  brand_url="$(lock_get "branding.${AAROPA_BRANDING}" calamares.url)"
  brand_ref="$(lock_get "branding.${AAROPA_BRANDING}" calamares.ref)"
  if [[ -n "$brand_url" && -n "$brand_ref" ]]; then
    aaropa_git_checkout "$brand_url" "$brand_ref" "${AAROPA_SRC_DIR}/branding"
    AAROPA_BRANDING_SRC="${AAROPA_SRC_DIR}/branding"
  else
    AAROPA_BRANDING_SRC=""
  fi

  if [[ "$recipe" != "$AAROPA_SOURCE" ]]; then
    source_url="$(lock_get_required "flavor.${AAROPA_SOURCE}" installer.url)"
    source_ref="$(lock_get_required "flavor.${AAROPA_SOURCE}" installer.ref)"
    aaropa_git_checkout "$source_url" "$source_ref" "${AAROPA_SRC_DIR}/installer-source"
    AAROPA_SOURCE_INSTALLER_SRC="${AAROPA_SRC_DIR}/installer-source"
    source_short="$(git -C "$AAROPA_SOURCE_INSTALLER_SRC" rev-parse --short=12 HEAD)"
  else
    source_url="$url"
    source_short=""
  fi

  installer_short="$(git -C "$AAROPA_INSTALLER_SRC" rev-parse --short=12 HEAD)"
  AAROPA_RELEASE_REPO="$url"
  AAROPA_RELEASE_TAG="$installer_short"
  if [[ -n "$source_short" ]]; then
    AAROPA_RELEASE_TAG="${AAROPA_RELEASE_TAG}-${source_short}"
  fi
  if [[ -n "${AAROPA_BRANDING_SRC:-}" ]]; then
    branding_short="$(git -C "$AAROPA_BRANDING_SRC" rev-parse --short=12 HEAD)"
    AAROPA_RELEASE_TAG="${AAROPA_RELEASE_TAG}-${branding_short}"
  fi
  aaropa_log "installer recipe ${recipe} at ${url}@${installer_short}"
  if [[ -n "$source_short" ]]; then
    aaropa_log "source overlay ${AAROPA_SOURCE} at ${source_url}@${source_short}"
  fi
  if [[ -n "${AAROPA_BRANDING_SRC:-}" ]]; then
    aaropa_log "branding ${AAROPA_BRANDING} at ${brand_url}@${branding_short}"
  fi
}
