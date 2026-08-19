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
  fi
  git -C "$dir" fetch origin
  git -C "$dir" checkout --detach "$ref"
}

aaropa_fetch_sources() {
  local recipe url ref brand_url brand_ref installer_short branding_short

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

  brand_url="$(lock_get "branding.${AAROPA_BRANDING}" calamares.url)"
  brand_ref="$(lock_get "branding.${AAROPA_BRANDING}" calamares.ref)"
  if [[ -n "$brand_url" && -n "$brand_ref" ]]; then
    aaropa_git_checkout "$brand_url" "$brand_ref" "${AAROPA_SRC_DIR}/branding"
    AAROPA_BRANDING_SRC="${AAROPA_SRC_DIR}/branding"
  else
    AAROPA_BRANDING_SRC=""
  fi

  installer_short="$(git -C "$AAROPA_INSTALLER_SRC" rev-parse --short=12 HEAD)"
  AAROPA_RELEASE_REPO="$url"
  AAROPA_RELEASE_TAG="$installer_short"
  if [[ -n "${AAROPA_BRANDING_SRC:-}" ]]; then
    branding_short="$(git -C "$AAROPA_BRANDING_SRC" rev-parse --short=12 HEAD)"
    AAROPA_RELEASE_TAG="${installer_short}-${branding_short}"
  fi
  aaropa_log "installer recipe ${recipe} at ${url}@${installer_short}"
  if [[ -n "${AAROPA_BRANDING_SRC:-}" ]]; then
    aaropa_log "branding ${AAROPA_BRANDING} at ${brand_url}@${branding_short}"
  fi
}
