#!/system/bin/sh
# dali-persist-label.sh
# Persist relabeling can be slow; keep it off the HAL-chain critical path.
toybox restorecon -RF /mnt/vendor/persist
mkdir -p /mnt/vendor/persist/data
chmod 0755 /mnt/vendor/persist/data
chown system:system /mnt/vendor/persist/data
toybox restorecon -RF /mnt/vendor/persist/data
exit 0
