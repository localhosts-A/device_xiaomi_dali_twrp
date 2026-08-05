LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := dali_recovery_prepare_marker
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_PATH := $(TARGET_RECOVERY_ROOT_OUT)
LOCAL_ADDITIONAL_DEPENDENCIES := \
    $(LOCAL_PATH)/recovery/prepare-ramdisk.sh \
    $(LOCAL_PATH)/recovery/patch-ap-touch-modules.py \
    $(LOCAL_PATH)/prebuilt/recovery_modules/cl_dsp-core.ko \
    $(LOCAL_PATH)/prebuilt/recovery_modules/cs40l26-core.ko \
    $(LOCAL_PATH)/prebuilt/recovery_modules/cs40l26-i2c.ko \
    $(LOCAL_PATH)/prebuilt/recovery_modules/cs40l26-spi.ko \
    $(LOCAL_PATH)/prebuilt/recovery_modules/flashlight.ko \
    $(LOCAL_PATH)/prebuilt/recovery_modules/goodix_core_dali.ko \
    $(LOCAL_PATH)/prebuilt/recovery_modules/leds-mt6379.ko \
    $(LOCAL_PATH)/prebuilt/recovery_modules/leds-mt6379pmic.ko \
    $(LOCAL_PATH)/prebuilt/recovery_modules/mtk_gpueb.ko \
    $(LOCAL_PATH)/prebuilt/recovery_modules/mtk_pbm.ko \
    $(LOCAL_PATH)/prebuilt/recovery_modules/mtk_peak_power_budget.ko \
    $(LOCAL_PATH)/prebuilt/recovery_modules/scp.ko \
    $(LOCAL_PATH)/prebuilt/recovery_modules/snd-soc-cs40l26.ko \
    $(LOCAL_PATH)/prebuilt/recovery_modules/xiaomi_touch_dali.ko \
    $(LOCAL_PATH)/prebuilt/recovery_modules/modules.dep \
    $(LOCAL_PATH)/prebuilt/recovery_properties/system.build.prop \
    $(LOCAL_PATH)/prebuilt/recovery_properties/vendor.build.prop \
    $(LOCAL_PATH)/recovery/root/system/etc/ld.config.dali-crypto.txt \
    $(LOCAL_PATH)/recovery/root/system/etc/init/zz-dali-bootctl.rc \
    $(LOCAL_PATH)/recovery/root/init.recovery.usb.rc \
    $(LOCAL_PATH)/recovery/root/init.recovery.project.rc \
    $(LOCAL_PATH)/recovery/root/init.recovery.mt6991.rc \
    $(LOCAL_PATH)/recovery/root/twres/languages/zh_CN.xml \
    $(LOCAL_PATH)/prebuilt/recovery_modules/modules.sha256 \
    $(LOCAL_PATH)/prebuilt/vendor_ramdisk/platform.cpio.gz \
    $(LOCAL_PATH)/prebuilt/vendor_ramdisk/official_recovery.cpio.gz \
    $(LOCAL_PATH)/prebuilt/dtb/dali.dtb \
    $(LOCAL_PATH)/prebuilt/kernel \
    $(wildcard $(LOCAL_PATH)/prebuilt/recovery_vendor_hal/*) \
    $(wildcard $(LOCAL_PATH)/prebuilt/recovery_firmware/*) \
    $(wildcard $(LOCAL_PATH)/recovery/root/system/bin/*) \
    $(wildcard $(LOCAL_PATH)/recovery/root/system/etc/init/*) \
    $(wildcard $(LOCAL_PATH)/recovery/root/odm/*) \
    $(wildcard $(LOCAL_PATH)/recovery/root/first_stage_ramdisk/*)
include $(BUILD_PHONY_PACKAGE)
