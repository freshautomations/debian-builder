#!/bin/bash

# Set strict bash mode and allow debugging.
set -euo pipefail
if [ -n "${DEBUG:-}" ]; then
  set -x
fi

# Input defaults and script variables
NAME="${NAME:-custom}"
MNT="${MNT:-/mnt}"
MEDIA="${MEDIA:-/media}"
TMP="${TMP:-/tmp}"
DEBUG="${DEBUG:-}"
FORCE="${FORCE:-}"
TIMEOUT="${TIMEOUT:-5}"

# Check input parameters and existence of preseed.cfg.
check_input() {
  if [ -z "${VERSION+set}" ]; then
    echo "Error: VERSION is not set. Please set a Debian ISO version number."
    exit 1
  fi
  if [ ! -f "${MNT}/preseed.cfg" ]; then
    echo "Error: missing ${MNT}/preseed.cfg. Please attach a volume to ${MNT}." 1>&2
    exit 1
  fi
}

# Download official Debian netinstall ISO or do nothing if one is already found on the volume.
get_iso() {
if [ ! -f "${MNT}/debian-${VERSION}-amd64-netinst.iso" ]; then
  echo "Downloading https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-${VERSION}-amd64-netinst.iso"
  wget -O "${MNT}/debian-${VERSION}-amd64-netinst.iso" "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-${VERSION}-amd64-netinst.iso"
  wget -O "${MNT}/SHA512SUMS" "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/SHA512SUMS"
  wget -O "${MNT}/SHA512SUMS.sign" "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/SHA512SUMS.sign"
  cd "${MNT}"
  sha512sum --ignore-missing -c SHA512SUMS
  gpg --keyserver keyring.debian.org --auto-key-retrieve --verify SHA512SUMS.sign SHA512SUMS
  if [ -z "${DEBUG}" ]; then
    rm SHA512SUMS.sign SHA512SUMS
  fi
else
  echo "Using existing ISO at ${MNT}/debian-${VERSION}-amd64-netinst.iso"
fi
}

# Unpack ISO
unpack_iso() {
  xorriso -osirrox on -indev "${MNT}/debian-${VERSION}-amd64-netinst.iso" -extract . "${MEDIA}"
}

# Update the MD5 file for existing files. Input: absolute path (Starting with ${MEDIA}).
update_md5() {
      LISTNAME=".${1##${MEDIA}}"
      MD5SUM="$(cd "${MEDIA}" && md5sum "${LISTNAME}")"
      sed -i "s,^[0-9a-f]*  ${LISTNAME}$,${MD5SUM}," "${MEDIA}/md5sum.txt"
}

# Add preseed to all "initrd"s.
# Slightly more convoluted than just copying it to the file system.
# During installation, it is mounted under /mnt/preseed.cfg.
preseed_into_initrd() {
  for i in $(find "${MEDIA}/install.amd" -follow -type f -name initrd.gz)
  do
    gunzip "$i"
    NOGZ="${i%%.gz}"
    echo "${MNT}/preseed.cfg" | cpio -H newc -o -A -F "$NOGZ"
    gzip "$NOGZ"

    update_md5 "$i"
  done
  PRESEED="file=file:///mnt/preseed.cfg"
}

# Add preseed onto the ISO filesystem. Simple solution.
# During installation, it is mounted under /cdrom/preseed.cfg.
preseed_onto_fs() {
  cp "${MNT}/preseed.cfg" "${MEDIA}"
  cd "${MEDIA}" && md5sum "preseed.cfg" >> "${MEDIA}/md5sum.txt"
  PRESEED="file=file:///cdrom/preseed.cfg"
}

# Set default menu entry for UEFI boot
bios_set_default_entry() {
  # FORCE=no: We will add preseed.cfg to only the "Automated install" entries in the boot menu.
  if [ -z "${FORCE}" ]; then
    # Remove menu default choices.
    grep -l "menu default" "${MEDIA}"/isolinux/*.cfg | while IFS= read -r line
    do
      sed -i '/^\tmenu default$/d' "$line"
      sed -i '/^default \(.*\)$/d' "$line"
      update_md5 "$line"
    done
    # Add default choice for automated (label auto*) menu items.
    grep -l "label auto" "${MEDIA}"/isolinux/*.cfg | while IFS= read -r line
    do
        MENUITEM="$(grep "label auto" "$line" | sed 's/.*label //')"
        sed -i '/label '"${MENUITEM}"'/ a default '"${MENUITEM}"'\n    menu default' "$line"
        update_md5 "$line"
    done
    # Open boot menu to advanced options
    sed -i '/^menu begin advanced$/ a menu start' "${MEDIA}"/isolinux/menu.cfg
    update_md5 "${MEDIA}"/isolinux/menu.cfg
    # Add preseed.cfg to automatic installation menu items.
    APPEND="${PRESEED}"
    grep -l "auto=true" "${MEDIA}"/isolinux/*.cfg | while IFS= read -r line
    do
      sed -i 's@auto=true@'"$APPEND auto=true"'@' "$line"
      update_md5 "$line"
    done
  # FORCE=yes: We will add preseed.cfg to all the entries in the boot menu.
  else
    APPEND="${PRESEED} auto=true" #Note: in some menu items "auto=true" will show twice. That's ok.
    for i in "${MEDIA}"/isolinux/*.cfg
    do
      sed -i 's@\---@'"$APPEND ---"'@' "$i"
      update_md5 "$i"
    done
  fi
  # Set boot menu timeout.
  sed -i 's/^timeout .*$/timeout '"${TIMEOUT}0"'/' "${MEDIA}"/isolinux/isolinux.cfg
  update_md5 "${MEDIA}"/isolinux/isolinux.cfg
}

uefi_set_default_entry() {
  # FORCE=no: We will add preseed.cfg to only the "Automated install" entries in the boot menu.
  if [ -z "${FORCE}" ]; then
    # Add preseed.cfg to automatic installation menu items.
    APPEND="${PRESEED}"
    sed -i 's@auto=true@'"$APPEND auto=true"'@' "${MEDIA}"/boot/grub/grub.cfg
    # Set default entry and timeout
    sed -i '/insmod play/ a default='\'"2"\''\ntimeout='"${TIMEOUT}"'' "${MEDIA}"/boot/grub/grub.cfg
    sed -i '/submenu.*Advanced options/ a default=2' "${MEDIA}"/boot/grub/grub.cfg
    sed -i '/submenu.*Speech-enabled advanced options/ a default=2' "${MEDIA}"/boot/grub/grub.cfg
    sed -i '/submenu.*Accessible dark contrast installer menu/ a default=2' "${MEDIA}"/boot/grub/grub.cfg
    update_md5 "${MEDIA}"/boot/grub/grub.cfg
  # FORCE=yes: We will add preseed.cfg to all the entries in the boot menu.
  else
    APPEND="${PRESEED} auto=true" #Note: in some menu items "auto=true" will show twice. That's ok.
    sed -i 's@\---@'"$APPEND ---"'@' "${MEDIA}"/boot/grub/grub.cfg
    sed -i '/insmod play/ a timeout='"${TIMEOUT}"'' "${MEDIA}"/boot/grub/grub.cfg
    update_md5 "${MEDIA}"/boot/grub/grub.cfg
  fi
}

# Build ISO using the previous build command with some simplifications.
build_iso() {
  dd if="${MNT}/debian-${VERSION}-amd64-netinst.iso" bs=1 count=432 of="${TMP}/isohdpfx.bin"
  sed \
      -e 's/-jigdo-[^ ]* [^ ]* //g' \
      -e 's/-checksum_algorithm_iso [^ ]* //' \
      -e 's/-checksum-list [^ ]* //' \
      -e 's,-isohybrid-mbr [^ ]* ,-isohybrid-mbr '"${TMP}"'/isohdpfx.bin ,' \
      -e 's/ CD1//' \
      -e 's, boot1, '"${MEDIA}"',' \
      -e 's,-o [^ ]*,-o "'"${MNT}"'/debian-'"${VERSION}"'-amd64-'"${NAME}"'.iso",' < "${MEDIA}/.disk/mkisofs" > "${TMP}/mkiso"
  chmod 755 "${TMP}/mkiso"
  "${TMP}/mkiso"
  if [ -z "${DEBUG}" ]; then
    rm "${TMP}/mkiso"
  fi
}

check_input
get_iso
unpack_iso
preseed_onto_fs
bios_set_default_entry
uefi_set_default_entry
build_iso
echo "debian-${VERSION}-amd64-${NAME}.iso created."
