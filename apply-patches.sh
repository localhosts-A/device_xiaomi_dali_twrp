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

PATCH_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/patches/recovery"

[ -d bootable/recovery ] || {
    echo "error: run from the OrangeFox source root (bootable/recovery not found)" >&2
    exit 1
}

p="$PATCH_DIR"

git -C bootable/recovery apply "$p/0001-feat-flash-current-orangefox-recovery-fragment.patch"
git -C bootable/recovery apply "$p/0002-feat-protect-standard-lk-writes.patch"
git -C bootable/recovery apply "$p/0003-fix-flash-current-target-platform.patch"
git -C bootable/recovery apply "$p/0004-protect-ota-preloader-aliases.patch"
git apply -p1 "$p/0005-protect-ota-verifier.patch"
git -C bootable/recovery apply "$p/0006-fix-format-data-unmap-userdata.patch"
git -C bootable/recovery apply "$p/0007-skip-pending-merge-before-format.patch"
git -C bootable/recovery apply -p3 "$p/0008-fix-sideload-vendor-unmount-cancel.patch"
git -C bootable/recovery apply -p3 "$p/0009-fix-sideload-completion-page.patch"
git -C bootable/recovery apply -p1 "$p/0010-fix-cli-sideload-cleanup.patch"
git -C bootable/recovery apply -p1 "$p/0011-fix-ab-ota-mounted-system-vendor.patch"
git -C bootable/recovery apply -p1 "$p/0012-fix-lk-virtual-capacity.patch"
git -C bootable/recovery apply -p1 "$p/0013-fix-ab-ota-snapshot-cleanup.patch"
git -C system/core/fs_mgr apply -p1 "$p/0014-fix-ab-snapshot-cancel-recovery.patch"
git -C system/core/fs_mgr apply -p3 "$p/0015-allow-new-update-after-merge.patch"
git -C bootable/recovery apply -p1 "$p/0016-fix-ors-sideload-mtp-restore.patch"
git -C bootable/recovery apply -p1 "$p/0017-fix-flash-current-gzip-trimmed-fragments.patch"
git -C bootable/recovery apply -p1 "$p/0018-fix-flash-current-fail-safe-no-trim.patch"
git -C bootable/recovery apply -p1 "$p/0019-fix-flash-current-safe-trim.patch"
git -C bootable/recovery apply -p1 "$p/0022-skip-vendor-module-mount.patch"
git -C bootable/recovery apply -p1 "$p/0023-retry-metadata-decrypt.patch"
git -C system/update_engine apply "$p/0026-allow-spl-downgrade.patch"
git -C bootable/recovery apply -p1 "$p/0027-allow-spl-downgrade-twinstall.patch"
git -C system/core/fs_mgr apply -p1 "$p/0028-allow-spl-downgrade-image-delete.patch"
git -C system/update_engine apply --recount "$p/0029-fix-spl-source-installed-system.patch"
git -C bootable/recovery apply -p1 "$p/0030-fix-ab-ota-stale-snapshot-status.patch"
git apply -p1 "$p/0031-fix-slidervalue-handle-centering.patch"
git apply -p1 "$p/0032-feat-evff-haptics-backend.patch"
git -C bootable/recovery apply "$p/0033-silence-redundant-property-set.patch"
git -C bootable/recovery apply --recount "$p/0035-hyperos3-rom-label.patch"
git -C bootable/recovery apply "$p/0036-localization-no-dst.patch"
git -C bootable/recovery apply --recount "$p/0038-default-zh-cn-timezone.patch"
git -C bootable/recovery apply "$p/0039-taller-about-cards.patch"
git apply -p1 "$p/0040-screenshots-pictures-path.patch"
git -C bootable/recovery apply "$p/0041-fox-ps-bin-system-bin.patch"
git -C bootable/recovery apply "$p/0044-fix-mtp-advise-noise.patch"
git -C bootable/recovery apply "$p/0045-fix-prepare-super-iterator.patch"
git -C bootable/recovery apply --recount "$p/0046-fox-spl-downgrade-ui.patch"
git -C bootable/recovery apply "$p/0042-fox-allow-non-vanilla-vab.patch"

echo "All Dali OrangeFox patches applied successfully."
