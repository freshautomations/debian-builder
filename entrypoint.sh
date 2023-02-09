#!/bin/bash

# Set strict bash mode and allow debugging.
set -euo pipefail
if [ -n "${DEBUG:-}" ]; then
  set -x
fi

# Check if a volume was mounted with preseed.cfg.
if [ ! -f "/mnt/preseed.cfg" ]; then
  echo "Error: missing /mnt/preseed.cfg. Please attach a volume to /mnt." 1>&2
  exit 1
fi

# Download ISO
if [ ! -f "/mnt/debian-$VERSION-amd64-netinst.iso" ]; then
  echo "Downloading https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-$VERSION-amd64-netinst.iso"
  wget -O "/mnt/debian-$VERSION-amd64-netinst.iso" "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-$VERSION-amd64-netinst.iso"
  wget -O "/mnt/SHA512SUMS" "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/SHA512SUMS"
  wget -O "/mnt/SHA512SUMS.sign" "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/SHA512SUMS.sign"
  cd /mnt
  sha512sum --ignore-missing -c SHA512SUMS
  gpg --keyserver keyring.debian.org --auto-key-retrieve --verify SHA512SUMS.sign SHA512SUMS
  rm SHA512SUMS.sign SHA512SUMS
else
  echo "Using existing ISO at /mnt/debian-$VERSION-amd64-netinst.iso"
fi 

# Unpack ISO
xorriso -osirrox on -indev "/mnt/debian-$VERSION-amd64-netinst.iso" -extract . /media
chmod -R +w /media

# Add preseed customization file and point to it at boot
cp /mnt/preseed.cfg /media
APPEND="file=/cdrom/preseed.cfg"
for i in /media/isolinux/*.cfg
do
  sed -i 's@\---@'"$APPEND ---"'@' "$i"
done

# Build ISO using the previous build command with some simplifications.
dd if="/mnt/debian-$VERSION-amd64-netinst.iso" bs=1 count=432 of="/tmp/isohdpfx.bin"
cat /media/.disk/mkisofs | sed \
    -e 's/-jigdo-[^ ]* [^ ]* //g' \
    -e 's/-checksum_algorithm_iso [^ ]* //' \
    -e 's/-checksum-list [^ ]* //' \
    -e 's,-isohybrid-mbr [^ ]* ,-isohybrid-mbr /tmp/isohdpfx.bin ,' \
    -e 's/ CD1//' \
    -e 's, boot1, /media,' \
    -e 's,-o [^ ]*,-o "/mnt/debian-$VERSION-amd64-$NAME.iso",' > /tmp/mkiso
chmod 755 /tmp/mkiso
/tmp/mkiso

echo "debian-$VERSION-amd64-$NAME.iso created."

