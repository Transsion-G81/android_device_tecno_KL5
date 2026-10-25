# KL5n NFC fixes — `hardware/nxp/nfc` (snxxx, AIDL)

These two patches fix the "tag is detected, then NFC turns off and does nothing"
behaviour on the TECNO KL5n (NXP PN557, `nfc_i2c.ko` driver, Android 16 /
LineageOS 23.2, HAL built from `hardware/nxp/nfc` `snxxx`).

Everything below is grounded in `snxxx/halimpl/hal/phNxpNciHal.cc` at
`lineage-23.2` plus the on-device logs.

## Root cause

The failing sequence (log `nfcnumber6.log`, repeated every ~12 s):

```
61052901…      RF_INTF_ACTIVATED_NTF (tag activated)
60070106       CORE_GENERIC_ERROR_NTF (GID 0, OID 7, status 0x06)  <- not the RF_DISCOVER_RSP
reSelect: timeout ×3                                    <- controller stops answering
nfc_ncif_cmd_timeout → NFA_DM_NFCC_TIMEOUT_EVT
NfcService: restartStack: Restarting NFC Service        <- "NFC turns off"
```

and at the teardown that follows:

```
Nfc::close
NxpNciX 20020501A0070102      (cmd_ce_in_phone_off_pn557)
NxpNciX 21030703800181018201  (RF_DISCOVER, listen-only A/B/F)   <-- phNxpNciHal_close()
NxpNciR 60070106              (CORE_GENERIC_ERROR_NTF again - discovery still running)
Callback Status is failed!! Timer Expired!! Couldn't read it! 0xff   (+1000 ms)
CMD_CE_DISC_NCI: Failed
NxpNciX 20000100              (CORE_RESET while the stack still thinks NFC is on)
```

Both symptoms are the same bug: **the host issues `RF_DISCOVER` while discovery is
already running.** This PN557 answers that with
`CORE_GENERIC_ERROR_NTF(DISCOVERY_ALREADY_STARTED)` instead of `RF_DISCOVER_RSP`,
and then stops servicing the session.

In `phNxpNciHal.cc`:

* `phNxpNciHal_close()` (`~2374`) always builds and sends
  `cmd_ce_discovery_nci` (`21 03 …`) for the CE handover. The listen parameters
  come from `NXP_UICC_LISTEN_TECH_MASK` / `NXP_ESE_LISTEN_TECH_MASK`, and both
  **default to `0x07` when the keys are missing** (`~2407`/`~2413`) - so the
  command is always sent, with A/B/F added (`~2477`-`2511`). Android 16's
  `libnfc-nci` closes the HAL *without* an `RF_DEACTIVATE`, so it collides.
* `phNxpNciHal_write()` (`~1156`) forwards every `RF_DISCOVER` from the stack
  unchanged. The stack reconfigures discovery by re-sending it, which collides
  for the same reason.

## Patches

* `0001-phNxpNciHal-stop-discovery-before-CE-discovery.patch`
  `RF_DEACTIVATE` (deactivate-to-idle, `21 06 01 00` - the same command
  `phNxpNciHal_configDiscShutdown()` already sends) before the CE-discovery in
  `phNxpNciHal_close()`. Fixes `CMD_CE_DISC_NCI: Failed`, the `CORE_RESET`
  underneath the running stack, and therefore the `restartStack` on/off loop.
* `0002-phNxpNciHal-deactivate-before-rf-discover-reconfig.patch`
  In the `RF_DISCOVER` branch of `phNxpNciHal_write()`, if discovery is already
  running (`NciDiscoveryCommandBuilderInstance.isRfDiscoveryCommandReceived()`)
  deactivate first. Fixes the `60070106` that lands right after the tag
  activation and takes the controller down with it - i.e. the actual tag read.

### Apply

The patches live in the device tree, next to this file:
`device/tecno/KL5/patches/nfc/` - on the build server,
`~/los23/device/tecno/KL5/patches/nfc/`. They are a two-patch series (`0002` is
diffed on top of `0001`), so apply them together and in order.

```sh
cd ~/los23/hardware/nxp/nfc              # the snxxx HAL repo
git apply ~/los23/device/tecno/KL5/patches/nfc/0001-*.patch \
          ~/los23/device/tecno/KL5/patches/nfc/0002-*.patch

# or commit them onto your branch (both are mail-format patches):
git am  ~/los23/device/tecno/KL5/patches/nfc/0001-*.patch \
        ~/los23/device/tecno/KL5/patches/nfc/0002-*.patch

# if your tree has drifted from lineage-23.2:
# patch -p1 --fuzz=3 < ~/los23/device/tecno/KL5/patches/nfc/0001-*.patch
# patch -p1 --fuzz=3 < ~/los23/device/tecno/KL5/patches/nfc/0002-*.patch

# build
m android.hardware.nfc-service.nxp
```

Verified against `lineage-23.2` on 2026-10-24
(`snxxx/halimpl/hal/phNxpNciHal.cc`, 160295 bytes, blob `c0a39b8`):
`git apply --check`, `git apply` and `git am` all apply the series cleanly and
produce exactly the same result - 31 inserted lines in that one file (15 + 16).

`vendor/tecno/KL5/KL5n-nfc.mk` already packages that module, so nothing else in
the tree changes. Consider adding a note about these patches to the `KL5n-nfc.mk`
header comment (next to the existing "How the stack fits together" block).

### Automating (opt-in)

`vendorsetup.sh` in the device tree applies the two patches for you. Export the
switch before sourcing envsetup.sh:

```sh
export PATCH_NFC=true        # then: source build/envsetup.sh
```

It is idempotent - an already applied (or already committed) patch is detected
with `git apply --reverse --check` and skipped - so re-running it after a
`repo sync` repairs the tree instead of failing. Without `PATCH_NFC` the script
prints nothing and touches nothing.

## Test without a rebuild (close-path half only)

Adding these two lines to `proprietary_kl5n/vendor/etc/libnfc-nxp.conf` makes the
`phNxpNciHal_close()` discovery command empty, so it is skipped
(`"No changes in the discovery command, sticking to last discovery command sent"`)
instead of failing and resetting the NFCC:

```
###############################################################################
# KL5n: no eSE/UICC off-host listener is wired up on this device, so do not build
# the listen-only CE discovery in phNxpNciHal_close() - sending RF_DISCOVER while
# discovery is still running makes the PN557 answer CORE_GENERIC_ERROR_NTF and the
# HAL then CORE_RESETs underneath the running stack.
NXP_UICC_LISTEN_TECH_MASK=0x00
NXP_ESE_LISTEN_TECH_MASK=0x00
###############################################################################
```

This is a workaround, not the fix: it removes the `CMD_CE_DISC_NCI: Failed` /
`restartStack` half, but the activation-time collision needs patch 2, and it
gives up the CE-in-NFC-off handover.

## Verify

```sh
adb logcat -b all -d | grep -E "CMD_CE_DISC_NCI|Timer Expired|restartStack|nfc_ncif_cmd_timeout|60070106|Tag dispatch"
```

Expected after the patches: no `CMD_CE_DISC_NCI: Failed`, no `Timer Expired`, no
`60070106` following an `RF_INTF_ACTIVATED_NTF`, no `restartStack` - and the tag
reaching `NfcDispatcher`/`dispatchTag`.

## Limits / next step if the read still fails

Patch 1 is a clear spec-level bug (an `RF_DISCOVER` must not be sent while
discovery is running). Patch 2's diagnosis rests on the log ordering - the
`60070106` arrives in the same millisecond as the second `RF_DISCOVER` and the
following `RF_INTF_ACTIVATED_NTF` - but it is inferred, not proven. If reads
still fail after both patches, instrument the HAL around the command that never
gets its response: `phNxpNciHal_print_packet()` already dumps every NCI packet,
so add the pending-command id/state (`nxpncihal_ctrl.rsp_buf_info`,
`nxpncihal_ctrl.p_cmd_data`) to the `phNxpNciHal_read_complete()` timeout path
and compare against the same trace from the stock KL5n firmware, where the same
card reads fine.

## Candidate upstream nit (not fixed here)

`phNxpNciHal_close()` decides the B listen parameter with
`(eseListenMask & 0x4) == 0x04` - the F bit - instead of `& 0x2`. Harmless with
the `0x07` default, but it means "B passive listen" is added whenever F was
requested.
