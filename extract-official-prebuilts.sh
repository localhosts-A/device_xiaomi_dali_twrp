#!/bin/sh
set -eu
verify_sha256() {
    expected=$1
    input=$2
    actual=$(sha256sum "$input" | awk '{print $1}')
    if [ "$actual" != "$expected" ]; then
        echo "hash mismatch: $input" >&2
        exit 1
    fi
}

if [ "$#" -ne 1 ]; then
    echo "usage: $0 /absolute/path/to/official-ota/unpacked" >&2
    exit 2
fi

source_root=$(readlink -f -- "$1") || {
    echo "failed to canonicalize official extraction root: $1" >&2
    exit 2
}
case "$source_root" in
    */official-ota/unpacked) ;;
    *)
        echo "refusing non-official extraction root: $source_root" >&2
        exit 2
        ;;
esac

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
official_ota_root=$(dirname -- "$source_root")
vendor_dlkm_modules="$official_ota_root/extracted/vendor_dlkm/lib/modules"
platform_modules="$source_root/vendor_ramdisk/root/lib/modules"
system_build_props="$official_ota_root/extracted/system/system/build.prop"
vendor_build_props="$official_ota_root/extracted/vendor/build.prop"

verify_sha256 55caa83bf1dd1ab5e34521f1faa18532a6110a065123577a1a62d80ee5178569 "$source_root/boot/kernel"
verify_sha256 223984cc1daf6f9194ff33e4c674dce9f2de9203dc9b73e72bd1e0754dbf4ae4 "$source_root/vendor_boot/dtb"
verify_sha256 83e9e2eccd9a47bceb7da29edffc5a4cc72fefd95c472b1200c9448c6e47a33a "$source_root/vendor_boot/vendor_ramdisk00"
verify_sha256 13f5bd1abf777a293a7bc74bb14e41757bced12c4fb2d130cf7b0829d35ab6a9 "$source_root/recovery_ramdisk/root/system/etc/recovery.fstab"
verify_sha256 912a4a651d2197883e46cf9a7afc3035261c1e7a8263709f91d0146ddfd68bfb "$source_root/recovery_ramdisk/root/first_stage_ramdisk/fstab.emmc"
verify_sha256 e75201e0a0d2be1a5a13371a010b749ac6d66fe5dc2742fa4a0d13876d5e4312 "$source_root/vendor_ramdisk/root/system/etc/ueventd.rc"
verify_sha256 ba8eddd72cbaad183012da73c1ebd1d2abbacb0ff1ed4eaad5dd0b4ec395371e "$source_root/recovery_ramdisk/root/init.recovery.mt6991.rc"
verify_sha256 7dd0abf1bdcc804ac2ae077debc52c0646c163b80df505ca99e7713cce297db6 "$vendor_dlkm_modules/scp.ko"
verify_sha256 d299c83cd2e334c22ae510de172146b39146cc4fdb1860fd1c67210a98cda156 "$vendor_dlkm_modules/goodix_core_dali.ko"
verify_sha256 46a49015776c944612669a0c7d7d26d14dc28333e5ffbc8248f75ab0aa4d6e08 "$vendor_dlkm_modules/xiaomi_touch_dali.ko"
verify_sha256 dd972abacb2c2cd5475903b8ad681c9985d0a3be67fd2e6f65c812305be8034c "$platform_modules/modules.dep"
verify_sha256 827ecadd2e3d23db6ae92de9f112c7d4f3e12a1347f0e56a758558db6b2aed3d "$system_build_props"
verify_sha256 1b05f6af77f2d37918041116878d3ad2e9d513094755eea08694ced2dcb9d42e "$vendor_build_props"
install -D -m 0644 "$source_root/boot/kernel" "$script_dir/prebuilt/kernel"
install -D -m 0644 "$source_root/vendor_boot/dtb" "$script_dir/prebuilt/dtb/dali.dtb"
install -D -m 0644 "$source_root/recovery_ramdisk/root/system/etc/recovery.fstab" "$script_dir/recovery.fstab"
install -D -m 0644 "$source_root/recovery_ramdisk/root/first_stage_ramdisk/fstab.emmc" \
    "$script_dir/recovery/root/first_stage_ramdisk/fstab.emmc"
# The recovery copy adds FBE device-node rules; verify the official baseline only.
install -D -m 0644 "$source_root/recovery_ramdisk/root/init.recovery.mt6991.rc" \
    "$script_dir/recovery/root/init.recovery.mt6991.rc"
recovery_modules="$script_dir/prebuilt/recovery_modules"
# All modules come from the official vendor_dlkm image (single source of
# truth: the list below must match prebuilt/recovery_modules). After
# installation the authoritative sha256 manifest is regenerated, which
# package-vendor-boot.sh then verifies against.
for ko in cl_dsp-core.ko cs40l26-core.ko cs40l26-i2c.ko cs40l26-spi.ko \
           flashlight.ko goodix_core_dali.ko leds-mt6379.ko leds-mt6379pmic.ko \
           mtk_gpueb.ko mtk_pbm.ko mtk_peak_power_budget.ko scp.ko \
           snd-soc-cs40l26.ko xiaomi_touch_dali.ko; do
    install -D -m 0644 "$vendor_dlkm_modules/$ko" "$recovery_modules/$ko"
done
install -D -m 0644 "$platform_modules/modules.dep" "$recovery_modules/modules.dep"
(cd "$recovery_modules" && sha256sum *.ko modules.dep > modules.sha256)
recovery_properties="$script_dir/prebuilt/recovery_properties"
install -D -m 0644 "$system_build_props" "$recovery_properties/system.build.prop"
install -D -m 0644 "$vendor_build_props" "$recovery_properties/vendor.build.prop"
command -v lz4 >/dev/null 2>&1 || {
    echo "lz4 is required to convert the official platform ramdisk" >&2
    exit 1
}
platform_dir="$script_dir/prebuilt/vendor_ramdisk"
mkdir -p "$platform_dir"
platform_raw=$(mktemp "$platform_dir/.platform.cpio.XXXXXX")
platform_gzip="$platform_dir/platform.cpio.gz"
platform_gzip_tmp=$(mktemp "$platform_dir/.platform.cpio.gz.XXXXXX")
cleanup() {
    rm -f "$platform_raw" "$platform_gzip_tmp"
}
trap cleanup EXIT HUP INT TERM
lz4 -dc "$source_root/vendor_boot/vendor_ramdisk00" > "$platform_raw"
verify_sha256 f97cfff3e9b570d8480861370a0a0971e4ab768d2d52e9e16308e3821bf69680 "$platform_raw"
gzip -9 -n -c "$platform_raw" > "$platform_gzip_tmp"
verify_sha256 d850274ff1c0be657238aa8c7d1b3452840123242dd18bb15f5872840fa0fe5f "$platform_gzip_tmp"
mv "$platform_gzip_tmp" "$platform_gzip"

sha256sum \
    "$script_dir/prebuilt/kernel" \
    "$script_dir/prebuilt/dtb/dali.dtb" \
    "$platform_gzip" \
    "$script_dir/recovery.fstab" \
    "$script_dir/recovery/root/first_stage_ramdisk/fstab.emmc" \
    "$script_dir/recovery/root/system/etc/ueventd.rc" \
    "$script_dir/recovery/root/init.recovery.mt6991.rc" \
    "$recovery_modules/scp.ko" \
    "$recovery_modules/goodix_core_dali.ko" \
    "$recovery_modules/xiaomi_touch_dali.ko" \
    "$recovery_modules/modules.dep" \
    "$recovery_properties/system.build.prop" \
    "$recovery_properties/vendor.build.prop"
