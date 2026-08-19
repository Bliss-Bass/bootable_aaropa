# Export the installer container and produce Android.mk artifacts without sudo.
# Mirrors Ananda-Aropa extract-rootfs.yml, using podman unshare instead of sudo chown.
# Sourced by aaropa-prebuilt.sh.

aaropa_export_image() {
  local runtime tag work cid helper
  runtime="${AAROPA_RUNTIME:-$(aaropa_detect_runtime)}" || aaropa_die "need podman or docker"
  tag="${AAROPA_IMAGE_TAG:-$(aaropa_image_tag)}"
  work="${AAROPA_CACHE_DIR}/rootfs"
  helper="usr/lib/dbus-1.0/dbus-daemon-launch-helper"

  rm -rf "$work"
  mkdir -p "${work}/install" "${work}/out"

  aaropa_log "exporting $tag"
  cid="$("$runtime" create "$tag")"
  "$runtime" export "$cid" | tar -C "${work}/install" -p -x
  "$runtime" rm "$cid" >/dev/null

  if [[ "$runtime" != "podman" ]]; then
    aaropa_die "local export currently requires podman unshare (no sudo). Install podman or use --fetch"
  fi

  aaropa_log "creating install.sfs (podman unshare, no sudo)"
  podman unshare bash -c '
    set -euo pipefail
    install_dir="$1"
    out_dir="$2"
    helper="$3"
    cd "$install_dir"
    rm -rf .dockerenv
    if [[ -f grub-rescue.iso ]]; then
      mv -f grub-rescue.iso "$out_dir/grub-rescue.iso"
    fi
    if [[ -f usr/lib/grub/i386-pc/boot_hybrid.img ]]; then
      cp -f usr/lib/grub/i386-pc/boot_hybrid.img "$out_dir/boot_hybrid.img"
    fi
    if [[ -f initrd_lib.tar.gz ]]; then
      cp -f initrd_lib.tar.gz "$out_dir/initrd_lib.tar.gz"
    fi
    if [[ -e "$helper" ]]; then
      chown 0:101 "$helper" 2>/dev/null || chown 0:0 "$helper"
      chmod 4754 "$helper"
    fi
    rm -rf initrd_lib initrd_lib.tar.gz install_lib install_lib.tar.gz
    mksquashfs "$install_dir" "$out_dir/install.sfs" -noappend -comp zstd -force-uid 0 -force-gid 0
  ' bash "${work}/install" "${work}/out" "$helper"

  [[ -s "${work}/out/install.sfs" ]] || aaropa_die "mksquashfs did not produce install.sfs"
  [[ -s "${work}/out/initrd_lib.tar.gz" ]] || aaropa_die "initrd_lib.tar.gz missing from exported image"
  [[ -s "${work}/out/boot_hybrid.img" ]] || aaropa_die "boot_hybrid.img missing from exported image"
  [[ -s "${work}/out/grub-rescue.iso" ]] || aaropa_die "grub-rescue.iso missing from exported image"

  aaropa_log "installing artifacts into ${AAROPA_ROOT}"
  rm -rf "${AAROPA_ROOT}/iso" "${AAROPA_ROOT}/initrd_lib"
  rm -f "${AAROPA_ROOT}/boot_hybrid.img"
  mkdir -p "${AAROPA_ROOT}/iso"

  mv -f "${work}/out/install.sfs" "${AAROPA_ROOT}/iso/install.sfs"
  mv -f "${work}/out/boot_hybrid.img" "${AAROPA_ROOT}/boot_hybrid.img"
  command -v 7z >/dev/null 2>&1 || aaropa_die "7z is required to extract grub-rescue.iso"
  7z x "${work}/out/grub-rescue.iso" -o"${AAROPA_ROOT}/iso" -y >/dev/null
  tar -xzf "${work}/out/initrd_lib.tar.gz" -C "$AAROPA_ROOT"
  chmod -R 755 "${AAROPA_ROOT}/initrd_lib"

  printf 'local-%s\n' "${AAROPA_RELEASE_TAG}" >"${AAROPA_ROOT}/version.txt"
  aaropa_artifacts_ok "${AAROPA_INITRD_ONLY:-0}" || aaropa_die "artifacts missing after local export"
  aaropa_log "local image export complete (${AAROPA_RELEASE_TAG})"
}
