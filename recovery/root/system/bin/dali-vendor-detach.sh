#!/system/bin/sh
# Lazy-detach any real vendor/odm/dlkm mounts left by OrangeFox ROM-info or
# manual operations that are no longer needed. Instant, no long waits.
umount -l /vendor/lib/modules 2>/dev/null
umount -l /vendor 2>/dev/null
umount -l /vendor_dlkm 2>/dev/null
umount -l /odm 2>/dev/null
umount -l /odm_dlkm 2>/dev/null
umount -l /system_dlkm 2>/dev/null
touch /tmp/dali-vendor-detached
exit 0
