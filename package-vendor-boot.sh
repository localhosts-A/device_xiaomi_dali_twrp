#!/bin/sh
set -eu
export LC_ALL=C

PARTITION_SIZE=67108864
MAX_PREAVB_SIZE=67039232
PLATFORM_CPIO_SHA256=f97cfff3e9b570d8480861370a0a0971e4ab768d2d52e9e16308e3821bf69680
PLATFORM_LIBCPP_SHA256=794eb8fafd7be35da3725e9ec0b15189c6f4f2544f5b78afd8a647dde5b69195
PLATFORM_GZIP_SHA256=d850274ff1c0be657238aa8c7d1b3452840123242dd18bb15f5872840fa0fe5f
OFFICIAL_RECOVERY_CPIO_SHA256=721e2acde9cba9ccc266ff1a931cb3a53dffb06cfaa60ba85cb070abab275db6
DTB_SHA256=223984cc1daf6f9194ff33e4c674dce9f2de9203dc9b73e72bd1e0754dbf4ae4
AVB_SALT=e1a6e69d4b89907d19b5eb301f2ab32d6b45d093d6237d9158ad83848dafe655
AVB_FINGERPRINT=alps/hal_mgvi_64_64only_armv82/mgvi_64_64only_armv82:15/AP3A.240905.015.A2/OS3.0.303.0.WONCNXM:user/release-keys
SCP_OUTPUT_SHA256=e00d0d0a8892ffd07467e4dc38060b6ea901125e4e86f2d8e38fd7ef2a9ac0c4
GOODIX_OUTPUT_SHA256=2015fd201a82913ef07b736ac3f35dcc89562cb92359e3d934ec98764219b3c0
XIAOMI_TOUCH_SHA256=46a49015776c944612669a0c7d7d26d14dc28333e5ffbc8248f75ab0aa4d6e08
FOCALTECH_OUTPUT_SHA256=f7c5c0dcde05c33a1b5764f974e782ecd89c9eb7e3dec1299734092e9311578d
MERGED_MODULES_DEP_SHA256=9a1b0bc55dfd9be9a91bdcd908fd0d02cd4c08d9de14cfa8b6ac1150543af3a4
FLASHLIGHT_SHA256=6c0cd49e6b460831b5d77389168aab30ee83340c7f439ec1d36f67d076e7a425
LEDS_MT6379_SHA256=3313b221d8b85e6f8c0c8dfbe53ef2434beea2fddb80d6c568e1f30aa1e8b893
LEDS_MT6379PMIC_SHA256=8cb39457b591a069bb00e63aab71525f7380a597f54e4b398d084cb852dd64d4
MTK_GPUEB_SHA256=a8e1387320581bb943b84ec544559b6373225819f319d7103088a3f44fa87db2
MTK_PBM_SHA256=cb440df5ece567746a3beedcd42111e8edd20633c05347421e520fbba3254b29
MTK_PEAK_POWER_BUDGET_SHA256=da0402612a579b93ec12ac2bafae86a5118a17dfb4d2c04f177200074980520c
CL_DSP_CORE_SHA256=3cc58bed32717df66f4dce569c25962630cb0a3b12bb2b7e0f07185309610a17
CS40L26_CORE_SHA256=e222d9eda7897ea25368a4a55ce6b46032dfbf57a71eb3a259eebc67f563580f
CS40L26_I2C_SHA256=f74fd302eec0b1f2383b1f603e647d2543c345c6ece0afc58c95ed2e907202b3
CS40L26_SPI_SHA256=a4781ab300e0f089beb78614e36594a23381dd41e8d12684c8b3cf3fc23c9990
SND_SOC_CS40L26_SHA256=0357ea716d99980c275fe2d4445690f51013a7d6e52ceb5d632fb027e14b2e21

die() {
    echo "$*" >&2
    exit 1
}

file_sha256() {
    sha256sum "$1" | awk '{print $1}'
}

require_sha256() {
    expected=$1
    input=$2
    actual=$(file_sha256 "$input")
    [ "$actual" = "$expected" ] || die "hash mismatch: $input"
}

extract_vendor_ramdisk() {
    fragment=$1
    destination=$2
    mkdir -p "$destination"
    cpio_input="$destination/.dali-vendor-ramdisk.cpio"
    gzip -dc "$fragment" > "$cpio_input"
    (
        cd "$destination"
        cpio -idmu --quiet < "$cpio_input"
    )
    rm -f -- "$cpio_input"
}

trim_platform_fragment() {
    platform_input=$1
    official_recovery_cpio=$2
    output_gzip=$3
    platform_root="$work/platform-root"
    official_recovery_root="$work/official-recovery-root"
    mkdir -p "$platform_root" "$official_recovery_root"
    gzip -dc "$platform_input" > "$work/platform-original.cpio"
    cpio -idmu --quiet -D "$platform_root" < "$work/platform-original.cpio"
    cpio -idmu --quiet -D "$official_recovery_root" < "$official_recovery_cpio"
    python3 - "$platform_root" "$official_recovery_root" <<'PYTRIM'
import os
import stat
import sys

platform_root, official_recovery_root = sys.argv[1:]
removed = 0
removed_bytes = 0

def kind(path):
    mode = os.lstat(path).st_mode
    if stat.S_ISDIR(mode):
        return "directory"
    if stat.S_ISREG(mode):
        return "file"
    if stat.S_ISLNK(mode):
        return "symlink"
    return "other"

def identical(left, right):
    lk = kind(left)
    rk = kind(right)
    if lk != rk:
        return False
    if lk == "symlink":
        return os.readlink(left) == os.readlink(right)
    if lk == "file":
        return os.path.getsize(left) == os.path.getsize(right) and open(left, "rb").read() == open(right, "rb").read()
    return False

for current, directories, files in os.walk(official_recovery_root, topdown=True, followlinks=False):
    paths = [os.path.join(current, name) for name in files]
    for name in list(directories):
        path = os.path.join(current, name)
        if os.path.islink(path):
            directories.remove(name)
        paths.append(path)
    for recovery_path in paths:
        relative = os.path.relpath(recovery_path, official_recovery_root)
        platform_path = os.path.join(platform_root, relative)
        if not os.path.lexists(platform_path):
            continue
        if kind(recovery_path) == "directory":
            continue
        if identical(platform_path, recovery_path):
            if kind(platform_path) == "file":
                removed_bytes += os.lstat(platform_path).st_size
            os.unlink(platform_path)
            removed += 1

for current, directories, files in os.walk(platform_root, topdown=False, followlinks=False):
    for name in directories + files:
        path = os.path.join(current, name)
        try:
            os.utime(path, (0, 0), follow_symlinks=False)
        except OSError as error:
            raise SystemExit("unable to normalize platform metadata for {}: {}".format(path, error))
try:
    os.utime(platform_root, (0, 0), follow_symlinks=False)
except OSError as error:
    raise SystemExit("unable to normalize platform metadata for {}: {}".format(platform_root, error))

print("safe-trimmed platform overrides: {} entries, {} regular-file bytes".format(removed, removed_bytes))
PYTRIM
    (cd "$platform_root" && find . -print0 | sort -z | cpio --null --reproducible -o -H newc > "$work/platform-trimmed.cpio")
    gzip -9 -n -c "$work/platform-trimmed.cpio" > "$output_gzip"
    gzip -t "$output_gzip"
}


validate_recovery_payload() {
    recovery_root=$1
    module_root="$recovery_root/lib/modules"
    recovery_binary="$recovery_root/system/bin/recovery"

    [ -d "$module_root" ] || die "final Recovery root has no module directory"
    require_sha256 "$PLATFORM_LIBCPP_SHA256" "$recovery_root/system/lib64/libc++.so"
    require_sha256 "$SCP_OUTPUT_SHA256" "$module_root/scp.ko"
    require_sha256 "$GOODIX_OUTPUT_SHA256" "$module_root/goodix_core_dali.ko"
    require_sha256 "$XIAOMI_TOUCH_SHA256" "$module_root/xiaomi_touch_dali.ko"
    require_sha256 "$FOCALTECH_OUTPUT_SHA256" "$module_root/focaltech_touch_dali.ko"
    require_sha256 "$FLASHLIGHT_SHA256" "$module_root/flashlight.ko"
    require_sha256 "$LEDS_MT6379_SHA256" "$module_root/leds-mt6379.ko"
    require_sha256 "$LEDS_MT6379PMIC_SHA256" "$module_root/leds-mt6379pmic.ko"
    require_sha256 "$MTK_GPUEB_SHA256" "$module_root/mtk_gpueb.ko"
    require_sha256 "$MTK_PBM_SHA256" "$module_root/mtk_pbm.ko"
    require_sha256 "$MTK_PEAK_POWER_BUDGET_SHA256" "$module_root/mtk_peak_power_budget.ko"
    require_sha256 "$CL_DSP_CORE_SHA256" "$module_root/cl_dsp-core.ko"
    require_sha256 "$CS40L26_CORE_SHA256" "$module_root/cs40l26-core.ko"
    require_sha256 "$CS40L26_I2C_SHA256" "$module_root/cs40l26-i2c.ko"
    require_sha256 "$CS40L26_SPI_SHA256" "$module_root/cs40l26-spi.ko"
    require_sha256 "$SND_SOC_CS40L26_SHA256" "$module_root/snd-soc-cs40l26.ko"
    require_sha256 "$MERGED_MODULES_DEP_SHA256" "$module_root/modules.dep"
    if grep -F -- "/vendor_dlkm/" "$module_root/modules.dep" >/dev/null; then
        die "final Recovery module metadata references vendor_dlkm"
    fi

    python3 - "$module_root" <<'PY'
import stat
import sys
from pathlib import Path

module_root = Path(sys.argv[1])
for line_number, line in enumerate((module_root / "modules.dep").read_text(encoding="ascii").splitlines(), 1):
    owner, separator, dependency_text = line.partition(":")
    if not separator or not owner:
        raise SystemExit(f"invalid modules.dep entry at line {line_number}")
    for entry in (owner, *dependency_text.split()):
        if entry.startswith("/lib/modules/"):
            relative = entry.removeprefix("/lib/modules/")
        elif entry.startswith("/"):
            raise SystemExit(f"unexpected absolute module path at line {line_number}: {entry}")
        else:
            relative = entry
        path = Path(relative)
        if path.is_absolute() or ".." in path.parts:
            raise SystemExit(f"unsafe module path at line {line_number}: {entry}")
        candidate = module_root / path
        try:
            mode = candidate.lstat().st_mode
        except FileNotFoundError:
            raise SystemExit(f"missing module dependency at line {line_number}: {entry}")
        if not stat.S_ISREG(mode):
            raise SystemExit(f"module dependency is not a regular file at line {line_number}: {entry}")
PY

    [ -f "$recovery_binary" ] || die "final Recovery executable is missing"
    for requested_module in xiaomi_touch_dali.ko goodix_core_dali.ko focaltech_touch_dali.ko
    do
        grep -aF -- "$requested_module" "$recovery_binary" >/dev/null ||
            die "final Recovery executable does not request $requested_module"
    done
}

[ "$#" -eq 2 ] || die "usage: $0 /absolute/path/to/source /absolute/path/to/vendor_boot.img"
source_root=$1
output_image=$2
case "$source_root" in
    /*) ;;
    *) die "source path must be absolute" ;;
esac
case "$output_image" in
    /*) ;;
    *) die "output path must be absolute" ;;
esac

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
platform_gzip="$script_dir/prebuilt/vendor_ramdisk/platform.cpio.gz"
dtb="$script_dir/prebuilt/dtb/dali.dtb"
built_vendor_boot="$source_root/out/target/product/dali/vendor_boot.img"
mkbootimg="$source_root/system/tools/mkbootimg/mkbootimg.py"
unpack_bootimg="$source_root/system/tools/mkbootimg/unpack_bootimg.py"
avbtool="$source_root/external/avb/avbtool.py"
for input in "$platform_gzip" "$dtb" "$built_vendor_boot" "$mkbootimg" "$unpack_bootimg" "$avbtool"
do
    [ -f "$input" ] || die "missing input: $input"
done

gzip -t "$platform_gzip"
require_sha256 "$PLATFORM_GZIP_SHA256" "$platform_gzip"
output_dir=$(dirname -- "$output_image")
mkdir -p "$output_dir"
work=$(mktemp -d "$output_dir/.dali-vendor-boot.XXXXXX")
cleanup() {
    if [ -d "$work" ]; then
        rm -rf "$work"
    fi
}
trap cleanup EXIT HUP INT TERM

gzip -dc "$platform_gzip" > "$work/platform.cpio"
require_sha256 "$PLATFORM_CPIO_SHA256" "$work/platform.cpio"
require_sha256 "$DTB_SHA256" "$dtb"
max_preavb_size=$(python3 "$avbtool" add_hash_footer \
    --partition_size "$PARTITION_SIZE" \
    --partition_name vendor_boot \
    --hash_algorithm sha256 \
    --salt "$AVB_SALT" \
    --algorithm NONE \
    --calc_max_image_size)
[ "$max_preavb_size" = "$MAX_PREAVB_SIZE" ] ||
    die "unexpected AVB maximum image size: $max_preavb_size"


python3 "$unpack_bootimg" --boot_img "$built_vendor_boot" --out "$work/built" > "$work/built-info.txt"
recovery_fragment="$work/built/vendor_ramdisk01"
awk '
    /^vendor boot image header version: 4$/ { header_v4 = 1 }
    /^    vendor_ramdisk01: \{$/ { recovery = 1; next }
    recovery && /^        type: 0x2$/ { recovery_type = 1 }
    recovery && /^        name: recovery$/ { recovery_name = 1 }
    recovery && /^    }$/ { recovery = 0 }
    END { exit !(header_v4 && recovery_type && recovery_name) }
' "$work/built-info.txt" ||
    die "built vendor_boot does not contain the expected v4 recovery fragment"
[ -f "$recovery_fragment" ] || die "built recovery fragment is missing"
gzip -t "$recovery_fragment"

gzip -dc "$recovery_fragment" > "$work/recovery.cpio"
optimized_recovery_fragment="$work/recovery-gzip9.cpio.gz"
gzip -9 -n -c "$work/recovery.cpio" > "$optimized_recovery_fragment"
gzip -t "$optimized_recovery_fragment"
gzip -dc "$optimized_recovery_fragment" > "$work/recovery-gzip9.cpio"
cmp "$work/recovery.cpio" "$work/recovery-gzip9.cpio"
trimmed_platform_gzip="$work/platform-trimmed.cpio.gz"
official_recovery_gzip="$script_dir/prebuilt/vendor_ramdisk/official_recovery.cpio.gz"
require_sha256 "$OFFICIAL_RECOVERY_CPIO_SHA256" "$official_recovery_gzip"
gzip -dc "$official_recovery_gzip" > "$work/official-recovery.cpio"
trim_platform_fragment "$platform_gzip" "$work/official-recovery.cpio" "$trimmed_platform_gzip"

python3 "$mkbootimg" \
    --header_version 4 \
    --pagesize 4096 \
    --base 0x00000000 \
    --kernel_offset 0x80000000 \
    --ramdisk_offset 0xa6f00000 \
    --tags_offset 0x87c80000 \
    --dtb_offset 0x0000000087c80000 \
    --vendor_cmdline "bootopt=64S3,32N2,64N2 erofs.reserved_pages=64" \
    --dtb "$dtb" \
    --vendor_ramdisk "$trimmed_platform_gzip" \
    --ramdisk_type RECOVERY \
    --ramdisk_name recovery \
    --vendor_ramdisk_fragment "$optimized_recovery_fragment" \
    --vendor_boot "$work/vendor_boot.preavb.img"

preavb_size=$(stat -c '%s' "$work/vendor_boot.preavb.img")
[ "$preavb_size" -le "$PARTITION_SIZE" ] || die "vendor_boot exceeds the partition before AVB: $preavb_size"
[ "$preavb_size" -le "$max_preavb_size" ] ||
    die "vendor_boot exceeds the AVB maximum before footer creation: $preavb_size > $max_preavb_size"
cp "$work/vendor_boot.preavb.img" "$work/vendor_boot.img"
python3 "$avbtool" add_hash_footer \
    --image "$work/vendor_boot.img" \
    --partition_size "$PARTITION_SIZE" \
    --partition_name vendor_boot \
    --hash_algorithm sha256 \
    --salt "$AVB_SALT" \
    --algorithm NONE \
    --prop "com.android.build.vendor_boot.fingerprint:$AVB_FINGERPRINT"
[ "$(stat -c '%s' "$work/vendor_boot.img")" -eq "$PARTITION_SIZE" ] || die "unexpected final image size"

python3 "$unpack_bootimg" --boot_img "$work/vendor_boot.img" --out "$work/output" > "$work/output-info.txt"
awk '
    /^vendor boot image header version: 4$/ { header_v4 = 1 }
    /^page size: 0x00001000$/ { page_size = 1 }
    /^kernel load address: 0x80000000$/ { kernel_address = 1 }
    /^ramdisk load address: 0xa6f00000$/ { ramdisk_address = 1 }
    /^vendor command line args: bootopt=64S3,32N2,64N2 erofs.reserved_pages=64$/ { cmdline = 1 }
    /^kernel tags load address: 0x87c80000$/ { tags_address = 1 }
    /^dtb address: 0x0000000087c80000$/ { dtb_address = 1 }
    /^vendor bootconfig size: 0$/ { empty_bootconfig = 1 }
    /^    vendor_ramdisk00: \{$/ { fragment = 1; next }
    /^    vendor_ramdisk01: \{$/ { fragment = 2; next }
    fragment == 1 && /^        type: 0x1$/ { platform_type = 1 }
    fragment == 1 && /^        name: $/ { platform_name = 1 }
    fragment == 2 && /^        type: 0x2$/ { recovery_type = 1 }
    fragment == 2 && /^        name: recovery$/ { recovery_name = 1 }
    fragment && /^    }$/ {
        if (fragment == 1) {
            platform = platform_type && platform_name
        } else if (fragment == 2) {
            recovery = recovery_type && recovery_name
        }
        fragment = 0
    }
    END {
        exit !(header_v4 && page_size && kernel_address && ramdisk_address &&
               cmdline && tags_address && dtb_address && empty_bootconfig &&
               platform && recovery)
    }
' "$work/output-info.txt" ||
    die "final vendor_boot layout does not match the official v4 contract"
cmp "$trimmed_platform_gzip" "$work/output/vendor_ramdisk00"
cmp "$optimized_recovery_fragment" "$work/output/vendor_ramdisk01"
cmp "$dtb" "$work/output/dtb"
merged_root="$work/merged-root"
extract_vendor_ramdisk "$work/output/vendor_ramdisk00" "$merged_root"
extract_vendor_ramdisk "$work/output/vendor_ramdisk01" "$merged_root"
validate_recovery_payload "$merged_root"
python3 "$avbtool" info_image --image "$work/vendor_boot.img" > "$work/avb-info.txt"
grep -F "Algorithm:                NONE" "$work/avb-info.txt" >/dev/null
grep -F "Hash Algorithm:        sha256" "$work/avb-info.txt" >/dev/null
grep -F "Partition Name:        vendor_boot" "$work/avb-info.txt" >/dev/null
grep -F "Salt:                  $AVB_SALT" "$work/avb-info.txt" >/dev/null
grep -F "Prop: com.android.build.vendor_boot.fingerprint -> '$AVB_FINGERPRINT'" "$work/avb-info.txt" >/dev/null

install -m 0644 "$work/vendor_boot.img" "$output_image"
sha256sum "$output_image" > "$output_image.sha256"
printf 'pre-AVB size: %s (AVB maximum: %s)\n' "$preavb_size" "$max_preavb_size"
printf 'created %s\n' "$output_image"
