#!/bin/sh

# vendorsetup.sh for android_device_tecno_KL5
#
# Auto-applies the NFC KTP/ATM card detection fix for the NXP PN557 stack.
# The fix lives in packages/modules/Nfc (outside this DT/VT repo), so it is
# applied here from your build tree ($ANDROID_BUILD_TOP or $HOME/cr by default,
# overridable via KL5_NFC_PATCH_DIR).
#
# Root cause: nfa_dm_disc_sm_poll_active() has no handler for
# NFA_DM_RF_INTF_ACTIVATED_NTF. When the PN557 firmware drops the
# RF_DEACTIVATED_NTF (card still in field after deactivate), the state machine
# stays stale in POLL_ACTIVE. The card re-activates, the activation NTF hits the
# default case ("Unexpected discovery event") and is dropped, then the
# ~8s deact-NTF timeout + recovery hits nfc_ncif_cmd_timeout -> restartStack
# (visible "NFC turns off").
#
# The patch adds an NFA_DM_RF_INTF_ACTIVATED_NTF case in poll_active that stops
# the deact-NTF timeout, clears W4_RSP|W4_NTF, and treats the re-activation as a
# fresh activation (or gracefully restarts discovery if the upper layer rejects
# it).

apply_kl5n_nfc_ktp_patch() {
    [ "${KL5_NFC_PATCH_SKIP:-0}" = "1" ] && return 0

    if [ -n "$KL5_NFC_PATCH_DIR" ]; then
        BUILD_TOP="$KL5_NFC_PATCH_DIR"
    elif [ -n "$ANDROID_BUILD_TOP" ]; then
        BUILD_TOP="$ANDROID_BUILD_TOP"
    else
        BUILD_TOP="$HOME/cr"
    fi

    TARGET="$BUILD_TOP/packages/modules/Nfc/libnfc-nci/src/nfa/dm/nfa_dm_discover.cc"
    PATCH="$BUILD_TOP/device/tecno/KL5/patches/nfc-ktp.patch"

    [ -f "$TARGET" ] || return 0
    [ -f "$PATCH" ] || return 0

    # Idempotency: bail out if our marker comment is already present.
    grep -q "Card re-activated while still in POLL_ACTIVE" "$TARGET" 2>/dev/null && return 0

    echo "vendorsetup.sh: applying KL5n NFC KTP patch to $TARGET"

    git -C "$BUILD_TOP" apply --verbose "$PATCH"
    rc=$?

    if [ $rc -eq 0 ]; then
        echo "vendorsetup.sh: KL5n NFC KTP patch applied"
    else
        echo "vendorsetup.sh: KL5n NFC KTP patch FAILED" >&2
    fi
    return $rc
}

apply_kl5n_settings_nfc_patch() {
    if [ -n "$KL5_NFC_PATCH_SKIP" ]; then
        echo "vendorsetup.sh: KL5n Settings NFC receiver patch skipped (KL5_NFC_PATCH_SKIP set)"
        return 0
    fi

    BUILD_TOP="$KL5_NFC_PATCH_DIR"
    if [ -z "$BUILD_TOP" ]; then
        BUILD_TOP="$ANDROID_BUILD_TOP"
    fi
    if [ -z "$BUILD_TOP" ]; then
        BUILD_TOP="$HOME/cr"
    fi

    TARGET="$BUILD_TOP/packages/apps/Settings/src/com/android/settings/connecteddevice/NfcAndPaymentFragmentController.java"
    if [ ! -f "$TARGET" ]; then
        echo "vendorsetup.sh: KL5n Settings NFC receiver patch skipped ($TARGET not found)"
        return 0
    fi

    if grep -q "Receiver was not registered; ignore." "$TARGET"; then
        echo "vendorsetup.sh: KL5n Settings NFC receiver patch already applied"
        return 0
    fi

    awk '
    /^[[:space:]]*mContext\.unregisterReceiver\(mReceiver\);[[:space:]]*$/ {
        match($0, /^[[:space:]]*/)
        indent = substr($0, 1, RLENGTH)
        print indent "try {"
        print indent "    mContext.unregisterReceiver(mReceiver);"
        print indent "} catch (IllegalArgumentException e) {"
        print indent "    Log.w(TAG, \"Receiver was not registered; ignore.\", e);"
        print indent "}"
        next
    }
    { print }
    ' "$TARGET" > "$TARGET.tmp" && mv "$TARGET.tmp" "$TARGET"
    rc=$?

    if [ $rc -eq 0 ]; then
        echo "vendorsetup.sh: KL5n Settings NFC receiver patch applied"
    else
        echo "vendorsetup.sh: KL5n Settings NFC receiver patch FAILED" >&2
    fi
    return $rc
}

apply_kl5n_nfc_ktp_patch
apply_kl5n_settings_nfc_patch
