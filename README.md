# OrangeFox 14.1 — `dali` (Xiaomi REDMI K80 Ultra)

OrangeFox 14.1 Recovery device tree for the Xiaomi `dali` (REDMI K80 Ultra,
Android 16, virtual A/B). The tree builds a `vendor_boot` image from
device-derived files reconstructed from the official
`OS3.0.303.0.WONCNXM` OTA, and carries a recorded patch set that must be
applied to a pristine OrangeFox 14.1 sync.

## Device information

| Item | Value |
| --- | --- |
| Codename | `dali` |
| Brand / Model | Xiaomi / REDMI K80 Ultra |
| Platform | MediaTek MT6991 (`mt6991`) |
| Android | 16 (API 36) |
| Partition scheme | virtual A/B (`vendor_boot` v4, AVB hash footer) |
| Official OTA | `OS3.0.303.0.WONCNXM` |
| Build target | `twrp_dali-ap2a-eng` |

## Project

- Recovery base: OrangeFox 14.1 (bootable/recovery commit
  `1b85e0272c19d20acfec176eed6aa46a610b4ec1`)
- Official inputs: kernel, vendor_boot DTB + platform ramdisk, fstabs,
  ueventd/init configuration, vendor_dlkm modules, build properties — all
  extracted from the official OTA and SHA-verified
  (`extract-official-prebuilts.sh`).
- Package: `package-vendor-boot.sh` / `build_vendor_boot.py` — safe-trim of
  platform entries overridden by Recovery, mkbootimg v4 assembly, AVB footer.

## Patches

All patches live in `patches/recovery/` and are applied in order by
`apply-patches.sh` from the OrangeFox source root:

```bash
sh <device-tree>/apply-patches.sh
```

| Patch | Purpose |
| --- | --- |
| `0001` | Flash-current OrangeFox: replace only the inactive slot's Recovery fragment in its own vendor_boot |
| `0002` | LK protection: virtualize standard by-name LK writes (loop-backed copies) |
| `0003` | Target-aware v4 capacity preflight + conditional platform trim |
| `0004-0005` | OTA preloader / verifier alias protection |
| `0006-0007` | Format-data unmap userdata; skip pending merge before format |
| `0008-0010` | Sideload vendor unmount cancel, completion page, CLI cleanup |
| `0011-0012` | AB-OTA mounted system/vendor; LK virtual capacity |
| `0013-0015` | AB-OTA snapshot cleanup; snapshot cancel in recovery; allow new update after merge |
| `0016-0019` | ORS sideload MTP restore; gzip-trimmed fragments; fail-safe no-trim; safe-trim |
| `0022-0023` | Skip vendor module mount; retry metadata decrypt |
| `0026-0029` | SPL downgrade: update_engine allow + twinstall hook + image delete + installed-system SPL source fix |
| `0030` | Fix stale AB-OTA snapshot status |
| `0031-0032` | Slider value handle centering; EV_FF haptics backend (CS40L26) |
| `0033` | Silence redundant property set |
| `0035-0036` | HyperOS3 ROM label; localization without DST |
| `0038-0041` | Default zh-CN timezone; taller About cards; screenshots path; fox ps bin |
| `0042` | Allow non-vanilla VAB (`0042-fox-allow-non-vanilla-vab.patch`) |
| `0044-0045` | MTP advise noise; prepare-super iterator fix |
| `0046` | SPL-downgrade UI (resource-keyed labels, en + zh_CN) |

`0042-boot-timeline.patch.disabled` is kept as a disabled instrumentation
record (not applied).

Additional user-authorized source exceptions (outside this tree):
`bootable/recovery/minuitwrp/events.cpp` (EV_FF haptics),
`bootable/recovery/gui/slidervalue.cpp` (slider haptic preview),
`system/vold/*` (FBE/Weaver compatibility).

### patches/source/ (whole-repo diffs, not applied by apply-patches.sh)

These two patches capture the cumulative working-tree changes in the
bootable/recovery and system/update_engine repos that are not expressible
as individual device-tree patches. They are regenerated from `git diff HEAD`
and include untracked files such as lk_protection_exec.c. They are kept for
reference/reproducibility:

| File | Contents |
|---|---|
| 0047-bootable-recovery-all-changes.patch | bootable/recovery cumulative diff (incl. lk_protection_exec.c, SPL/LK UI strings, direct-write merge skip, EVFF) |
| 0048-update-engine-direct-write.patch | update_engine non-VAB direct-write mode + MapUpdateSnapshot fallback |

To regenerate either patch from a working source tree, run
`git -C <repo> diff HEAD > device/xiaomi/dali/patches/source/00XX-....patch`
(untracked files must be `git add`-ed first).

Note: merge_ab_tool.cc referenced by older 0048 revisions is obsolete
(direct-write mode makes the standalone merge tool unnecessary); the
current 0048 no longer adds that module to Android.bp.
