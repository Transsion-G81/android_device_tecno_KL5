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

    [ -f "$TARGET" ] || return 0

    # Idempotency: bail out if our marker comment is already present.
    grep -q "Card re-activated while still in POLL_ACTIVE" "$TARGET" 2>/dev/null && return 0

    echo "vendorsetup.sh: applying KL5n NFC KTP patch to $TARGET"

    TMPFILE="$(mktemp)" || return 0
    cat > "$TMPFILE" <<'EOF'
    case NFA_DM_RF_INTF_ACTIVATED_NTF:
      /* Card re-activated while still in POLL_ACTIVE (deactivation NTF was
       * lost, e.g. NXP PN557 firmware with card still in field). Stop the
       * deact-NTF timeout, clear pending flags, and treat as fresh activation.
       */
      nfa_sys_stop_timer(&nfa_dm_cb.disc_cb.tle);
      nfa_dm_cb.disc_cb.disc_flags &= ~(NFA_DM_DISC_FLAGS_W4_RSP | NFA_DM_DISC_FLAGS_W4_NTF);
      if (nfa_dm_disc_notify_activation(&(p_data->nfc_discover)) == NFA_STATUS_FAILED) {
        LOG(VERBOSE) << StringPrintf(
            "%s: Not matched, restart discovery after receiving deactivate ntf", __func__);
        nfa_dm_cb.disc_cb.disc_flags |= (NFA_DM_DISC_FLAGS_W4_RSP | NFA_DM_DISC_FLAGS_W4_NTF);
        NFC_Deactivate(NFA_DEACTIVATE_TYPE_IDLE);
      }
      break;
EOF

    awk -v blockfile="$TMPFILE" '
    /^    case NFA_DM_CORE_INTF_ERROR_NTF:$/ { in_block=1 }
    in_block && /^    case NFA_DM_RF_INTF_EXT_START_CMD:$/ {
        while ((getline line < blockfile) > 0) print line
        close(blockfile)
        in_block=0
    }
    { print }
    ' "$TARGET" > "$TARGET.tmp" && mv "$TARGET.tmp" "$TARGET"
    rc=$?
    rm -f "$TMPFILE"

    if [ $rc -eq 0 ]; then
        echo "vendorsetup.sh: KL5n NFC KTP patch applied"
    else
        echo "vendorsetup.sh: KL5n NFC KTP patch FAILED" >&2
    fi
    return $rc
}

apply_kl5n_nfc_ktp_patch
