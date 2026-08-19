# Overlay Bass install-time Calamares options from vendor aaropa-options.
# Uses the Bliss `options` view module already in the image; replaces its YAML
# catalog with vendor_packages/aaropa-options/boot_options/options.yaml.
# Does not compile aaropa_calamares_modules_bass (presets/bassoptions .so).
# Sourced by aaropa-prebuilt.sh.

aaropa_find_options_yaml() {
  local f
  if [[ -n "${AAROPA_OPTIONS_YAML:-}" ]]; then
    [[ -f "$AAROPA_OPTIONS_YAML" ]] || aaropa_die "AAROPA_OPTIONS_YAML not found: $AAROPA_OPTIONS_YAML"
    printf '%s\n' "$AAROPA_OPTIONS_YAML"
    return 0
  fi
  f="$(lock_get "branding.${AAROPA_BRANDING:-}" options_yaml)"
  if [[ -n "$f" ]]; then
    [[ "$f" == /* ]] || f="${AAROPA_ROOT}/${f}"
    if [[ -f "$f" ]]; then
      printf '%s\n' "$f"
      return 0
    fi
  fi
  f="${AAROPA_ROOT}/../../vendor/ax86-lite/vendor_packages/aaropa-options/boot_options/options.yaml"
  if [[ -f "$f" ]]; then
    printf '%s\n' "$f"
    return 0
  fi
  return 1
}

aaropa_resolve_options_yaml() {
  AAROPA_OPTIONS_YAML_RESOLVED=""
  AAROPA_OPTIONS_YAML_SHA256=""
  case "${AAROPA_BRANDING:-}" in
    bass|bassos) ;;
    *) return 0 ;;
  esac
  AAROPA_OPTIONS_YAML_RESOLVED="$(aaropa_find_options_yaml)" \
    || aaropa_die "Bass install options YAML not found. Set AAROPA_OPTIONS_YAML to vendor aaropa-options/boot_options/options.yaml"
  AAROPA_OPTIONS_YAML_SHA256="$(file_sha256 "$AAROPA_OPTIONS_YAML_RESOLVED")"
  aaropa_log "install options yaml ${AAROPA_OPTIONS_YAML_RESOLVED} (${AAROPA_OPTIONS_YAML_SHA256:0:12})"
}

aaropa_apply_install_options() {
  local root="$1"
  local yaml dest
  [[ -n "${AAROPA_OPTIONS_YAML_RESOLVED:-}" ]] || return 0

  dest="${root}/etc/calamares/modules/options.yaml"
  [[ -f "$dest" ]] || aaropa_die "image has no Calamares options.yaml to overlay"
  yaml="${AAROPA_OPTIONS_YAML_RESOLVED}"
  aaropa_log "overlaying Calamares options catalog from $yaml"
  mkdir -p "$(dirname "$dest")"
  cp -f "$yaml" "$dest"

  # Bass options.conf should keep the known-good Bliss groupsUrl wiring.
  # options.yaml carries the Bass-specific expanded option catalog.
  if [[ -f "${root}/etc/calamares/modules/options.conf" ]]; then
    cat >"${root}/etc/calamares/modules/options.conf" <<'EOF'
# SPDX-FileCopyrightText: no
# SPDX-License-Identifier: CC0-1.0
# sets default options option groups list, first fetches from the net.
# second will be used as fallback if fetching fails
---
groupsUrl:
 - file:///usr/share/calamares/modules/options.yaml
 - file:///etc/calamares/modules/options.yaml

required: true

label:
 sidebar: "Options"
 title: "Additional options"
 subtitle: "WARNING: Check out https://tinyurl.com/4ahpktk4 to know which options to choose.\nDO NOT TRY TO PICK ALL OPTIONS AT ONCE !!!"
EOF
  fi
}
