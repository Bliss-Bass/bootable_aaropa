# Shared helpers for Aaropa pre-build scripts.
# Sourced from aaropa-prebuilt.sh; not meant to be run directly.

if [[ -z "${AAROPA_ROOT:-}" ]]; then
  echo "lib.sh: AAROPA_ROOT is not set" >&2
  return 1 2>/dev/null || exit 1
fi

AAROPA_LOCK="${AAROPA_LOCK:-${AAROPA_ROOT}/aaropa.lock}"
AAROPA_CACHE_DIR="${AAROPA_CACHE_DIR:-${AAROPA_ROOT}/.cache}"
AAROPA_STAMP_FILE="${AAROPA_STAMP_FILE:-${AAROPA_CACHE_DIR}/aaropa-prebuilt.stamp}"
AAROPA_SRC_DIR="${AAROPA_SRC_DIR:-${AAROPA_ROOT}/.src}"

aaropa_die() {
  echo "error: $*" >&2
  exit 1
}

aaropa_log() {
  echo "==> $*"
}

# lock_get SECTION KEY  -> prints value (empty if missing)
lock_get() {
  local section="$1" key="$2"
  [[ -f "$AAROPA_LOCK" ]] || aaropa_die "lockfile not found: $AAROPA_LOCK"
  awk -v sec="$section" -v want="$key" '
    BEGIN { insec = 0 }
    /^[[:space:]]*(#|$)/ { next }
    /^\[/ {
      gsub(/[[:space:]]/, "")
      gsub(/[\[\]]/, "")
      insec = ($0 == sec)
      next
    }
    insec {
      eq = index($0, "=")
      if (eq < 1) next
      k = substr($0, 1, eq - 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", k)
      if (k == want) {
        v = substr($0, eq + 1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
        print v
        exit
      }
    }
  ' "$AAROPA_LOCK"
}

lock_get_required() {
  local section="$1" key="$2" val
  val="$(lock_get "$section" "$key")"
  [[ -n "$val" ]] || aaropa_die "missing ${section}.${key} in $AAROPA_LOCK"
  printf '%s\n' "$val"
}

lock_top_get() {
  local key="$1"
  [[ -f "$AAROPA_LOCK" ]] || aaropa_die "lockfile not found: $AAROPA_LOCK"
  awk -v want="$key" '
    /^[[:space:]]*(#|$)/ { next }
    /^\[/ { exit }
    {
      eq = index($0, "=")
      if (eq < 1) next
      k = substr($0, 1, eq - 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", k)
      if (k == want) {
        v = substr($0, eq + 1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
        print v
        exit
      }
    }
  ' "$AAROPA_LOCK"
}

file_sha256() {
  sha256sum "$1" | awk '{print $1}'
}

scripts_sha256() {
  local f
  {
    for f in \
      "${AAROPA_ROOT}/build/aaropa-prebuilt.sh" \
      "${AAROPA_ROOT}/build/lib.sh" \
      "${AAROPA_ROOT}/build/00-fetch-release.sh" \
      "${AAROPA_ROOT}/build/01-fetch-sources.sh" \
      "${AAROPA_ROOT}/build/04-image.sh" \
      "${AAROPA_ROOT}/build/05-export.sh"
    do
      [[ -f "$f" ]] && file_sha256 "$f"
    done
  } | sha256sum | awk '{print $1}'
}

lock_sha256() {
  file_sha256 "$AAROPA_LOCK"
}

aaropa_artifacts_ok() {
  local initrd_only="${1:-0}"
  [[ -d "${AAROPA_ROOT}/initrd_lib" ]] || return 1
  [[ -n "$(find "${AAROPA_ROOT}/initrd_lib" -mindepth 1 -maxdepth 1 -printf '.' -quit)" ]] || return 1
  if [[ "$initrd_only" != "1" ]]; then
    [[ -f "${AAROPA_ROOT}/boot_hybrid.img" ]] || return 1
    [[ -d "${AAROPA_ROOT}/iso" ]] || return 1
    [[ -f "${AAROPA_ROOT}/iso/install.sfs" ]] || return 1
    [[ -f "${AAROPA_ROOT}/iso/boot/grub/grub.cfg" ]] || return 1
  fi
  return 0
}

# Writes stamp fields to stdout (stable key=value order).
aaropa_desired_stamp() {
  cat <<EOF
lock_sha256=$(lock_sha256)
scripts_sha256=$(scripts_sha256)
source=${AAROPA_SOURCE}
branding=${AAROPA_BRANDING:-}
mode=${AAROPA_MODE}
release_tag=${AAROPA_RELEASE_TAG:-}
release_repo=${AAROPA_RELEASE_REPO:-}
initrd_only=${AAROPA_INITRD_ONLY:-0}
EOF
}

aaropa_stamp_matches() {
  [[ -f "$AAROPA_STAMP_FILE" ]] || return 1
  local desired tmp
  tmp="$(mktemp)"
  aaropa_desired_stamp >"$tmp"
  if cmp -s "$AAROPA_STAMP_FILE" "$tmp"; then
    rm -f "$tmp"
    return 0
  fi
  rm -f "$tmp"
  return 1
}

aaropa_write_stamp() {
  mkdir -p "$AAROPA_CACHE_DIR"
  aaropa_desired_stamp >"$AAROPA_STAMP_FILE"
  aaropa_log "wrote stamp $AAROPA_STAMP_FILE"
}

# HTTP GET to stdout. Prefers curl, then wget.
http_get() {
  local url="$1"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$url"
  else
    aaropa_die "need curl or wget"
  fi
}

github_latest_tag() {
  local repo="$1" json tag
  json="$(http_get "https://api.github.com/repos/${repo}/releases/latest" || true)"
  [[ -n "$json" ]] || return 1
  tag="$(printf '%s\n' "$json" | grep -m1 '"tag_name":' | sed -E 's/.*"tag_name":[[:space:]]*"([^"]+)".*/\1/')"
  [[ -n "$tag" && "$tag" != "$json" ]] || return 1
  printf '%s\n' "$tag"
}

download_file() {
  local url="$1" dest="$2"
  aaropa_log "downloading $(basename "$dest")"
  if command -v aria2c >/dev/null 2>&1; then
    aria2c -x 16 -s 16 --allow-overwrite=true --auto-file-renaming=false -d "$(dirname "$dest")" -o "$(basename "$dest")" "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$dest" "$url"
  elif command -v curl >/dev/null 2>&1; then
    curl -fL --retry 3 -o "$dest" "$url"
  else
    aaropa_die "need aria2c, wget, or curl"
  fi
}

# Rootless container runtime for later local image builds. No sudo.
aaropa_detect_runtime() {
  if command -v podman >/dev/null 2>&1; then
    printf '%s\n' "podman"
    return 0
  fi
  if command -v docker >/dev/null 2>&1; then
    if docker info >/dev/null 2>&1; then
      printf '%s\n' "docker"
      return 0
    fi
  fi
  return 1
}

aaropa_have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

aaropa_need_pkg() {
  local pkg="$1" seen
  for seen in "${AAROPA_MISSING_PKGS[@]+"${AAROPA_MISSING_PKGS[@]}"}"; do
    [[ "$seen" == "$pkg" ]] && return 0
  done
  AAROPA_MISSING_PKGS+=("$pkg")
}

aaropa_need_cmd() {
  local cmd="$1" pkg="$2"
  if aaropa_have_cmd "$cmd"; then
    return 0
  fi
  AAROPA_MISSING_CMDS+=("$cmd")
  aaropa_need_pkg "$pkg"
  return 1
}

aaropa_host_issue() {
  AAROPA_MISSING_HOST+=("$1")
}

# Collect missing Ubuntu/Debian packages for fetch and/or sandbox (Podman) paths.
# Does not run sudo. Prints a single apt install line when packages are missing.
# Usage: aaropa_check_deps fetch|sandbox|all [error|warn]
# Returns 1 if required items are missing.
aaropa_check_deps() {
  local scope="${1:-fetch}"
  local severity="${2:-error}"
  AAROPA_MISSING_PKGS=()
  AAROPA_MISSING_CMDS=()
  AAROPA_MISSING_HOST=()

  if [[ "$scope" != "fetch" && "$scope" != "sandbox" && "$scope" != "all" ]]; then
    aaropa_die "aaropa_check_deps: scope must be fetch, sandbox, or all"
  fi

  if [[ "$scope" == "fetch" || "$scope" == "all" ]]; then
    if ! aaropa_have_cmd curl && ! aaropa_have_cmd wget; then
      AAROPA_MISSING_CMDS+=("curl|wget")
      aaropa_need_pkg curl
    fi
    aaropa_need_cmd 7z p7zip-full || true
    aaropa_need_cmd tar tar || true
    aaropa_need_cmd sha256sum coreutils || true
  fi

  if [[ "$scope" == "sandbox" || "$scope" == "all" ]]; then
    if aaropa_have_cmd podman; then
      aaropa_need_cmd newuidmap uidmap || true
      aaropa_need_cmd newgidmap uidmap || true
      aaropa_need_cmd slirp4netns slirp4netns || true
      aaropa_need_cmd fuse-overlayfs fuse-overlayfs || true
    elif aaropa_have_cmd docker; then
      :
    else
      AAROPA_MISSING_CMDS+=("podman")
      aaropa_need_pkg podman
      aaropa_need_pkg uidmap
      aaropa_need_pkg slirp4netns
      aaropa_need_pkg fuse-overlayfs
    fi
    aaropa_need_cmd mksquashfs squashfs-tools || true
    aaropa_need_cmd git git || true
    aaropa_need_cmd rsync rsync || true

    local userns subuid_line
    userns="$(cat /proc/sys/kernel/unprivileged_userns_clone 2>/dev/null || echo 1)"
    if [[ "$userns" == "0" ]]; then
      aaropa_host_issue "unprivileged user namespaces are disabled (kernel.unprivileged_userns_clone=0)"
    fi
    subuid_line="$(grep -E "^${USER}:" /etc/subuid 2>/dev/null || true)"
    if [[ -z "$subuid_line" ]]; then
      aaropa_host_issue "no /etc/subuid entry for ${USER} (needed for rootless Podman)"
    fi
    if [[ ! -f /etc/subgid ]] || ! grep -qE "^${USER}:" /etc/subgid 2>/dev/null; then
      aaropa_host_issue "no /etc/subgid entry for ${USER} (needed for rootless Podman)"
    fi
  fi

  if [[ ${#AAROPA_MISSING_CMDS[@]} -eq 0 && ${#AAROPA_MISSING_PKGS[@]} -eq 0 && ${#AAROPA_MISSING_HOST[@]} -eq 0 ]]; then
    aaropa_log "dependencies ok (${scope})"
    return 0
  fi

  echo "${severity}: missing Aaropa ${scope} dependencies" >&2
  if [[ ${#AAROPA_MISSING_CMDS[@]} -gt 0 ]]; then
    echo "  missing commands: ${AAROPA_MISSING_CMDS[*]}" >&2
  fi
  if [[ ${#AAROPA_MISSING_PKGS[@]} -gt 0 ]]; then
    echo "  install with:" >&2
    echo "    sudo apt install -y ${AAROPA_MISSING_PKGS[*]}" >&2
  fi
  if [[ ${#AAROPA_MISSING_HOST[@]} -gt 0 ]]; then
    local issue
    echo "  host configuration (not an apt package):" >&2
    for issue in "${AAROPA_MISSING_HOST[@]}"; do
      echo "    - $issue" >&2
    done
  fi
  return 1
}
