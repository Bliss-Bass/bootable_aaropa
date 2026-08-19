# Fetch Ananda-Aropa GitHub release artifacts into bootable/aaropa.
# Sourced by aaropa-prebuilt.sh after lib.sh. Expects AAROPA_* vars set.

aaropa_resolve_release_tag() {
  local repo tag_pin tag
  repo="$(lock_get_required "fetch.${AAROPA_SOURCE}" github_repo)"
  tag_pin="$(lock_get "fetch.${AAROPA_SOURCE}" tag)"
  tag_pin="${tag_pin:-latest}"
  AAROPA_RELEASE_REPO="$repo"
  if [[ "$tag_pin" == "latest" ]]; then
    tag="$(github_latest_tag "$repo" || true)"
    if [[ -z "$tag" ]]; then
      if aaropa_artifacts_ok "${AAROPA_INITRD_ONLY:-0}"; then
        aaropa_log "could not reach GitHub; keeping existing artifacts"
        AAROPA_RELEASE_TAG="$(tr -d '[:space:]' <"${AAROPA_ROOT}/version.txt" 2>/dev/null || true)"
        return 2
      fi
      aaropa_die "could not determine latest tag for $repo"
    fi
    AAROPA_RELEASE_TAG="$tag"
  else
    AAROPA_RELEASE_TAG="$tag_pin"
  fi
  return 0
}

aaropa_extract_initrd_lib() {
  aaropa_log "extracting initrd_lib.tar.gz"
  tar -xzf "${AAROPA_ROOT}/initrd_lib.tar.gz" -C "$AAROPA_ROOT"
  chmod -R 755 "${AAROPA_ROOT}/initrd_lib"
  rm -f "${AAROPA_ROOT}/initrd_lib.tar.gz"
}

aaropa_extract_grub_rescue() {
  command -v 7z >/dev/null 2>&1 || aaropa_die "7z is required to extract grub-rescue.iso"
  aaropa_log "extracting grub-rescue.iso into iso/"
  mkdir -p "${AAROPA_ROOT}/iso"
  7z x "${AAROPA_ROOT}/grub-rescue.iso" -o"${AAROPA_ROOT}/iso" -y >/dev/null
  rm -f "${AAROPA_ROOT}/grub-rescue.iso"
}

aaropa_fetch_release() {
  local repo tag assets asset url dest initrd_only
  repo="$AAROPA_RELEASE_REPO"
  tag="$AAROPA_RELEASE_TAG"
  initrd_only="${AAROPA_INITRD_ONLY:-0}"
  assets="$(lock_get_required "fetch.${AAROPA_SOURCE}" assets)"

  aaropa_log "fetching $repo@$tag (source=${AAROPA_SOURCE})"

  rm -rf "${AAROPA_ROOT}/initrd_lib"
  if [[ "$initrd_only" != "1" ]]; then
    rm -rf "${AAROPA_ROOT}/iso"
    rm -f "${AAROPA_ROOT}/boot_hybrid.img"
  fi

  for asset in $assets; do
    if [[ "$initrd_only" == "1" && "$asset" != "initrd_lib.tar.gz" ]]; then
      continue
    fi
    dest="${AAROPA_ROOT}/${asset}"
    url="https://github.com/${repo}/releases/download/${tag}/${asset}"
    download_file "$url" "$dest"
    [[ -s "$dest" ]] || aaropa_die "download produced empty file: $dest"
  done

  if [[ -f "${AAROPA_ROOT}/initrd_lib.tar.gz" ]]; then
    aaropa_extract_initrd_lib
  fi

  if [[ "$initrd_only" != "1" ]]; then
    if [[ -f "${AAROPA_ROOT}/grub-rescue.iso" ]]; then
      aaropa_extract_grub_rescue
    fi
    if [[ -f "${AAROPA_ROOT}/install.sfs" ]]; then
      mkdir -p "${AAROPA_ROOT}/iso"
      mv -f "${AAROPA_ROOT}/install.sfs" "${AAROPA_ROOT}/iso/install.sfs"
    fi
  fi

  printf '%s\n' "$tag" >"${AAROPA_ROOT}/version.txt"
  aaropa_artifacts_ok "$initrd_only" || aaropa_die "artifacts missing after fetch"
  aaropa_log "fetch complete ($tag)"
}
