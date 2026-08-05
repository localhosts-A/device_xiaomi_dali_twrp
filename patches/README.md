# OrangeFox Source Patches

This directory records source-level exceptions intentionally distributed with
this device tree. Patches are not applied automatically by the build system.
Review and apply each patch against its recorded source revision before a
build. Other authorized source exceptions are maintained separately and listed
in the top-level README.

| Patch | Target | OrangeFox Recovery base | Purpose |
| --- | --- | --- | --- |
| `recovery/0001-feat-flash-current-orangefox-recovery-fragment.patch` | `bootable/recovery/twrpRepacker.cpp` | `1b85e0272c19d20acfec176eed6aa46a610b4ec1` | Replace only the inactive vendor_boot Recovery fragment and update its AVB hash descriptor. |
| `recovery/0002-feat-protect-standard-lk-writes.patch` | `bootable/recovery` | `1b85e0272c19d20acfec176eed6aa46a610b4ec1` | Add the Dali default-enabled ZIP/sideload LK virtual-target protection helper. |
| `recovery/0003-fix-flash-current-target-platform.patch` | `bootable/recovery/twrpRepacker.cpp` | `1b85e0272c19d20acfec176eed6aa46a610b4ec1` | Make Flash Current target-aware: rebuild the inactive vendor_boot with its own platform fragment trimmed against the Recovery fragment. |
| `recovery/0004-protect-ota-preloader-aliases.patch` | `bootable/recovery/lk_protection_exec.c` | `1b85e0272c19d20acfec176eed6aa46a610b4ec1` | Virtualize OTA `preloader_raw` aliases with sized zero backing so protected OTAs never write preloader. |
| `recovery/0005-protect-ota-verifier.patch` | `bootable/recovery/lk_protection_exec.c`, `system/update_engine/payload_consumer/filesystem_verifier_action.cc` | `1b85e0272c19d20acfec176eed6aa46a610b4ec1` | Route OTA verifier reads of protected boot-chain targets through the virtual devices. |
| `recovery/0006-fix-format-data-unmap-userdata.patch` | `bootable/recovery/partition.cpp` | `1b85e0272c19d20acfec176eed6aa46a610b4ec1` | Destroy the /data default-key dm mapping before formatting so make_f2fs can open the raw userdata partition. |
| `recovery/0007-skip-pending-merge-before-format.patch` | `bootable/recovery/partitionmanager.cpp` | `1b85e0272c19d20acfec176eed6aa46a610b4ec1` | When `of.skip_format_pending_merge` is set (device tree), skip the pending Virtual A/B merge/unmap pre-check before Format Data. |
| `recovery/0008-fix-sideload-vendor-unmount-cancel.patch` | `bootable/recovery` (`twrpinstall/twinstall.cpp`, `gui/action.cpp`) | `1b85e0272c19d20acfec176eed6aa46a610b4ec1` | Keep vendor mounted during FUSE sideload and make graphical cancellation bounded (restart adbd, release the page). |
| `recovery/0009-fix-sideload-completion-page.patch` | `bootable/recovery` (`gui/action.cpp`, `gui/gui.cpp`) | `1b85e0272c19d20acfec176eed6aa46a610b4ec1` | Return both GUI and ORS sideload completion flows to the main page. |
| `recovery/0010-fix-cli-sideload-cleanup.patch` | `bootable/recovery` (`gui/action.cpp`, `twrpinstall/adb_install.cpp`, `openrecoveryscript.cpp`) | `1b85e0272c19d20acfec176eed6aa46a610b4ec1` | Remove duplicate CLI FUSE installation/cleanup and propagate the first install's cache-wipe result once. |
| `recovery/0011-fix-ab-ota-mounted-system-vendor.patch` | `bootable/recovery/twrpinstall/twinstall.cpp` | `1b85e0272c19d20acfec176eed6aa46a610b4ec1` | Classify local update-binary ZIPs (AOSP-style) vs A/B payload ZIPs (HyperOS) and preserve system/vendor mounts for the A/B path. |
| `recovery/0012-fix-lk-virtual-capacity.patch` | `bootable/recovery/lk_protection_exec.c` | `1b85e0272c19d20acfec176eed6aa46a610b4ec1` | Size virtual LK backing files from the native LK capacity instead of a fixed size. |
| `recovery/0013-fix-ab-ota-snapshot-cleanup.patch` | `bootable/recovery/twrpinstall/twinstall.cpp` | `1b85e0272c19d20acfec176eed6aa46a610b4ec1` | Before `update_engine_sideload`: unmount current-slot super mounts, delete stale snapshot dm devices via `dmctl`, mount `/metadata`. |
| `recovery/0014-fix-ab-snapshot-cancel-recovery.patch` | `system/core/fs_mgr/libsnapshot/snapshot.cpp` | `1b85e0272c19d20acfec176eed6aa46a610b4ec1` | Allow cancelling Unverified Virtual A/B updates in Recovery and remove stale COW devices on retry. |
| `recovery/0015-allow-new-update-after-merge.patch` | `system/core/fs_mgr/libsnapshot/snapshot.cpp` | `1b85e0272c19d20acfec176eed6aa46a610b4ec1` | `BeginUpdate()` accepts `MergeCompleted` so a new OTA can start after a merge in the same Recovery session. |
| `recovery/0016-fix-ors-sideload-mtp-restore.patch` | `bootable/recovery/openrecoveryscript.cpp` | `1b85e0272c19d20acfec176eed6aa46a610b4ec1` | Restore the MTP server around ORS/CLI sideload so the configfs gadget can re-enable after minadbd exits (adbd + MTP must both be ready). |
| `recovery/0017-fix-flash-current-gzip-trimmed-fragments.patch` | `bootable/recovery/twrpRepacker.cpp` | `1b85e0272c19d20acfec176eed6aa46a610b4ec1` | Re-compress trimmed inactive vendor_boot fragments with gzip (including the DTB in the repack directory) before MagiskBoot repack so Flash current OrangeFox fits the 64 MiB partition, keeps its DTB, and its AVB footer can be repaired. |
| `recovery/0018-fix-flash-current-fail-safe-no-trim.patch` | `bootable/recovery/twrpRepacker.cpp` | `1b85e0272c19d20acfec176eed6aa46a610b4ec1` | Refuse Flash current OrangeFox when the inactive vendor_boot cannot fit the current Recovery fragment without trimming the platform; trimming breaks normal boot (first-stage init loses fstab/ueventd and panics). |
| `recovery/0019-fix-flash-current-safe-trim.patch` | `bootable/recovery/twrpRepacker.cpp` + `recovery/root/system/bin/dali-safe-trim.sh` | `1b85e0272c19d20acfec176eed6aa46a610b4ec1` | Safe-trim Flash current: remove from the inactive platform only entries byte-identical to that slot's official Recovery fragment (keeps normal-boot fstab/ueventd/init/sepolicy), then gzip-repack with DTB. |
| `recovery/0022-skip-vendor-module-mount.patch` | `bootable/recovery/kernel_module_loader.cpp` | `1b85e0272c19d20acfec176eed6aa46a610b4ec1` | Gate KernelModuleLoader vendor/vendor_dlkm mounts behind `of.skip_vendor_module_mount`; modules already live in the ramdisk, so the real vendor stays unmounted and the HAL closure/labels remain valid. |
| `recovery/0023-retry-metadata-decrypt.patch` | `bootable/recovery/partitionmanager.cpp` | `1b85e0272c19d20acfec176eed6aa46a610b4ec1` | Retry FBE metadata decryption (up to 20 x 500ms) so keystore2/KeyMint have time to become ready after the crypto HAL chain starts. |
| `recovery/0026-allow-spl-downgrade.patch` | `system/update_engine` (`aosp/hardware_android.cc`, `payload_consumer/delta_performer.cc`) | `1b85e0272c19d20acfec176eed6aa46a610b4ec1` | Allow SPL-downgrade OTAs when `of.allow_spl_downgrade=1` is set (skips the locked-bootloader SPL rejection and permits payload timestamp downgrade). |
| `recovery/0027-allow-spl-downgrade-twinstall.patch` | `bootable/recovery/twrpinstall/twinstall.cpp` | `1b85e0272c19d20acfec176eed6aa46a610b4ec1` | Set `of.allow_spl_downgrade=1` before running update_engine when the `tw_allow_spl_downgrade` checkbox is enabled. |
| `recovery/0028-allow-spl-downgrade-image-delete.patch` | `system/core/fs_mgr/libfiemap/image_manager.cpp` | `1b85e0272c19d20acfec176eed6aa46a610b4ec1` | Allow deleting /data-backed snapshot images during SPL downgrade even when /data is encrypted/undecrypted. |
| `recovery/0029-fix-spl-source-installed-system.patch` (apply with `--recount`) | `system/update_engine/payload_consumer/delta_performer.cc` | `1b85e0272c19d20acfec176eed6aa46a610b4ec1` | Use `of.installed_os_spl` (set by the device tree from the installed ROM) as the current SPL for OTA downgrade checks, so Recovery can report a KeyMint-compatible patchlevel. |
| `recovery/0030-fix-ab-ota-stale-snapshot-status.patch` | `bootable/recovery/twrpinstall/twinstall.cpp` | `1b85e0272c19d20acfec176eed6aa46a610b4ec1` | Remove stale current-slot `/metadata/ota/snapshots/*_a` status files before a new A/B OTA so `FinishUpdate()` does not fail on snapshot devices that were already cleaned. |
| `recovery/0031-fix-slidervalue-handle-centering.patch` | `bootable/recovery/gui/slidervalue.cpp` | `1b85e0272c19d20acfec176eed6aa46a610b4ec1` | Blit slider handles from the hover image size so the handle stays centered on the line. |
| `recovery/0032-feat-evff-haptics-backend.patch` | `bootable/recovery/minuitwrp/events.cpp` | `1b85e0272c19d20acfec176eed6aa46a610b4ec1` | Add an EV_FF force-feedback haptics backend for the CS40L26 input device, tried before the legacy sysfs paths. |
| `recovery/0033-silence-redundant-property-set.patch` | `bootable/recovery/twrp-functions.cpp` | `1b85e0272c19d20acfec176eed6aa46a610b4ec1` | Skip redundant writes to read-only properties so bionic stops logging `Unable to set property ... 0xb` during Recovery startup. |
| `recovery/0035-hyperos3-rom-label.patch` (apply with `--recount`) | `bootable/recovery/twrp-functions.cpp` | `1b85e0272c19d20acfec176eed6aa46a610b4ec1` | Prefer the device-codename (`dali`) fingerprint from vendor build.prop and label the installed ROM as HyperOS 3 when the fingerprint/incremental carries `OS3.`. |
| `recovery/0036-localization-no-dst.patch` | `bootable/recovery/data.cpp` | `1b85e0272c19d20acfec176eed6aa46a610b4ec1` | Default the timezone GUI to DST-off (`TW_TIME_ZONE_GUIDST=0`). |
| `recovery/0038-default-zh-cn-timezone.patch` (apply with `--recount`) | `bootable/recovery/twrp.cpp` | `1b85e0272c19d20acfec176eed6aa46a610b4ec1` | Force zh_CN and Asia/Shanghai defaults when no explicit settings store exists yet. |
| `recovery/0039-taller-about-cards.patch` | `bootable/recovery/gui/theme/portrait_hdpi/images/SVG/About/card.svg` | `1b85e0272c19d20acfec176eed6aa46a610b4ec1` | Extend the About card image downward by 48px (device vars adjust spacing/text). |
| `recovery/0040-screenshots-pictures-path.patch` | `bootable/recovery/gui/action.cpp` | `1b85e0272c19d20acfec176eed6aa46a610b4ec1` | Route Recovery screenshots to `/sdcard/Pictures` (derived from the internal storage path). |
| `recovery/0041-fox-ps-bin-system-bin.patch` | `bootable/recovery/variables.h` | `1b85e0272c19d20acfec176eed6aa46a610b4ec1` | Point the Fox `ps` helper at `/system/bin` (no `toybox` fallback path). |
| `recovery/0042-fox-allow-non-vanilla-vab.patch` | `bootable/recovery/orangefox.mk` | `1b85e0272c19d20acfec176eed6aa46a610b4ec1` | Allow non-vanilla VAB installs (relax the vanilla-super sanity check for Fox builds). |
| `recovery/0044-fix-mtp-advise-noise.patch` | `bootable/recovery/mtp/ffs/MtpFfsHandle.cpp` | `1b85e0272c19d20acfec176eed6aa46a610b4ec1` | Drop a noisy MTP advise log (cosmetic). |
| `recovery/0045-fix-prepare-super-iterator.patch` | `bootable/recovery/partitionmanager.cpp` | `1b85e0272c19d20acfec176eed6aa46a610b4ec1` | Fix undefined behaviour of the prepare-super logical-volume iterator (post-increment on erase). |
| `recovery/0046-fox-spl-downgrade-ui.patch` (apply with `--recount`) | `bootable/recovery/gui/theme/portrait_hdpi/pages/{install,advanced}.xml` | `1b85e0272c19d20acfec176eed6aa46a610b4ec1` | Add the "Allow SPL downgrade" checkbox after every lk-protect block (flash_confirm / fox_modules / advanced pages). |

Apply from the OrangeFox source root:

```bash
# Run from the OrangeFox source root. Patches whose headers are repository-relative
# (a/bootable/recovery/..., a/system/...) must be applied from the root with -p1.
DT=<device-tree>
git -C bootable/recovery apply \
  $DT/patches/recovery/0001-feat-flash-current-orangefox-recovery-fragment.patch
git -C bootable/recovery apply \
  $DT/patches/recovery/0002-feat-protect-standard-lk-writes.patch
git -C bootable/recovery apply \
  $DT/patches/recovery/0003-fix-flash-current-target-platform.patch
git -C bootable/recovery apply \
  $DT/patches/recovery/0004-protect-ota-preloader-aliases.patch
git apply -p1 \
  $DT/patches/recovery/0005-protect-ota-verifier.patch
git -C bootable/recovery apply \
  $DT/patches/recovery/0006-fix-format-data-unmap-userdata.patch
git -C bootable/recovery apply \
  $DT/patches/recovery/0007-skip-pending-merge-before-format.patch
git -C bootable/recovery apply -p3 \
  $DT/patches/recovery/0008-fix-sideload-vendor-unmount-cancel.patch
git -C bootable/recovery apply -p3 \
  $DT/patches/recovery/0009-fix-sideload-completion-page.patch
git -C bootable/recovery apply -p1 \
  $DT/patches/recovery/0010-fix-cli-sideload-cleanup.patch
git -C bootable/recovery apply -p1 \
  $DT/patches/recovery/0011-fix-ab-ota-mounted-system-vendor.patch
git -C bootable/recovery apply -p1 \
  $DT/patches/recovery/0012-fix-lk-virtual-capacity.patch
git -C bootable/recovery apply -p1 \
  $DT/patches/recovery/0013-fix-ab-ota-snapshot-cleanup.patch
git -C system/core/fs_mgr apply -p1 \
  $DT/patches/recovery/0014-fix-ab-snapshot-cancel-recovery.patch
git -C system/core/fs_mgr apply -p3 \
  $DT/patches/recovery/0015-allow-new-update-after-merge.patch
git -C bootable/recovery apply -p1 \
  $DT/patches/recovery/0016-fix-ors-sideload-mtp-restore.patch
git -C bootable/recovery apply -p1 \
  $DT/patches/recovery/0017-fix-flash-current-gzip-trimmed-fragments.patch
git -C bootable/recovery apply -p1 \
  $DT/patches/recovery/0018-fix-flash-current-fail-safe-no-trim.patch
git -C bootable/recovery apply -p1 \
  $DT/patches/recovery/0019-fix-flash-current-safe-trim.patch
git -C bootable/recovery apply -p1 \
  $DT/patches/recovery/0022-skip-vendor-module-mount.patch
git -C bootable/recovery apply -p1 \
  $DT/patches/recovery/0023-retry-metadata-decrypt.patch
git -C system/update_engine apply \
  $DT/patches/recovery/0026-allow-spl-downgrade.patch
git -C bootable/recovery apply -p1 \
  $DT/patches/recovery/0027-allow-spl-downgrade-twinstall.patch
git -C system/core/fs_mgr apply -p1 \
  $DT/patches/recovery/0028-allow-spl-downgrade-image-delete.patch
git -C system/update_engine apply --recount \
  $DT/patches/recovery/0029-fix-spl-source-installed-system.patch
git -C bootable/recovery apply -p1 \
  $DT/patches/recovery/0030-fix-ab-ota-stale-snapshot-status.patch
git apply -p1 \
  $DT/patches/recovery/0031-fix-slidervalue-handle-centering.patch
git apply -p1 \
  $DT/patches/recovery/0032-feat-evff-haptics-backend.patch
git -C bootable/recovery apply \
  $DT/patches/recovery/0033-silence-redundant-property-set.patch
git -C bootable/recovery apply --recount \
  $DT/patches/recovery/0035-hyperos3-rom-label.patch
git -C bootable/recovery apply \
  $DT/patches/recovery/0036-localization-no-dst.patch
git -C bootable/recovery apply --recount \
  $DT/patches/recovery/0038-default-zh-cn-timezone.patch
git -C bootable/recovery apply \
  $DT/patches/recovery/0039-taller-about-cards.patch
git apply -p1 \
  $DT/patches/recovery/0040-screenshots-pictures-path.patch
git -C bootable/recovery apply \
  $DT/patches/recovery/0041-fox-ps-bin-system-bin.patch
git -C bootable/recovery apply \
  $DT/patches/recovery/0044-fix-mtp-advise-noise.patch
git -C bootable/recovery apply \
  $DT/patches/recovery/0045-fix-prepare-super-iterator.patch
git -C bootable/recovery apply --recount \
  $DT/patches/recovery/0046-fox-spl-downgrade-ui.patch
git -C bootable/recovery apply \
  $DT/patches/recovery/0042-fox-allow-non-vanilla-vab.patch
```
