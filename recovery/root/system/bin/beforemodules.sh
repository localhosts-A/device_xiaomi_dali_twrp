#!/system/bin/sh

# The Goodix/TP firmware and configuration are packaged in the Recovery
# ramdisk at /odm/firmware, so the logical ODM partition is not mounted.
# KernelModuleLoader calls this before vendor modules probe; the driver
# reads the official firmware directly from the rootfs copy.
status=/tmp/dali-odm-beforemodules.status
if [ -d /odm/firmware ] && { ls /odm/firmware/goodix_*.bin >/dev/null 2>&1 || ls /odm/firmware/focaltech_*.bin >/dev/null 2>&1; }; then
    printf '%s\n' "ramdisk-odm" > "$status"
else
    printf '%s\n' "missing-ramdisk-firmware" > "$status"
fi
exit 0
