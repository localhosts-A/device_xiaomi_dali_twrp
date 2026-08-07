#!/bin/sh
set -eu
# apply-patches.sh
# Apply every Dali OrangeFox 14.1 source patch on top of a pristine OrangeFox
# 14.1 sync (bootable/recovery base commit:
# 1b85e0272c19d20acfec176eed6aa46a610b4ec1).
#
# Run this script from the root of the OrangeFox source checkout:
#   sh /path/to/device_xiaomi_dali_twrp/apply-patches.sh
#
# Patches are stored under patches/recovery/ in this tree. The script mirrors
# the exact application order and path conventions used for release builds.
#
# Note: 0035/0038/0046 have hunk-header line drift; git apply --recount is
# used for them, and every patch falls back to `patch -p1 --fuzz=3` if git
# apply fails (whitespace/context drift).

PATCH_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/patches/recovery"

[ -d bootable/recovery ] || {
    echo "error: run from the OrangeFox source root (bootable/recovery not found)" >&2
    exit 1
}

p="$PATCH_DIR"

# apply_one <repo-or-.> <git-apply-extra-args> <patch-file>
# repo "." means run from the source root; otherwise git -C <repo>.
apply_one() {
    repo=$1
    shift
    extra=$1
    shift
    patch_file=$1
    if [ "$repo" = "." ]; then
        if git apply $extra "$patch_file"; then
            return 0
        fi
        echo "git apply failed for $(basename "$patch_file"), retrying with patch --fuzz=3" >&2
        patch -p1 --fuzz=3 --forward < "$patch_file"
        return $?
    else
        if git -C "$repo" apply $extra "$patch_file"; then
            return 0
        fi
        echo "git apply failed for $(basename "$patch_file"), retrying with patch --fuzz=3" >&2
        (cd "$repo" && patch -p1 --fuzz=3 --forward < "$patch_file")
        return $?
    fi
}

apply_one bootable/recovery "" "$p/0001-feat-flash-current-orangefox-recovery-fragment.patch"
apply_one bootable/recovery "" "$p/0002-feat-protect-standard-lk-writes.patch"
apply_one bootable/recovery "" "$p/0003-fix-flash-current-target-platform.patch"
apply_one bootable/recovery "" "$p/0004-protect-ota-preloader-aliases.patch"
apply_one . "-p1" "$p/0005-protect-ota-verifier.patch"
apply_one bootable/recovery "" "$p/0006-fix-format-data-unmap-userdata.patch"
apply_one bootable/recovery "" "$p/0007-skip-pending-merge-before-format.patch"
apply_one bootable/recovery "-p3" "$p/0008-fix-sideload-vendor-unmount-cancel.patch"
apply_one bootable/recovery "-p3" "$p/0009-fix-sideload-completion-page.patch"
apply_one bootable/recovery "-p1" "$p/0010-fix-cli-sideload-cleanup.patch"
apply_one bootable/recovery "-p1" "$p/0011-fix-ab-ota-mounted-system-vendor.patch"
apply_one bootable/recovery "-p1" "$p/0012-fix-lk-virtual-capacity.patch"
apply_one bootable/recovery "-p1" "$p/0013-fix-ab-ota-snapshot-cleanup.patch"
apply_one system/core/fs_mgr "-p1" "$p/0014-fix-ab-snapshot-cancel-recovery.patch"
apply_one system/core/fs_mgr "-p3" "$p/0015-allow-new-update-after-merge.patch"
apply_one bootable/recovery "-p1" "$p/0016-fix-ors-sideload-mtp-restore.patch"
apply_one bootable/recovery "-p1" "$p/0017-fix-flash-current-gzip-trimmed-fragments.patch"
apply_one bootable/recovery "-p1" "$p/0018-fix-flash-current-fail-safe-no-trim.patch"
apply_one bootable/recovery "-p1" "$p/0019-fix-flash-current-safe-trim.patch"
apply_one bootable/recovery "-p1" "$p/0022-skip-vendor-module-mount.patch"
apply_one bootable/recovery "-p1" "$p/0023-retry-metadata-decrypt.patch"
apply_one system/update_engine "" "$p/0026-allow-spl-downgrade.patch"
apply_one bootable/recovery "-p1" "$p/0027-allow-spl-downgrade-twinstall.patch"
apply_one system/core/fs_mgr "-p1" "$p/0028-allow-spl-downgrade-image-delete.patch"
apply_one system/update_engine "--recount" "$p/0029-fix-spl-source-installed-system.patch"
apply_one bootable/recovery "-p1" "$p/0030-fix-ab-ota-stale-snapshot-status.patch"
apply_one . "-p1" "$p/0031-fix-slidervalue-handle-centering.patch"
apply_one . "-p1" "$p/0032-feat-evff-haptics-backend.patch"
apply_one bootable/recovery "" "$p/0033-silence-redundant-property-set.patch"
apply_one bootable/recovery "--recount" "$p/0035-hyperos3-rom-label.patch"
apply_one bootable/recovery "" "$p/0036-localization-no-dst.patch"
apply_one bootable/recovery "--recount" "$p/0038-default-zh-cn-timezone.patch"
apply_one bootable/recovery "" "$p/0039-taller-about-cards.patch"
apply_one . "-p1" "$p/0040-screenshots-pictures-path.patch"
apply_one bootable/recovery "-p1" "$p/0041-fox-ps-bin-system-bin.patch"
apply_one bootable/recovery "" "$p/0044-fix-mtp-advise-noise.patch"
apply_one bootable/recovery "" "$p/0045-fix-prepare-super-iterator.patch"
apply_one bootable/recovery "--recount" "$p/0046-fox-spl-downgrade-ui.patch"
apply_one bootable/recovery "" "$p/0042-fox-allow-non-vanilla-vab.patch"

echo "All Dali OrangeFox patches applied successfully."
