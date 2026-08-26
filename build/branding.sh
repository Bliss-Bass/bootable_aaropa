# Overlay Ananda-Aropa Calamares branding onto an exported installer rootfs.
# Look: branding dir, welcome strings, branding: key. GRUB theme is swapped in
# the image pkglist. Install-time option catalogs are applied by options.sh.
# Sourced by aaropa-prebuilt.sh.

aaropa_apply_branding() {
  local root="$1"
  local src settings component desc welcome

  [[ -n "${AAROPA_BRANDING:-}" ]] || return 0
  case "$AAROPA_BRANDING" in
    bliss|blissos)
      aaropa_log "keeping in-image Bliss Calamares branding"
      return 0
      ;;
  esac

  [[ -n "${AAROPA_BRANDING_SRC:-}" ]] || aaropa_die "branding ${AAROPA_BRANDING} requested but sources were not cloned"
  src="${AAROPA_BRANDING_SRC}/calamares"
  [[ -d "${src}/branding" ]] || aaropa_die "no calamares/branding in ${AAROPA_BRANDING_SRC}"

  # Current Ananda-Aropa Calamares settings live in /etc/calamares (not /usr/share).
  settings="${root}/etc/calamares/settings.conf"
  [[ -f "$settings" ]] || aaropa_die "image has no /etc/calamares/settings.conf; Bass local builds need the Bliss installer recipe (flavor.bass.image_from=bliss)"

  aaropa_log "overlaying Calamares branding ${AAROPA_BRANDING}"
  mkdir -p "${root}/etc/calamares"
  rsync -a "${src}/branding/" "${root}/etc/calamares/branding/"

  # Vendor grublock patches live in calamares/scripts/ (e.g. 10_blissos).
  if [[ -d "${src}/scripts" ]]; then
    mkdir -p "${root}/etc/calamares/scripts" "${root}/usr/share/calamares/scripts"
    rsync -a "${src}/scripts/" "${root}/etc/calamares/scripts/"
    rsync -a "${src}/scripts/" "${root}/usr/share/calamares/scripts/"
  fi

  component="$(lock_get "branding.${AAROPA_BRANDING}" component)"
  if [[ -z "$component" ]]; then
    desc="$(find "${src}/branding" -name branding.desc -print -quit || true)"
    if [[ -n "$desc" ]]; then
      component="$(awk '/^componentName:/{print $2; exit}' "$desc")"
    fi
  fi
  component="${component:-bassos}"
  sed -i -E "s/^branding:.*/branding: ${component}/" "$settings"
  find "${root}/etc/calamares/branding" -mindepth 1 -maxdepth 1 -type d ! -name "$component" -exec rm -rf {} +

  mkdir -p "${root}/etc/calamares/modules"
  for welcome in welcome.conf welcomeq.conf bootcfg.conf; do
    if [[ -f "${src}/modules/${welcome}" ]]; then
      cp -f "${src}/modules/${welcome}" "${root}/etc/calamares/modules/"
    fi
  done
}

aaropa_restore_vfs_dirs() {
  local root="$1"
  mkdir -p "${root}/dev" "${root}/proc" "${root}/sys" "${root}/run" "${root}/tmp"
  chmod 1777 "${root}/tmp"
}
