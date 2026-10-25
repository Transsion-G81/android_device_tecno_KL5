#!/bin/sh
# vendorsetup.sh for android_device_tecno_KL5 (TECNO KL5 / KL5n)
#
# build/envsetup.sh sources every device/*/*/vendorsetup.sh it finds, so this
# runs on every "source build/envsetup.sh".  It is opt-in:
#
#     export PATCH_NFC=true        # before sourcing envsetup.sh / lunch
#
# then patches/nfc/000{1,2}-*.patch are applied to hardware/nxp/nfc (the NXP
# snxxx NFC HAL).  Without PATCH_NFC nothing is printed and nothing is touched,
# so a normal build is unaffected.  Re-running is safe: an already applied
# patch is detected and skipped, so a "repo sync" that drops the patches is
# repaired on the next envsetup.sh.
#
# What the patches do (evidence: patches/nfc/README.md):
#   0001  phNxpNciHal_close(): send RF_DEACTIVATE (deactivate-to-idle) before
#         the CE-discovery handover.  Android 16's libnfc-nci closes the HAL
#         without one, so discovery is still running and the PN557 answers the
#         listen-only RF_DISCOVER with CORE_GENERIC_ERROR_NTF instead of
#         RF_DISCOVER_RSP -> "CMD_CE_DISC_NCI: Failed" -> CORE_RESET underneath
#         the running stack -> NfcService: restartStack ("NFC turns off").
#   0002  phNxpNciHal_write(): the same deactivate before a re-sent
#         RF_DISCOVER, i.e. before the reconfiguration that lands right after a
#         tag activates - the one that broke the actual tag read.
#
# The rest of the KL5n NFC fix needs no patching, it is already in the trees:
# the SIM Secure Element HAL is packaged by vendor/tecno/KL5 (KL5n-nfc.mk) and
# declared in manifest.xml, and the KTP/ISO-DEP crash fix lives in
# packages/modules/Nfc.  The old patches/nfc-ktp.patch shell hack was dropped
# on purpose - it was superseded by that in-tree fix (see the commit
# "revert: remove vendorsetup.sh NFC shell hacks").
#
# Applying by hand, or reverting: see patches/nfc/README.md.

apply_kl5n_nfc_hal_patches() {
    top="${ANDROID_BUILD_TOP:-$PWD}"
    self="${BASH_SOURCE[0]:-$0}"
    here="$(cd "$(dirname "$self")" 2>/dev/null && pwd)" || here=""

    hal="$top/hardware/nxp/nfc"
    pdir="${here:-$top/device/tecno/KL5}/patches/nfc"

    if [ ! -d "$hal" ]; then
        echo "vendorsetup.sh: PATCH_NFC is set but $hal does not exist - skipped"
        return 0
    fi
    if [ ! -d "$pdir" ]; then
        echo "vendorsetup.sh: PATCH_NFC is set but $pdir does not exist - skipped"
        return 0
    fi

    echo "vendorsetup.sh: PATCH_NFC=$PATCH_NFC - patching the NXP NFC HAL in $hal"
    failed=0
    seen=0
    for p in "$pdir"/[0-9][0-9][0-9][0-9]-*.patch; do
        [ -f "$p" ] || continue
        seen=$((seen + 1))
        name=$(basename "$p")

        if [ -d "$hal/.git" ]; then
            # already applied?  (holds whether the patch was applied or committed)
            if git -C "$hal" apply --reverse --check "$p" 2>/dev/null; then
                echo "  $name: already applied"
                continue
            fi
            if git -C "$hal" apply --check "$p" 2>/dev/null; then
                if git -C "$hal" apply "$p" 2>/dev/null; then
                    echo "  $name: applied"
                else
                    echo "  $name: FAILED (git apply)" >&2
                    failed=1
                fi
                continue
            fi
            # otherwise the tree has drifted: fall through to patch(1)
        fi

        if patch -p1 --reverse --dry-run --fuzz=3 -d "$hal" -i "$p" >/dev/null 2>&1; then
            echo "  $name: already applied"
        elif patch -p1 --dry-run --fuzz=3 -d "$hal" -i "$p" >/dev/null 2>&1; then
            if patch -p1 --fuzz=3 --no-backup-if-mismatch -d "$hal" -i "$p" >/dev/null 2>&1; then
                echo "  $name: applied (patch --fuzz=3)"
            else
                echo "  $name: FAILED (patch)" >&2
                failed=1
            fi
        else
            echo "  $name: FAILED - apply it by hand, see $pdir/README.md" >&2
            failed=1
        fi
    done

    if [ "$seen" -eq 0 ]; then
        echo "vendorsetup.sh: no patches found in $pdir" >&2
    elif [ "$failed" -eq 0 ]; then
        echo "vendorsetup.sh: NFC HAL patches OK"
    else
        echo "vendorsetup.sh: some NFC HAL patches were NOT applied" >&2
    fi
    return 0
}

case "${PATCH_NFC:-}" in
    true|TRUE|True|1|yes|YES|on|ON)
        apply_kl5n_nfc_hal_patches
        ;;
esac
