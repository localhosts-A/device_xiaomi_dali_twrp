# Changelog

All notable changes are tracked against the published release artifacts.

## 2026-08-06 — Release `final2` (vendor_boot-release.img)

SHA-256 `48936a1a542f63e07aaf8c30a02c07109a49a22be9e775587f6f507e9d9c0a88`,
pre-AVB `62545920` / `67039232`.

### Features

- **SPL downgrade + VAB merge**: `update_engine` allows SPL downgrade when the
  user enables *Allow SPL downgrade* (default on, persisted); the Recovery
  fragment completes the virtual-A/B snapshot merge (`merge_ab_tool`) so a
  downgraded OTA boots without re-flashing.
- SPL-downgrade / LK-protection UI labels now use resource keys (`en` +
  `zh_CN`) instead of a build-time injection; the duplicated "Allow SPL
  downgrade" / "Allow Spl Downgrade" options are unified into a single control.
- `dali-spl-override.sh` mounts the installed system by name instead of
  passing the directory as a filesystem type (the SPL probe previously always
  fell back to the default value).
- MTP storage creation is wired into the mount path (`Add_Remove_MTP_Storage`
  ADD branch), so the `Internal Storage` mount point is created on demand.
- `dali-persist-label.sh` uses toybox `restorecon` (the previous
  `restorecon_recursive` call is an init builtin and always failed silently).
- Single-instance guards for `dali-log-persist.sh` and `dali-ensure-tee.sh`
  (pid files with kill -0 checks), preventing concurrent invocations during
  retry loops.
- `dali-odm-mount.sh` falls back from erofs to ext4 for the odm slot mount.
- `odm_firmware` (touch panel firmware / THP config / display LUTs) is staged
  into the Recovery ramdisk so touch and display keep working without mounting
  the real odm partition.
- Default zh-CN timezone, no-DST localization handling; taller About cards.

### Fixes

- 0032 EV_FF patch diff headers carry the `bootable/recovery/` prefix so
  `git apply` works cleanly.
- 0046 SPL-downgrade UI patch includes the `en.xml` hunk (English labels).
- `fox_fix_date` installation restored in `prepare-ramdisk.sh` (FFiles tree is
  installed into `/sbin` and the FFiles directory is cleaned afterwards).
- safe-trim whitelist uses `+` instead of `:` for range syntax (POSIX
  portable); README and `apply-patches.sh` synchronised (18 -> 19 entries).
- `dali-detach` and `hal-relabel` merged into a single script; rc reference
  updated.
- `modules.sha256` documents the build-time verification note.
- 0030/0045 snapshot-status handling prevents stale snapshot state after a
  cancelled update; 0044 silences MTP ADVISE noise.

### Known limitations

- Whole-UFS-offset writers and malicious updaters that remove the shadow
  mounts are outside the LK protection interface.
- Fastboot and manually issued ADB `dd` commands bypass the LK protection UI.
- USB OTG removable-media testing was deferred (no FAT32/exFAT media
  available); the route is integrated and statically/runtime-prepared.
- APEX handling is disabled for this Recovery build.

## 2026-08-03 — r176 baseline

- Initial public device tree: official OTA inputs, 39-patch record, verified
  display/touch/vibration/flashlight/FBE/MTP, boot-time optimizations, OTA
  menu hidden per user request (`OF_DISABLE_OTA_MENU := 1`), non-vanilla
  feature set (MIUI features / Flash current OrangeFox) kept.
