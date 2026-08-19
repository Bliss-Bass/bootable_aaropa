# podman (preferred) or docker build of the Ananda-Aropa installer Dockerfile.
# Sourced by aaropa-prebuilt.sh. No sudo.
# Bass local builds use the Bliss installer context with the Bass GRUB theme
# swapped in a throwaway copy so .src/installer stays a clean git checkout.

aaropa_image_tag() {
  printf 'localhost/aaropa-installer-%s:local\n' "${AAROPA_SOURCE}"
}

aaropa_prepare_build_context() {
  local recipe_src ctx want_grub pkglist
  recipe_src="${AAROPA_INSTALLER_SRC:?}"
  [[ -f "${recipe_src}/Dockerfile" ]] || aaropa_die "no Dockerfile in $recipe_src"
  ctx="${AAROPA_CACHE_DIR}/buildctx"
  pkglist="${ctx}/packages/pkglist.cfg"

  rm -rf "$ctx"
  mkdir -p "$AAROPA_CACHE_DIR"
  rsync -a --delete --exclude .git "$recipe_src/" "$ctx/"

  want_grub="$(lock_get "flavor.${AAROPA_BRANDING:-$AAROPA_SOURCE}" grub_theme_pkg)"
  if [[ -z "$want_grub" ]]; then
    want_grub="$(lock_get "flavor.${AAROPA_SOURCE}" grub_theme_pkg)"
  fi
  if [[ -n "$want_grub" && -f "$pkglist" ]]; then
    if grep -qE '^grub-theme-' "$pkglist"; then
      sed -i -E "s/^grub-theme-.*/${want_grub}/" "$pkglist"
    else
      printf '\n%s\n' "$want_grub" >>"$pkglist"
    fi
    aaropa_log "pkglist grub theme: $want_grub"
  fi
  AAROPA_BUILD_CTX="$ctx"
}

aaropa_build_image() {
  local runtime src tag
  runtime="$(aaropa_detect_runtime)" || aaropa_die "need podman or a working docker (see --check-deps)"
  aaropa_prepare_build_context
  src="${AAROPA_BUILD_CTX:?}"
  [[ -f "${src}/Dockerfile" ]] || aaropa_die "no Dockerfile in $src"
  tag="$(aaropa_image_tag)"
  AAROPA_RUNTIME="$runtime"
  AAROPA_IMAGE_TAG="$tag"

  aaropa_log "building $tag with $runtime (FROM ghcr.io/ananda-aropa/aaropa_rootfs_base)"
  (
    cd "$src"
    "$runtime" build -f Dockerfile -t "$tag" .
  )
}
