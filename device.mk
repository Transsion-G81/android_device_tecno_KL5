#
# Copyright (C) 2023 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Installs gsi keys into ramdisk, to boot a developer GSI with verified boot.
$(call inherit-product, $(SRC_TARGET_DIR)/product/developer_gsi_keys.mk)

# Project ID Quota
$(call inherit-product, $(SRC_TARGET_DIR)/product/emulated_storage.mk)

# Setup dalvik vm configs
$(call inherit-product, frameworks/native/build/phone-xhdpi-4096-dalvik-heap.mk)

## Inherit from GKI stuffs
$(call inherit-product, $(SRC_TARGET_DIR)/product/generic_ramdisk.mk)

## Inherit from virtual A/B, most specific first
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota/launch_with_vendor_ramdisk.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota/vabc_features.mk)

# Inherit common MediaTek IMS
$(call inherit-product, vendor/mediatek/ims/ims.mk)

# A/B
PRODUCT_PACKAGES += \
    com.android.hardware.boot \
    android.hardware.boot-service.default_recovery

PRODUCT_PACKAGES += \
    create_pl_dev \
    create_pl_dev.recovery

PRODUCT_PACKAGES += \
    update_engine \
    update_engine_sideload \
    update_verifier

PRODUCT_PACKAGES_DEBUG += \
    update_engine_client

AB_OTA_POSTINSTALL_CONFIG += \
    RUN_POSTINSTALL_system=true \
    POSTINSTALL_PATH_system=system/bin/otapreopt_script \
    FILESYSTEM_TYPE_system=ext4 \
    POSTINSTALL_OPTIONAL_system=true

AB_OTA_POSTINSTALL_CONFIG += \
    RUN_POSTINSTALL_vendor=true \
    POSTINSTALL_PATH_vendor=bin/checkpoint_gc \
    FILESYSTEM_TYPE_vendor=erofs \
    POSTINSTALL_OPTIONAL_vendor=true

PRODUCT_PACKAGES += \
    checkpoint_gc \
    otapreopt_script

# Audio
PRODUCT_PACKAGES += \
    android.hardware.audio@7.0-impl:32 \
    android.hardware.audio.effect@7.0-impl:32 \
    android.hardware.audio.service

PRODUCT_PACKAGES += \
    audio.bluetooth.default:32 \
    android.hardware.bluetooth.audio-impl:32

PRODUCT_PACKAGES += \
    Audioservice.tran \
    MtkInCallService

PRODUCT_PACKAGES += \
    libdynproc:32 \
    libhapticgenerator:32

PRODUCT_COPY_FILES += \
    $(call find-copy-subdir-files,*,$(LOCAL_PATH)/configs/audio/,$(TARGET_COPY_OUT_VENDOR)/etc)

PRODUCT_COPY_FILES += \
    frameworks/av/services/audiopolicy/config/bluetooth_audio_policy_configuration_7_0.xml:$(TARGET_COPY_OUT_VENDOR)/etc/bluetooth_audio_policy_configuration.xml \
    frameworks/av/services/audiopolicy/config/r_submix_audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/r_submix_audio_policy_configuration.xml

# AudioFX
TARGET_EXCLUDES_AUDIOFX := true

# Cgroup
PRODUCT_COPY_FILES += \
    system/core/libprocessgroup/profiles/cgroups_30.json:$(TARGET_COPY_OUT_VENDOR)/etc/cgroups.json \
    $(LOCAL_PATH)/configs/task_profiles.json:$(TARGET_COPY_OUT_VENDOR)/etc/task_profiles.json

# ConsumerIR
PRODUCT_PACKAGES += \
    android.hardware.ir-service.example

PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.consumerir.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.consumerir.xml

# Charger
PRODUCT_PACKAGES += \
    libsuspend

# ConsumerIR
PRODUCT_PACKAGES += \
    android.hardware.ir-service.example

PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.consumerir.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.consumerir.xml

# Display
PRODUCT_PACKAGES += \
    android.hardware.graphics.composer@2.1-service \
    android.hardware.memtrack-service.mediatek-mali

# DRM
PRODUCT_PACKAGES += \
    android.hardware.drm-service.clearkey

# DT2W
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/configs/keylayout/mtk-tpd.kl:$(TARGET_COPY_OUT_VENDOR)/usr/keylayout/mtk-tpd.kl

# DTB
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/prebuilt/dtb.img:$(TARGET_OUT)/dtb.img

# Dynamic Partitions
PRODUCT_USE_DYNAMIC_PARTITIONS := true
PRODUCT_BUILD_SUPER_PARTITION := false

PRODUCT_PACKAGES += \
    fastbootd

# FM Radio
PRODUCT_PACKAGES += \
    FMRadio

# Gatekeeper
PRODUCT_PACKAGES += \
    android.hardware.gatekeeper@1.0-impl \
    android.hardware.gatekeeper@1.0-service

# Health
PRODUCT_PACKAGES += \
    android.hardware.health-V1-ndk \
    android.hardware.health@2.1-impl \
    android.hardware.health@2.1-impl.recovery \
    android.hardware.health@2.1-service

# HIDL 
PRODUCT_PACKAGES += \
    libhidltransport \
    libhidltransport.vendor 

# Light
PRODUCT_PACKAGES += \
    android.hardware.light-service.lineage

# Linker
PRODUCT_VENDOR_LINKER_CONFIG_FRAGMENTS += \
    $(LOCAL_PATH)/configs/linker.config.json

# Neural Networks
PRODUCT_PACKAGES += \
	android.hardware.neuralnetworks@1.0.vendor \
	android.hardware.neuralnetworks@1.1.vendor \
	android.hardware.neuralnetworks@1.2.vendor \
	android.hardware.neuralnetworks@1.3.vendor \
    libruy.vendor \
    libtextclassifier_hash.vendor
    
# Media
PRODUCT_COPY_FILES += \
    $(call find-copy-subdir-files,*,$(LOCAL_PATH)/configs/seccomp,$(TARGET_COPY_OUT_VENDOR)/etc/seccomp_policy) \
    $(call find-copy-subdir-files,*,$(LOCAL_PATH)/configs/media,$(TARGET_COPY_OUT_VENDOR)/etc)

# Overlays
PRODUCT_PACKAGES += \
    CarrierConfigOverlay_KL5 \
    FrameworksResOverlay_KL5 \
    SystemUIOverlay_KL5 \
    SettingsResOverlay_KL5 \
    TetheringResOverlay_KL5 \
    WifiResOverlay_KL5

DEVICE_PACKAGE_OVERLAYS += \
    $(LOCAL_PATH)/overlay-lineage

PRODUCT_ENFORCE_RRO_TARGETS := *

# Partition source order for Product/Build properties pickup.
PRODUCT_SYSTEM_PROPERTIES += \
    ro.product.property_source_order=odm,vendor,product,system_ext,system

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/configs/import.prop:$(TARGET_COPY_OUT_ODM)/etc/import.prop

# Permissions
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.audio.low_latency.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.audio.low_latency.xml \
    frameworks/native/data/etc/android.hardware.bluetooth_le.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth_le.xml \
    frameworks/native/data/etc/android.hardware.bluetooth.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth.xml \
    frameworks/native/data/etc/android.hardware.camera.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.xml \
    frameworks/native/data/etc/android.hardware.camera.flash-autofocus.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.flash-autofocus.xml \
    frameworks/native/data/etc/android.hardware.camera.front.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.front.xml \
    frameworks/native/data/etc/android.hardware.faketouch.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.faketouch.xml \
    frameworks/native/data/etc/android.hardware.fingerprint.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.fingerprint.xml \
    frameworks/native/data/etc/android.hardware.location.gps.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.location.gps.xml \
    frameworks/native/data/etc/android.hardware.opengles.aep.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.opengles.aep.xml \
    frameworks/native/data/etc/android.hardware.sensor.accelerometer.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.accelerometer.xml \
    frameworks/native/data/etc/android.hardware.sensor.light.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.light.xml \
    frameworks/native/data/etc/android.hardware.sensor.proximity.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.proximity.xml \
    frameworks/native/data/etc/android.hardware.sensor.stepcounter.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.stepcounter.xml \
    frameworks/native/data/etc/android.hardware.sensor.stepdetector.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.stepdetector.xml \
    frameworks/native/data/etc/android.hardware.sensor.compass.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.compass.xml \
    frameworks/native/data/etc/android.hardware.sensor.dynamic.head_tracker.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.dynamic.head_tracker.xml \
    frameworks/native/data/etc/android.hardware.sensor.gyroscope.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.gyroscope.xml \
    frameworks/native/data/etc/android.hardware.telephony.cdma.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.telephony.cdma.xml \
    frameworks/native/data/etc/android.hardware.telephony.gsm.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.telephony.gsm.xml \
    frameworks/native/data/etc/android.hardware.telephony.ims.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.telephony.ims.xml \
    frameworks/native/data/etc/android.hardware.touchscreen.multitouch.distinct.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.touchscreen.multitouch.distinct.xml \
    frameworks/native/data/etc/android.hardware.touchscreen.multitouch.jazzhand.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.touchscreen.multitouch.jazzhand.xml \
    frameworks/native/data/etc/android.hardware.touchscreen.multitouch.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.touchscreen.multitouch.xml \
    frameworks/native/data/etc/android.hardware.touchscreen.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.touchscreen.xml \
    frameworks/native/data/etc/android.hardware.usb.accessory.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.accessory.xml \
    frameworks/native/data/etc/android.hardware.usb.host.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.host.xml \
    frameworks/native/data/etc/android.hardware.vulkan.compute-0.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.vulkan.compute.xml \
    frameworks/native/data/etc/android.hardware.vulkan.level-1.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.vulkan.level.xml \
    frameworks/native/data/etc/android.hardware.vulkan.version-1_1.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.vulkan.version.xml \
    frameworks/native/data/etc/android.hardware.wifi.direct.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.direct.xml \
    frameworks/native/data/etc/android.hardware.wifi.passpoint.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.passpoint.xml \
    frameworks/native/data/etc/android.hardware.wifi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.xml \
    frameworks/native/data/etc/android.software.ipsec_tunnels.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.ipsec_tunnels.xml \
    frameworks/native/data/etc/android.software.midi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.midi.xml \
    frameworks/native/data/etc/android.software.opengles.deqp.level-2020-03-01.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.opengles.deqp.level.xml \
    frameworks/native/data/etc/android.software.verified_boot.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.verified_boot.xml \
    frameworks/native/data/etc/android.software.vulkan.deqp.level-2020-03-01.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.vulkan.deqp.level.xml \
    frameworks/native/data/etc/handheld_core_hardware.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/handheld_core_hardware.xml

PRODUCT_PACKAGES += \
    android.hardware.hardware_keystore.km41.xml

# Power
PRODUCT_PACKAGES += \
    android.hardware.power@1.3.vendor \
    android.hardware.power-service.lineage-libperfmgr \
    vendor.mediatek.hardware.mtkpower@1.2-service.stub \
    libmtkperf_client_vendor \
    libmtkperf_client

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/configs/powerhint.json:$(TARGET_COPY_OUT_VENDOR)/etc/powerhint.json

# Power Off Alarm
PRODUCT_PACKAGES += \
    PowerOffAlarm

# Properties
include $(LOCAL_PATH)/vendor_logtag.mk

# Rootdir
PRODUCT_PACKAGES += \
    fstab.mt6768 \
    fstab.mt6768.vendor_ramdisk \
    init.connectivity.rc \
    init.modem.rc \
    init.insmod.mt6768.cfg \
    init.mtkgki.rc \
    init.connectivity.mt6768.rc \
    init.connectivity.common.rc \
    init_connectivity.rc \
    init.mt6768.rc \
    init.cgroup.rc \
    init.insmod.sh \
    init.mt6768.usb.rc \
    init.project.rc \
    init.sensor_1_0.rc \
    init.target.rc \
    ueventd.mt6768.rc

PRODUCT_PACKAGES += \
    init.recovery.usb.rc

PRODUCT_PACKAGES += \
    libsensorndkbridge:64 \
    android.hardware.sensors@1.0.vendor:64 \
    android.hardware.sensors@2.1.vendor:64 \
    android.frameworks.sensorservice@1.0:64 \
    android.frameworks.sensorservice@1.0.vendor:64 \
    android.hardware.sensors@2.1-service.multihal \
    android.hardware.sensors@2.0-ScopedWakelock.vendor:64

PRODUCT_PACKAGES += \
    sensors.dynamic_sensor_hal:64

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/configs/hals.conf:$(TARGET_COPY_OUT_VENDOR)/etc/sensors/hals.conf

# Shipping API level
PRODUCT_SHIPPING_API_LEVEL := 30

# Soong namespaces
PRODUCT_SOONG_NAMESPACES += \
    $(LOCAL_PATH) \
    hardware/google/interfaces \
    hardware/google/pixel \
    hardware/lineage/interfaces/power-libperfmgr \
    hardware/mediatek \
    hardware/mediatek/libmtkperf_client 

# Thermal
PRODUCT_PACKAGES += \
    android.hardware.thermal@1.0-impl

PRODUCT_PACKAGES += \
    android.hardware.thermal@2.0.vendor

# USB
PRODUCT_PACKAGES += \
    android.hardware.usb@1.3.vendor \
    android.hardware.usb.gadget@1.1.vendor

# Vibrator
$(call soong_config_set, vibrator, vibratortargets, vibratoraidlV2target)

PRODUCT_PACKAGES += \
    vendor.qti.hardware.vibrator.service

PRODUCT_COPY_FILES += \
    vendor/qcom/opensource/vibrator/excluded-input-devices.xml:$(TARGET_COPY_OUT_VENDOR)/etc/excluded-input-devices.xml

# VNDK
PRODUCT_PACKAGES += \
    libcrypto-v33 \
    libtinyxml2-v34 \
    libssl-v33

# vndservice
PRODUCT_PACKAGES += \
   vndservicemanager \
   vndservice

# Wi-Fi
PRODUCT_PACKAGES += \
    android.system.wifi.keystore@1.0.vendor \
    libkeystore-wifi-hidl \
    libkeystore-engine-wifi-hidl \
    libnl.vendor \
    android.hardware.wifi@1.1.vendor \
    android.hardware.wifi@1.2.vendor \
    android.hardware.wifi@1.3.vendor \
    android.hardware.wifi@1.4.vendor \
    android.hardware.wifi.supplicant@1.0.vendor \
    android.hardware.wifi.supplicant@1.1.vendor \
    android.hardware.wifi.supplicant@1.2.vendor \
    android.hardware.wifi.supplicant@1.3.vendor \
    android.hardware.wifi.supplicant@1.4.vendor \
    hostapd \
    libwifi-hal-wrapper \
    android.hardware.wifi-service

PRODUCT_COPY_FILES += \
    $(call find-copy-subdir-files,*,$(LOCAL_PATH)/configs/wifi/,$(TARGET_COPY_OUT_VENDOR)/etc/wifi)

# Inherit the proprietary files
$(call inherit-product, vendor/tecno/KL5/KL5-vendor.mk)

# Inherit the sign keys
$(call inherit-product, vendor/lineage-priv/keys/keys.mk)
