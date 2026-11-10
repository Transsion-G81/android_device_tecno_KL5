# patches/nfc

Two patches for `hardware/nxp/nfc` (the NXP snxxx AIDL HAL, built from Lineage source)
on the KL5n PN553. Both send RF_DEACTIVATE before a discovery command that the
controller would otherwise reject with DISCOVERY_ALREADY_STARTED - which the HAL
answers with CORE_RESET, so NfcService restarts the stack.

* `0001` `phNxpNciHal_close()`: deactivate before the CE handover discovery.
* `0002` `phNxpNciHal_write()`: deactivate before a re-sent RF_DISCOVER.

Applied by `vendorsetup.sh` when `PATCH_NFC=true` is exported before
`source build/envsetup.sh`. Re-running is safe: an already applied patch is detected
and skipped, so a `repo sync` that resets the HAL is repaired on the next envsetup.

By hand, from `hardware/nxp/nfc`:

```sh
git apply ../../device/tecno/KL5/patches/nfc/0001-phNxpNciHal-stop-discovery-before-CE-discovery.patch
git apply --reverse ../../device/tecno/KL5/patches/nfc/0001-*.patch    # revert
```

Generated against lineage-23.2. The longer analysis that produced these patches is in
the git history of this file.
