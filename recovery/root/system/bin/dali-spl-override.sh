#!/system/bin/sh
# dali-spl-override.sh
# Reads the installed system's real SPL (not baked into prop.default) and
# publishes it so KeyMint/update_engine see the true value. The SPL ceiling
# for the crypto HAL chain is set synchronously by init.recovery.project.rc.

#
# KeyMint bakes the OS/vendor security-patch level into every hardware key
# blob. When an OTA upgrades the installed ROM (e.g. 303 -> 305), the FBE
# metadata key blob is re-wrapped with the newer patchlevel; if Recovery
# reports an older baked SPL, the TEE rejects the blob with INVALID_KEY_BLOB
# (-33) and /data cannot be decrypted.
#
# This hook runs in the background (see init.recovery.project.rc) and reads the
# installed current-slot system/vendor build.prop. The KeyMint SPL ceiling is
# set synchronously by the init rc.sh before the HAL chain starts;
# update_engine reads of.installed_os_spl / of.installed_vendor_spl here so
# OTA SPL-downgrade checks compare against the real installed system.

log() { echo "dali-spl-override: $*"; }

slot=$(getprop ro.boot.slot_suffix)
[ -n "$slot" ] || slot=$(getprop ro.boot.slot)
[ -n "$slot" ] || slot="_a"

OS_SPL=""
VENDOR_SPL=""

read_spl() {
    [ -f "$1" ] || return 0
    sed -n "s/^$2=//p" "$1" | head -n 1
}

# Prefer already-mounted Recovery views of the installed partitions.
if [ -f /system/build.prop ]; then
    OS_SPL=$(read_spl /system/build.prop ro.build.version.security_patch)
fi
if [ -z "$OS_SPL" ] && [ -f /system_root/build.prop ]; then
    OS_SPL=$(read_spl /system_root/build.prop ro.build.version.security_patch)
fi
if [ -z "$OS_SPL" ] && [ -f /system_root/system/build.prop ]; then
    OS_SPL=$(read_spl /system_root/system/build.prop ro.build.version.security_patch)
fi
if [ -f /vendor/build.prop ]; then
    VENDOR_SPL=$(read_spl /vendor/build.prop ro.vendor.build.security_patch)
fi

mnt=/mnt/dali_spl
mkdir -p "$mnt"

mount_ro() {
    mkdir -p "$mnt/$2"
    case "$2" in
        *_ext4) fstype=ext4 ;;
        *) fstype=erofs ;;
    esac
    mount -t "$fstype" -o ro "/dev/block/mapper/$1" "$mnt/$2" 2>/dev/null
}

if [ -z "$OS_SPL" ]; then
    mount_ro "system$slot" sys_erofs || mount_ro "system$slot" sys_ext4
    if [ -f "$mnt/sys_erofs/build.prop" ]; then
        OS_SPL=$(read_spl "$mnt/sys_erofs/build.prop" ro.build.version.security_patch)
    elif [ -f "$mnt/sys_ext4/build.prop" ]; then
        OS_SPL=$(read_spl "$mnt/sys_ext4/build.prop" ro.build.version.security_patch)
    fi
    umount "$mnt/sys_erofs" 2>/dev/null
    umount "$mnt/sys_ext4" 2>/dev/null
fi

if [ -z "$VENDOR_SPL" ]; then
    mount_ro "vendor$slot" vnd_erofs || mount_ro "vendor$slot" vnd_ext4
    if [ -f "$mnt/vnd_erofs/build.prop" ]; then
        VENDOR_SPL=$(read_spl "$mnt/vnd_erofs/build.prop" ro.vendor.build.security_patch)
    elif [ -f "$mnt/vnd_ext4/build.prop" ]; then
        VENDOR_SPL=$(read_spl "$mnt/vnd_ext4/build.prop" ro.vendor.build.security_patch)
    fi
    umount "$mnt/vnd_erofs" 2>/dev/null
    umount "$mnt/vnd_ext4" 2>/dev/null
fi

# Real installed values for update_engine SPL-downgrade checks (patch 0029).
# The KeyMint SPL ceiling is applied synchronously by the init rc.sh.
setprop of.installed_os_spl "${OS_SPL:-2026-05-01}"
setprop of.installed_vendor_spl "${VENDOR_SPL:-2026-02-01}"

log "slot=$slot installed_os_spl=${OS_SPL:-<unread>} installed_vendor_spl=${VENDOR_SPL:-<unread>} keymint=2127-12 applied"
exit 0
