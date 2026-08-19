# Clone/update the Ananda-Aropa installer flavor repo into .src/installer.
# Sourced by aaropa-prebuilt.sh after lib.sh.

aaropa_fetch_sources() {
  local url ref dir
  url="$(lock_get_required "flavor.${AAROPA_SOURCE}" installer.url)"
  ref="$(lock_get_required "flavor.${AAROPA_SOURCE}" installer.ref)"
  dir="${AAROPA_SRC_DIR}/installer"

  command -v git >/dev/null 2>&1 || aaropa_die "git is required to clone installer sources"
  mkdir -p "$AAROPA_SRC_DIR"

  if [[ ! -d "${dir}/.git" ]]; then
    aaropa_log "cloning $url into $dir"
    git clone "$url" "$dir"
  else
    aaropa_log "updating installer sources in $dir"
    git -C "$dir" remote set-url origin "$url"
  fi
  git -C "$dir" fetch origin
  git -C "$dir" checkout --detach "$ref"

  AAROPA_INSTALLER_SRC="$dir"
  AAROPA_RELEASE_REPO="$url"
  AAROPA_RELEASE_TAG="$(git -C "$dir" rev-parse --short=12 HEAD)"
  aaropa_log "installer sources at ${AAROPA_RELEASE_REPO}@${AAROPA_RELEASE_TAG}"
}
