#!/bin/sh
set -eu

die() {
    echo "dali recovery ramdisk preparation: $*" >&2
    exit 2
}

verify_sha256() {
    expected=$1
    input=$2
    actual=$(sha256sum "$input" | awk '{print $1}')
    [ "$actual" = "$expected" ] || die "hash mismatch: $input"
}

if [ "$#" -ne 7 ]; then
    die "usage: $0 /absolute/path/to/recovery-root /absolute/path/to/soong-bridge /absolute/path/to/llvm-readobj /absolute/path/to/recovery-module-inputs /absolute/path/to/recovery-property-inputs /absolute/path/to/recovery-vendor-hal-inputs /absolute/path/to/recovery-firmware-inputs"
fi

input_root=$1
input_bridge=$2
input_llvm_readobj=$3
input_module_dir=$4
input_property_dir=$5
input_vendor_hal_dir=$6
input_firmware_dir=$7
case "$input_root" in
    /*) ;;
    *) die "recovery root must be absolute" ;;
esac
case "$input_bridge" in
    /*) ;;
    *) die "Soong bridge must be absolute" ;;
esac
case "$input_llvm_readobj" in
    /*) ;;
    *) die "llvm-readobj must be absolute" ;;
esac
case "$input_module_dir" in
    /*) ;;
    *) die "recovery module input directory must be absolute" ;;
esac
case "$input_property_dir" in
    /*) ;;
    *) die "recovery property input directory must be absolute" ;;
esac
case "$input_firmware_dir" in
    /*) ;;
    *) die "recovery firmware input directory must be absolute" ;;
esac

root=$(readlink -f -- "$input_root") || die "failed to canonicalize recovery root"
bridge=$(readlink -f -- "$input_bridge") || die "failed to canonicalize Soong bridge"
llvm_readobj=$(readlink -f -- "$input_llvm_readobj") || die "failed to canonicalize llvm-readobj"
module_dir=$(readlink -f -- "$input_module_dir") || die "failed to canonicalize recovery module input directory"
property_dir=$(readlink -f -- "$input_property_dir") || die "failed to canonicalize recovery property input directory"
vendor_hal_dir=$(readlink -f -- "$input_vendor_hal_dir") || die "failed to canonicalize recovery vendor HAL input directory"
firmware_dir=$(readlink -f -- "$input_firmware_dir") || die "failed to canonicalize recovery firmware input directory"
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
device_root=$(dirname -- "$script_dir")
soong_dir=$(dirname "$bridge")
out_dir=$(dirname "$soong_dir")

case "$soong_dir" in
    */soong) ;;
    *) die "unexpected Soong directory: $soong_dir" ;;
esac
case "$bridge" in
    "$soong_dir"/Android-*.mk) ;;
    *) die "unexpected Soong bridge: $bridge" ;;
esac
case "$root" in
    "$out_dir"/target/product/*/recovery/root) ;;
    *) die "unexpected recovery root: $root" ;;
esac
case "$module_dir" in
    "$device_root"/prebuilt/recovery_modules) ;;
    *) die "unexpected recovery module input directory: $module_dir" ;;
esac
case "$property_dir" in
    "$device_root"/prebuilt/recovery_properties) ;;
    *) die "unexpected recovery property input directory: $property_dir" ;;
esac
case "$vendor_hal_dir" in
    "$device_root"/prebuilt/recovery_vendor_hal) ;;
    *) die "unexpected recovery vendor HAL input directory: $vendor_hal_dir" ;;
esac
case "$firmware_dir" in
    "$device_root"/prebuilt/recovery_firmware) ;;
    *) die "unexpected recovery firmware input directory: $firmware_dir" ;;
esac

test -d "$root" || die "missing recovery root"
test -x "$root/system/bin/of-lk-protection-exec" || die "missing LK protection helper"
test -f "$bridge" || die "missing Soong bridge"
test -x "$llvm_readobj" || die "missing llvm-readobj"
test -f "$script_dir/patch-ap-touch-modules.py" || die "missing AP touch module generator"
test -f "$script_dir/root/init.recovery.usb.rc" || die "missing Recovery USB configfs rc"
test -f "$property_dir/system.build.prop" || die "missing official system build properties"
test -f "$property_dir/vendor.build.prop" || die "missing official vendor build properties"
for manifest in ramdisk-files.txt ramdisk-files.sha256sum
do
    test -f "$root/$manifest" || die "missing recovery manifest: $root/$manifest"
done

extract_prebuilt() {
    module=$1
    module_class=$2
    python3 - "$bridge" "$module" "$module_class" <<'PY'
import sys

bridge, target_module, target_class = sys.argv[1:]
matches = []
current = {}


def record_current():
    if (current.get("module") == target_module and
            current.get("module_class") == target_class):
        prebuilt = current.get("prebuilt")
        link_type = current.get("link_type")
        if prebuilt:
            matches.append((prebuilt, link_type))


with open(bridge, encoding="utf-8") as stream:
    for raw_line in stream:
        line = raw_line.rstrip("\n")
        if line.startswith("include $(CLEAR_VARS)"):
            record_current()
            current = {}
        elif line.startswith("LOCAL_MODULE := "):
            current["module"] = line[len("LOCAL_MODULE := "):]
        elif line.startswith("LOCAL_MODULE_CLASS := "):
            current["module_class"] = line[len("LOCAL_MODULE_CLASS := "):]
        elif line.startswith("LOCAL_PREBUILT_MODULE_FILE := "):
            current["prebuilt"] = line[len("LOCAL_PREBUILT_MODULE_FILE := "):]
        elif line.startswith("LOCAL_SOONG_LINK_TYPE := "):
            current["link_type"] = line[len("LOCAL_SOONG_LINK_TYPE := "):]
record_current()

if len(matches) != 1:
    print(
        "expected exactly one {} {} Recovery artifact, found {}".format(
            target_module, target_class, len(matches)
        ),
        file=sys.stderr,
    )
    raise SystemExit(1)

path, link_type = matches[0]
if link_type != "native:recovery":
    print(
        "{} {} is not native:recovery".format(target_module, target_class),
        file=sys.stderr,
    )
    raise SystemExit(1)
print(path)
PY
}

require_recovery_artifact() {
    path=$1
    name=$2
    [ -n "$path" ] && [ -f "$path" ] || die "missing $name Recovery artifact"
    case "$path" in
        "$out_dir"/soong/.intermediates/*/android_recovery_*/*/*) ;;
        *) die "$name is not a Recovery Soong artifact: $path" ;;
    esac
    case "$path" in
        */unstripped/*) die "$name selected an unstripped artifact" ;;
    esac
}

verify_recovery_symbol() {
    elf=$1
    name=$2

    symbols=$("$llvm_readobj" --dyn-symbols "$elf") ||
        die "failed to read dynamic symbols from $name"
    case "$symbols" in
        *VintfObjectRecovery*) ;;
        *) die "$name lacks the Recovery VINTF dynamic symbol" ;;
    esac
}

servicemanager=$(extract_prebuilt servicemanager.recovery EXECUTABLES) ||
    die "failed to locate servicemanager Recovery artifact"
libvintf=$(extract_prebuilt libvintf.recovery SHARED_LIBRARIES) ||
    die "failed to locate libvintf Recovery artifact"
require_recovery_artifact "$servicemanager" servicemanager
require_recovery_artifact "$libvintf" libvintf
verify_recovery_symbol "$servicemanager" servicemanager
verify_recovery_symbol "$libvintf" libvintf

[ -f "$root/system/bin/servicemanager" ] || die "ordinary servicemanager relink output is missing"
[ -f "$root/system/lib64/libvintf.so" ] || die "ordinary libvintf relink output is missing"

install -m 0755 "$servicemanager" "$root/system/bin/.servicemanager.dali"
install -m 0644 "$libvintf" "$root/system/lib64/.libvintf.so.dali"
mv -f "$root/system/bin/.servicemanager.dali" "$root/system/bin/servicemanager"
mv -f "$root/system/lib64/.libvintf.so.dali" "$root/system/lib64/libvintf.so"
cmp -s "$servicemanager" "$root/system/bin/servicemanager" || die "servicemanager copy verification failed"
cmp -s "$libvintf" "$root/system/lib64/libvintf.so" || die "libvintf copy verification failed"

# The Recovery CPIO overlays the official platform fragment. Its older libc++
# lacks Android 16's verbose-abort ABI, while the platform libc++ resolves all
# Recovery C++ imports and must therefore remain the final copy.
recovery_libcpp="$root/system/lib64/libc++.so"
rm -f -- "$recovery_libcpp"
[ ! -e "$recovery_libcpp" ] && [ ! -L "$recovery_libcpp" ] ||
    die "failed to remove incompatible Recovery libc++"

verify_sha256 827ecadd2e3d23db6ae92de9f112c7d4f3e12a1347f0e56a758558db6b2aed3d \
    "$property_dir/system.build.prop"
verify_sha256 1b05f6af77f2d37918041116878d3ad2e9d513094755eea08694ced2dcb9d42e \
    "$property_dir/vendor.build.prop"
python3 - "$property_dir/system.build.prop" "$property_dir/vendor.build.prop" \
    "$root/prop.default" "$root/default.prop" <<'PY'
import os
import re
import stat
import sys
import tempfile

system_props, vendor_props, target_path, default_link = sys.argv[1:]
keys = (
    "ro.build.version.release",
)
# KeyMint validates FBE metadata key blobs against the Recovery-reported OS
# and vendor patchlevels. After an OTA bumps the ROM's SPL, a blob upgraded by
# the new system is newer than this Recovery build's baked SPL and KeyMint
# rejects it with INVALID_KEY_BLOB (-33). Recovery therefore does not bake SPLs
# into prop.default; dali-spl-override.sh sets them at boot from the installed
# system (see init.recovery.project.rc).
spl_keys = (
    "ro.build.version.security_patch",
    "ro.vendor.build.security_patch",
)


def values_from(path, wanted):
    values = {key: [] for key in wanted}
    with open(path, "r", encoding="utf-8", newline="") as stream:
        for raw in stream:
            line = raw.rstrip("\r\n")
            if "=" not in line or line.startswith("#"):
                continue
            key, value = line.split("=", 1)
            if key in values:
                values[key].append(value)
    result = {}
    for key, candidates in values.items():
        if not candidates or len(set(candidates)) != 1:
            raise SystemExit(
                "official property input must provide one unambiguous value for {}".format(key)
            )
        result[key] = candidates[0]
    return result


expected = {}
expected.update(values_from(system_props, keys))
# vendor.build.prop is hash-verified above; its SPL is applied at boot from the
# installed ROM instead of being baked here.

if not os.path.islink(default_link) or os.readlink(default_link) != "prop.default":
    raise SystemExit("default.prop must remain a prop.default symlink")

with open(target_path, "r", encoding="utf-8", newline="") as stream:
    original = stream.readlines()

seen = {key: 0 for key in keys}
seen_spl = {key: 0 for key in spl_keys}
rewritten = []
for raw in original:
    line = raw.rstrip("\r\n")
    ending = raw[len(line):]
    if "=" in line and not line.startswith("#"):
        key, _ = line.split("=", 1)
        if key in expected:
            seen[key] += 1
            rewritten.append("{}={}{}".format(key, expected[key], ending))
            continue
        if key in seen_spl:
            seen_spl[key] += 1
            continue
    rewritten.append(raw)

if any(count != 1 for count in seen.values()):
    raise SystemExit("Recovery prop.default must contain each target property exactly once")
if any(count > 1 for count in seen_spl.values()):
    raise SystemExit(
        "Recovery prop.default SPL properties must appear at most once for removal"
    )

mode = stat.S_IMODE(os.stat(target_path).st_mode)
directory = os.path.dirname(target_path)
fd, temporary = tempfile.mkstemp(prefix=".prop.default.dali.", dir=directory)
try:
    with os.fdopen(fd, "w", encoding="utf-8", newline="") as stream:
        stream.writelines(rewritten)
    os.chmod(temporary, mode)
    os.replace(temporary, target_path)
finally:
    if os.path.exists(temporary):
        os.unlink(temporary)

actual = values_from(target_path, keys)
if actual != expected:
    raise SystemExit("Recovery prop.default post-write verification failed")
with open(target_path, "r", encoding="utf-8", newline="") as stream:
    remaining = stream.read()
for key in seen_spl:
    if re.search(r"(?m)^" + re.escape(key) + r"=", remaining):
        raise SystemExit("SPL property still present in prop.default: " + key)
if not os.path.islink(default_link) or os.readlink(default_link) != "prop.default":
    raise SystemExit("default.prop symlink changed during property update")

PY

install -m 0644 "$script_dir/root/init.recovery.usb.rc" "$root/init.recovery.usb.rc"
install -m 0755 "$script_dir/root/system/bin/dali-spl-override.sh" "$root/system/bin/dali-spl-override.sh"
install -m 0755 "$script_dir/root/system/bin/dali-ensure-tee.sh" "$root/system/bin/dali-ensure-tee.sh"
install -m 0755 "$script_dir/root/system/bin/dali-prune-modules.sh" "$root/system/bin/dali-prune-modules.sh"
install -m 0755 "$script_dir/root/system/bin/dali-persist-label.sh" "$root/system/bin/dali-persist-label.sh"

python3 "$script_dir/patch-ap-touch-modules.py" "$module_dir" "$root/lib/modules" ||
    die "failed to stage Recovery-only AP touch modules"
for module in scp.ko goodix_core_dali.ko xiaomi_touch_dali.ko modules.dep \
    flashlight.ko leds-mt6379.ko leds-mt6379pmic.ko mtk_gpueb.ko mtk_pbm.ko \
    mtk_peak_power_budget.ko cl_dsp-core.ko cs40l26-core.ko cs40l26-i2c.ko \
    cs40l26-spi.ko snd-soc-cs40l26.ko
do
    test -f "$root/lib/modules/$module" || die "missing staged module input: $module"
done

find "$root/lib/modules" -type f -iname "*focaltech*" -delete
find "$root/lib/modules" -type l -iname "*focaltech*" -delete
stale_focaltech=$(find "$root/lib/modules" -iname "*focaltech*" -print -quit)
[ -z "$stale_focaltech" ] || die "stale FocalTech entry remains in Recovery root"
if grep -F -- "focaltech_touch_dali.ko" "$root/lib/modules/modules.dep" >/dev/null; then
    die "Recovery module metadata still references FocalTech"
fi

# CS40L26 haptic firmware must be reachable from the kernel firmware loader
# without mounting the real vendor partition. Stage the official vendor files
# into both standard firmware roots of the Recovery ramdisk and verify them.
test -d "$firmware_dir" || die "missing recovery firmware input directory"
for firmware in cs40l26.wmfw cs40l26.bin cs40l26-calib.wmfw cs40l26-calib.bin \
    cs40l26-a2h.bin cs40l26-a2h1.bin cs40l26-dbc.bin cs40l26-dvl.bin cs40l26-svc.bin
do
    test -f "$firmware_dir/$firmware" || die "missing firmware input: $firmware"
done
verify_sha256 05f846c6164f5f8c41f53ba5dd625146e1b61495eef5f87346c015dbb2b56edd "$firmware_dir/cs40l26.wmfw"
verify_sha256 60d2a161c14242f33351fc820cc4c9de9bba56edb56904accf3d48d254f4b631 "$firmware_dir/cs40l26.bin"
verify_sha256 9ea0eccf985af55afbeed5e7eff7e8683025aa18023dd4536129f0d07907701f "$firmware_dir/cs40l26-calib.wmfw"
verify_sha256 bae013ffdcb3f28164f9dfeed387bd889e8d42a093cf956433ba2fccf1cb9251 "$firmware_dir/cs40l26-calib.bin"
verify_sha256 71309bdcb6a9e5a9990e4ca7238dd8802ddc1e531aa0ed755f6363e51a2bb4bd "$firmware_dir/cs40l26-a2h.bin"
verify_sha256 f95c1d842a672882782ab4900b9184240a7d34040c69cdde63f7ead1560835c8 "$firmware_dir/cs40l26-a2h1.bin"
verify_sha256 1dc4a2db7a23fac6e31465efcbdc6a5e46927e5e49f013fc38ed443f3216582f "$firmware_dir/cs40l26-dbc.bin"
verify_sha256 a7ee03eb89c8116b7e6a00d2cf8d99ae0eb652668137358a02698f2d6b91df09 "$firmware_dir/cs40l26-dvl.bin"
verify_sha256 84d15789a59d195a3d64bcba1fe02133b7ab2094b1ed781dff337e3ba63e5d15 "$firmware_dir/cs40l26-svc.bin"
install -d -m 0755 "$root/vendor/firmware"
install -m 0644 "$firmware_dir"/* "$root/vendor/firmware/"
for firmware in "$root/vendor/firmware"/cs40l26*
do
    base=${firmware##*/}
    cmp -s "$firmware" "$firmware_dir/$base" || die "firmware copy verification failed: $firmware"
done

# The Recovery image is assembled from an incremental root that can retain a
# stale libminuitwrp (the OrangeFox manifest installs the fresh library only
# into the system image).  Stage the freshly built library explicitly so the
# EV_FF haptics backend compiled into events.cpp is actually present at
# runtime, and refuse to package a copy that lacks the EVIOCSFF ioctl code.
product_root=$(dirname -- "$(dirname -- "$root")")
built_lib="$product_root/system/lib64/libminuitwrp.so"
[ -f "$built_lib" ] || die "missing built libminuitwrp.so: $built_lib"
if ! grep -aq "dali-evff" "$built_lib"; then
    die "built libminuitwrp.so lacks the dali-evff haptics backend marker"
fi
install -m 0644 "$built_lib" "$root/system/lib64/libminuitwrp.so"
cmp -s "$built_lib" "$root/system/lib64/libminuitwrp.so" ||
    die "libminuitwrp.so staging verification failed"

vendor_hal_src="$vendor_hal_dir"
vendor_hal_dst="$root/vendor"
# Remove the pre-r74 legacy location so incremental builds do not
# package a duplicate closure.
rm -rf -- "$root/system/vendor_hal"
rm -rf -- "$root/system/bin/vendor_hal"
rm -rf -- "$vendor_hal_dst/bin" "$vendor_hal_dst/lib64" "$vendor_hal_dst/mitee"
mkdir -p "$vendor_hal_dst"
cp -a -- "$vendor_hal_src/." "$vendor_hal_dst/"
for bin in \
    bin/tee-supplicant \
    bin/hw/android.hardware.security.keymint@3.0-service.mitee \
    bin/hw/android.hardware.gatekeeper-service.mitee \
    bin/hw/android.hardware.weaver-service.nxp \
    bin/hw/vendor.xiaomi.hardware.secure_element-service \
    bin/hw/android.hardware.boot-service.mtk
do
    test -x "$vendor_hal_dst/$bin" || die "missing vendor HAL binary: $bin"
done
test -d "$vendor_hal_dst/mitee/ta" || die "missing vendor HAL TA directory"
ta_count=$(find "$vendor_hal_dst/mitee/ta" -type f | wc -l)
[ "$ta_count" -ge 10 ] || die "unexpected vendor HAL TA count: $ta_count"
lib_count=$(find "$vendor_hal_dst/lib64" -type f | wc -l)
[ "$lib_count" -ge 30 ] || die "unexpected vendor HAL library count: $lib_count"

# The safe platform trim removes /system/lib64/libc++.so (an official
# recovery duplicate). Keep the merged boot rootfs self-sufficient by also
# shipping the platform libc++ in the Recovery fragment.
cp -f -- "$vendor_hal_dst/lib64/libc++.so" "$root/system/lib64/libc++.so"

# Ensure dmctl is present in the Recovery ramdisk so OTA snapshot cleanup can
# remove stale dm devices before update_engine_sideload.
source_root=$(CDPATH= cd -- "$device_root/../../.." && pwd)
dmctl_src="$source_root/out/target/product/dali/system/bin/dmctl"
if [ -f "$dmctl_src" ]; then
    install -m 0755 "$dmctl_src" "$root/system/bin/dmctl"
else
    die "built dmctl not found: $dmctl_src"
fi

# Simplified Chinese UI: stock OrangeFox keeps zh_CN in extra-languages, so
# copy the language XML and its CJK font into the ramdisk. Reclaim space from
# font files and the unused "sed" splash theme that no active twres XML
# references (checked against ui.xml/style.xml/pages/*.xml).
# Keep only English + Simplified Chinese: stock OrangeFox parses every
# language XML at UI startup; trimming the other 28 files skips ~2.4 MiB of
# XML parsing on every boot.
rm -f "$root"/twres/languages/*.xml
install -m 0644 \
    "$script_dir/root/twres/languages/zh_CN.xml" \
    "$root/twres/languages/zh_CN.xml"
install -m 0644 \
    "$source_root/bootable/recovery/gui/theme/common/languages/en.xml" \
    "$root/twres/languages/en.xml"
install -m 0644 \
    "$source_root/bootable/recovery/gui/theme/extra-languages/fonts/DroidSansFallback.ttf" \
    "$root/twres/fonts/DroidSansFallback.ttf"
rm -f "$root/twres/fonts/Chococooky.ttf" \
      "$root/twres/fonts/FiraCode-Medium.ttf" \
      "$root/twres/fonts/Exo2-Medium.ttf" \
      "$root/twres/fonts/EuclidFlex-Medium.ttf"
rm -rf "$root/twres/themes/sed"

# fox_fix_date is staged by the OrangeFox build inside the official FFiles
# tree; install it into /sbin (the path fix_date is rewritten to use below)
# and then drop the FFiles tree so it does not end up in the image.
if [ -f "$root/FFiles/fox_fix_date" ]; then
    install -D -m 0755 "$root/FFiles/fox_fix_date" "$root/sbin/fox_fix_date"
fi
[ ! -e "$root/FFiles" ] || rm -rf -- "$root/FFiles"
[ ! -e "$root/FFiles" ] || die "FFiles directory still present after cleanup"

# fix_date / mkshrc are copied in by the OrangeFox build script from the
# official FFiles tree and still point into /FFiles; rewrite them in place.
for f in "$root/sbin/fix_date" "$root/system/etc/mkshrc"
do
    [ -f "$f" ] || continue
    sed -i 's|cp -a /FFiles/fox_fix_date $fox_home|cp -a /sbin/fox_fix_date $fox_home|' "$f"
    sed -i '\|/FFiles|d' "$f"
done
[ -e "$root/system/bin/ps" ] || die "Recovery root lacks /system/bin/ps for FOX_PS_BIN"
ffiles_refs=$(grep -rIl --exclude-dir=twres --exclude=ramdisk-files.txt --exclude=ramdisk-files.sha256sum -- "/FFiles" "$root" 2>/dev/null | head -1)
[ -z "$ffiles_refs" ] || die "Recovery root still references /FFiles: $ffiles_refs"

# Recovery image slimming: remove libraries that no ELF in the ramdisk links
# or dlopens. The list was derived from a transitive NEEDED closure over every
# executable and shared library in the merged root, then cross-checked for
# runtime dlopen string references in every other ELF (zero found).
SLIM_LIBS="android.frameworks.stats-V1-ndk.so
android.hardware.vibrator-V1-cpp.so
android.hardware.vibrator-V1-ndk.so
android.hardware.vibrator-V2-cpp.so
android.hardware.vibrator-V2-ndk.so
android.hardware.vibrator@1.2.so
android.system.keystore2-V3-ndk.so
android.system.suspend@1.0.so
android.system.wifi.keystore@1.0.so
libadbd.so
libadbd_services.so
libandroid_runtime_lazy.so
libext2_profile.so
libhidltransport.so
libnos_datagram.so
libnos_transport.so
libservices.so
libsoftkeymasterdevice.so
libutilscallstack.so
libxml2.so"
for lib in $SLIM_LIBS
do
    rm -f -- "$root/system/lib64/$lib"
done

# After slimming, verify that every NEEDED library of every ELF executable and
# shared library still resolves inside the ramdisk. A missing dependency aborts
# the build instead of shipping a broken Recovery.
verify_needed_libs() {
    elf=$1
    needed_list=$(mktemp "$root/.dali-needed.XXXXXX")
    "$llvm_readobj" --dynamic-table "$elf" 2>/dev/null |
        sed -n 's/.*Shared library: \[\(.*\)\].*/\1/p' > "$needed_list" || true
    while read -r lib
    do
        [ -n "$lib" ] || continue
        [ -f "$root/system/lib64/$lib" ] ||
        [ -f "$root/system/lib64/hw/$lib" ] ||
        [ -f "$root/vendor/lib64/$lib" ] ||
        [ -f "$root/vendor/lib64/hw/$lib" ] ||
        [ -f "$root/odm/lib64/$lib" ] ||
        [ -f "$root/odm/lib64/hw/$lib" ] ||
            die "slimmed Recovery root is missing NEEDED library $lib for $elf"
    done < "$needed_list"
    rm -f -- "$needed_list"
}
elf_magic=$(printf '\177ELF')
for dir in system/bin system/lib64 system/lib64/hw vendor/bin vendor/lib64 vendor/lib64/hw vendor/bin/hw
do
    for elf in "$root/$dir"/*
    do
        [ -f "$elf" ] || continue
        [ "$(head -c 4 "$elf" 2>/dev/null)" = "$elf_magic" ] || continue
        verify_needed_libs "$elf"
    done
done

# The normal Recovery RC retains the recovery SELinux domain. The variant RC
# would define the same service name, and OrangeFox appends Bash/Nano wrappers
# after its feature filters. The marker is only an incremental-build input.
rm -f "$root/system/etc/init/servicemanager.recovery.rc" \
    "$root/sbin/bash" \
    "$root/sbin/nano" \
    "$root/dali_recovery_prepare_marker-timestamp"
cd "$root"
find . | sed "s/.\\///" > ramdisk-files.txt
find -type f | sed "s/.\\/ramdisk-files.sha256sum//" | sed "/prop.default/d" |
    xargs sha256sum > ramdisk-files.sha256sum
