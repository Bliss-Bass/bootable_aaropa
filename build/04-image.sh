# podman (preferred) or docker build of the Ananda-Aropa installer Dockerfile.
# Sourced by aaropa-prebuilt.sh. No sudo.

aaropa_image_tag() {
  printf 'localhost/aaropa-installer-%s:local\n' "${AAROPA_SOURCE}"
}

aaropa_build_image() {
  local runtime src tag
  runtime="$(aaropa_detect_runtime)" || aaropa_die "need podman or a working docker (see --check-deps)"
  src="${AAROPA_INSTALLER_SRC:?}"
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
