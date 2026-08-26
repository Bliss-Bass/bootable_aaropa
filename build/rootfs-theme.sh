# Overlay source-installer rootfs theming (desktop/session artwork and labels).
# For Bass local builds this applies template files from the Bass installer fork
# on top of the Bliss recipe output so the live rootfs branding is Bass.
# Sourced by aaropa-prebuilt.sh.

aaropa_apply_rootfs_theme() {
  local root src
  root="$1"
  src="${AAROPA_SOURCE_INSTALLER_SRC:-}"
  [[ -n "$src" ]] || return 0
  [[ "$src" != "${AAROPA_INSTALLER_SRC:-}" ]] || return 0

  case "${AAROPA_SOURCE:-}" in
    bass) ;;
    *) return 0 ;;
  esac

  [[ -d "${src}/template" ]] || aaropa_die "source installer has no template dir: $src"
  aaropa_log "overlaying rootfs theme from ${AAROPA_SOURCE} installer template"

  for p in etc/bliss root; do
    if [[ -d "${src}/template/${p}" ]]; then
      mkdir -p "${root}/${p}"
      rsync -a "${src}/template/${p}/" "${root}/${p}/"
    fi
  done

  # OEM installer (Bass template); may include bass_grub.env timeout/security hooks.
  if [[ -f "${src}/template/usr/sbin/oem-install" ]]; then
    mkdir -p "${root}/usr/sbin"
    cp -f "${src}/template/usr/sbin/oem-install" "${root}/usr/sbin/oem-install"
    chmod 755 "${root}/usr/sbin/oem-install"
  fi

  rm -f "${root}/etc/bliss/blissos_logo.png" "${root}/etc/bliss/blissos_logo.svg"
}
