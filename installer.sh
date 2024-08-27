#!/bin/bash

set -e

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root." >&2
  exit 1
fi

# Check for required arguments
if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <device> <cllinux.tar.xz> </boot/>" >&2
  exit 1
fi

DEVICE="$1"
ROOTFS_ARCHIVE="$2"
BOOTFILES_DIR="$3"

# Ensure the device exists
if [ ! -b "$DEVICE" ]; then
  echo "Device $DEVICE not found." >&2
  exit 1
fi

# Unmount all partitions on the device
for PART in $(ls ${DEVICE}?*); do
  echo "Unmounting $PART..."
  umount "$PART" || true
done

# Partition the device
echo "Partitioning $DEVICE..."
(
echo o # Create a new empty DOS partition table
echo n # New partition
echo p # Primary partition
echo 1 # Partition number 1
echo   # First sector (Accept default: 2048)
echo +256M # Size of the partition
echo a # Mark partition 1 as bootable
echo n # New partition
echo p # Primary partition
echo 2 # Partition number 2
echo   # First sector (Accept default)
echo   # Last sector (Accept default: end of disk)
echo w # Write changes
) | fdisk "$DEVICE"

# Format the partitions
echo "Formatting partitions..."
mkfs.vfat -F 32 "${DEVICE}1"
mkfs.ext4 "${DEVICE}2"

# Mount the root filesystem partition
echo "Mounting root filesystem partition..."
mkdir -p /mnt/rootfs
mount "${DEVICE}2" /mnt/rootfs

# Extract the root filesystem
echo "Extracting root filesystem..."
tar -xJf "$ROOTFS_ARCHIVE" -C /mnt/rootfs

# Mount the boot partition
echo "Mounting boot partition..."
mkdir -p /mnt/boot
mount "${DEVICE}1" /mnt/boot

# Copy boot files
echo "Copying boot files..."
cp -r "$BOOTFILES_DIR"/* /mnt/boot/

# Clean up
echo "Cleaning up..."
umount /mnt/rootfs
umount /mnt/boot
rmdir /mnt/rootfs
rmdir /mnt/boot

echo "Installation complete."
