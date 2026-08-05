#!/system/bin/sh
# Mount the real ODM briefly so KeyMint can load its TA for the (possibly
# upgraded) metadata key blob. The postinit detach unmounts it afterwards.
slot=$(getprop ro.boot.slot_suffix)
[ -n "$slot" ] || slot="_a"
mount -t erofs -o ro "/dev/block/mapper/odm${slot}" /odm 2>/dev/null && exit 0
mount -t ext4 -o ro "/dev/block/mapper/odm${slot}" /odm 2>/dev/null && exit 0
# mapper path failed; fall back to by-name before giving up.
mount -t erofs -o ro "/dev/block/by-name/odm${slot}" /odm 2>/dev/null && exit 0
mount -t ext4 -o ro "/dev/block/by-name/odm${slot}" /odm 2>/dev/null && exit 0
log -t dali-odm-mount "failed to mount odm (mapper + by-name, erofs + ext4)"
exit 1
mount -t erofs -o ro /dev/block/by-name/odm /odm 2>/dev/null && exit 0
exit 0
