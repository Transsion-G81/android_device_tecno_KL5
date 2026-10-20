#
# Copyright (C) 2023-2025 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#
# TECNO Spark 30C 5G (KL5n) — KL5 tree with the imx582 back-camera stack.
# The ONLY differences from lineage_KL5.mk are the camera bits:
#   * SOONG_CONFIG selects the KL5n libcameracustom.so prebuilt
#     (vendor/tecno/KL5/Android.bp soong_config srcs switch)
#   * device.mk then inherits vendor/tecno/KL5/KL5n-camera.mk for the
#     imx582 tuning/hdr/anc blobs + IdxMgr modules
#   * BoardConfig.mk swaps imgsensor_isp4.ko for the imx582-enabled module
# Identity props are taken from the stock KL5n dump
# (TECNO-KL5n-KL5n-XK678ORUWXAdAeAfP-U-OP-260710V808).
#

# Camera variant for the soong_config srcs switch in vendor/tecno/KL5/Android.bp
# (libcameracustom). Must be set before device.mk: device.mk keys the
# conditional inherit of KL5n-camera.mk off this same variable.
SOONG_CONFIG_NAMESPACES += tecno_camera
SOONG_CONFIG_tecno_camera += camera_variant
SOONG_CONFIG_tecno_camera_camera_variant := kl5n

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit from device makefile.
$(call inherit-product, device/tecno/KL5/device.mk)

# Inherit some common LineageOS stuff.
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

PRODUCT_NAME := lineage_KL5n
PRODUCT_DEVICE := KL5
PRODUCT_MANUFACTURER := Tecno
PRODUCT_BRAND := Tecno
PRODUCT_MODEL := TECNO KL5n

PRODUCT_SYSTEM_NAME := TECNO-KL5n
PRODUCT_SYSTEM_DEVICE := KL5n

PRODUCT_GMS_CLIENTID_BASE := android-transsion

PRODUCT_BUILD_PROP_OVERRIDES += \
    BuildDesc="TECNO-KL5n-user 14 UP1A.231005.007 260710V887 release-keys" \
    BuildFingerprint=TECNO/KL5n-OP/TECNO-KL5n:14/UP1A.231005.007/260710V887:user/release-keys \
    SystemModel=$(PRODUCT_SYSTEM_DEVICE) \
    SystemName=$(PRODUCT_SYSTEM_NAME) \
    ProductModel=$(PRODUCT_SYSTEM_DEVICE) \
    DeviceProduct=$(PRODUCT_SYSTEM_NAME)
