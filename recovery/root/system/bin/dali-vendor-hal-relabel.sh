#!/system/bin/sh
# Detach any real vendor/odm mounts first (lazy), then relabel the ramdisk
# HAL closure. The wait is bounded so the HAL chain starts quickly enough for
# TWRP's FBE setup.
umount -l /vendor/lib/modules 2>/dev/null
umount -l /vendor/lib/modules/6.6 2>/dev/null
umount -l /vendor/lib/modules/6.6-gki 2>/dev/null
umount -l /vendor 2>/dev/null
umount -l /vendor_dlkm 2>/dev/null
umount -l /odm 2>/dev/null
umount -l /odm_dlkm 2>/dev/null
umount -l /system_dlkm 2>/dev/null
i=0
while grep -q ' /vendor ' /proc/mounts && [ "$i" -lt 10 ]; do
    umount -l /vendor 2>/dev/null
    i=$((i+1))
    sleep 1
done
touch /tmp/dali-vendor-hal-relabeled
exit 0
