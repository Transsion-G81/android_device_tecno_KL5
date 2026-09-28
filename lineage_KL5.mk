#
# Copyright (C) 2023-2024 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit from device makefile.
$(call inherit-product, device/tecno/KL5/device.mk)

# Inherit some common LineageOS stuff.
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

PRODUCT_NAME := lineage_KL5
PRODUCT_DEVICE := KL5
PRODUCT_MANUFACTURER := Tecno
PRODUCT_BRAND := Tecno
PRODUCT_MODEL := Spark 30C

PRODUCT_SYSTEM_NAME := Spark 30C
PRODUCT_SYSTEM_DEVICE := KL5

PRODUCT_GMS_CLIENTID_BASE := android-transsion

PRODUCT_BUILD_PROP_OVERRIDES += \
    BuildDesc="TECNO-KL5-user 14 UP1A.231005.007 240811V1304 release-keys" \
    BuildFingerprint=TECNO/KL5-OP/TECNO-KL5:14/UP1A.231005.007/240811V1304:user/release-keys
    SystemModel=$(PRODUCT_SYSTEM_DEVICE) \
    SystemName=$(PRODUCT_SYSTEM_NAME) \
    ProductModel=$(PRODUCT_SYSTEM_DEVICE) \
    DeviceProduct=$(PRODUCT_SYSTEM_NAME)