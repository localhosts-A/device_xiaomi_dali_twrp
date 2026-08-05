LOCAL_PATH := device/xiaomi/dali

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)
$(call inherit-product, vendor/twrp/config/common.mk)
$(call inherit-product, $(LOCAL_PATH)/device.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota/vabc_features.mk)
PRODUCT_FULL_TREBLE_OVERRIDE := true

PRODUCT_DEVICE := dali
PRODUCT_NAME := twrp_dali
PRODUCT_BRAND := Redmi
PRODUCT_MODEL := REDMI K80 Ultra
PRODUCT_MANUFACTURER := Xiaomi
