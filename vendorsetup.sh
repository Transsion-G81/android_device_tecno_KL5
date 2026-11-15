#!/bin/sh
# Applies patches/nfc/*.patch to hardware/nxp/nfc (the NXP snxxx NFC HAL).
# Opt-in: export PATCH_NFC=true before sourcing envsetup.sh / lunch.
# Details: patches/nfc/README.md.

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
            # tree drifted: fall through to patch(1)
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

# Applies patches/systemui/*.patch to frameworks/base on every envsetup.sh run.
# Opt out with PATCH_SHADE=0. Details: patches/systemui/README.md.
apply_kl5_systemui_patches() {
    top="${ANDROID_BUILD_TOP:-$PWD}"
    self="${BASH_SOURCE[0]:-$0}"
    here="$(cd "$(dirname "$self")" 2>/dev/null && pwd)" || here=""

    fb="$top/frameworks/base"
    pdir="${here:-$top/device/tecno/KL5}/patches/systemui"

    if [ ! -d "$fb" ]; then
        echo "vendorsetup.sh: $fb does not exist - SystemUI patch skipped" >&2
        return 0
    fi
    if [ ! -d "$pdir" ]; then
        echo "vendorsetup.sh: $pdir does not exist - SystemUI patch skipped" >&2
        return 0
    fi

    failed=0
    seen=0
    for p in "$pdir"/[0-9][0-9][0-9][0-9]-*.patch; do
        [ -f "$p" ] || continue
        seen=$((seen + 1))
        name=$(basename "$p")

        if [ -d "$fb/.git" ]; then
            if git -C "$fb" apply --reverse --check "$p" 2>/dev/null; then
                echo "  $name: already applied"
                continue
            fi
            if git -C "$fb" apply --check "$p" 2>/dev/null; then
                if git -C "$fb" apply "$p" 2>/dev/null; then
                    echo "  $name: applied"
                else
                    echo "  $name: FAILED (git apply)" >&2
                    failed=1
                fi
                continue
            fi
        fi

        if patch -p1 --reverse --dry-run --fuzz=3 -d "$fb" -i "$p" >/dev/null 2>&1; then
            echo "  $name: already applied"
        elif patch -p1 --dry-run --fuzz=3 -d "$fb" -i "$p" >/dev/null 2>&1; then
            if patch -p1 --fuzz=3 --no-backup-if-mismatch -d "$fb" -i "$p" >/dev/null 2>&1; then
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
        echo "vendorsetup.sh: SystemUI shade patch OK"
    else
        echo "vendorsetup.sh: SystemUI shade patch NOT applied - ShadeProvider.tran will do nothing" >&2
    fi
    return 0
}

case "${PATCH_SHADE:-1}" in
    0|false|FALSE|False|no|NO|off|OFF)
        echo "vendorsetup.sh: PATCH_SHADE=$PATCH_SHADE - SystemUI shade patch skipped"
        ;;
    *)
        apply_kl5_systemui_patches
        ;;
esac
