# Android device tree — TECNO Spark 30C (KL5) / Spark 30C 5G (KL5n)

LineageOS 23.2 tree for the TECNO Spark 30C (**KL5**, MT6768) and its 5G
sibling **KL5n** (also MT6768, same board, different camera sensors).
Both targets build from this one device dir; the difference between them is
**camera only** (see below).

| Lunch target       | Device   | Back camera | Stock firmware reference |
|--------------------|----------|-------------|--------------------------|
| `lineage_KL5-…`    | KL5      | hi5022q     | `TECNO/KL5-OP/TECNO-KL5:14/UP1A.231005.007/240811V1304` |
| `lineage_KL5n-…`   | KL5n     | **imx582**  | `TECNO/KL5n-OP/TECNO-KL5n:14/UP1A.231005.007/260710V887` |

`PRODUCT_DEVICE` is `KL5` for **both** (the device dir is
`device/tecno/KL5`); the targets are distinguished by `PRODUCT_NAME`.

The matching vendor blob tree is `vendor/tecno/KL5`
(`android_vendor_tecno_KL5-lineage-23.2` in this workspace).

---

## 1. The camera problem and its root cause

**Symptom:** building this ROM tree for the KL5n produced a vendor image in
which the back camera (the Sony IMX582) never appeared — camera app falls
back to the front camera, `logcat` shows no imx582 sensor bring-up.

**Root cause:** three independent gaps, all rooted in the fact that this is
a *KL5* tree being asked to serve a *KL5n*:

1. **Kernel module gap** — `imgsensor_isp4.ko` (the MTK imaging sensor
   kernel module) built from the KL5 kernel tree contains no imx582
   support: its sensor table covers only `hi5022q`, `s5kjn1`, `gc08a8`,
   `hi846`, `fake_serial_yuv`. The stock KL5n ships a different
   `imgsensor_isp4.ko` (vermagic `5.10.237-android12-9+`) that *does*
   contain `IMX582_MIPI_RAW_SensorInit` / `imx582_17201932` entries.
   The ROM's kernel is `5.10.209-android12-9+`, so the stock module
   cannot be loaded as-is (vermagic mismatch).
2. **HAL userspace gap** — `libcameracustom.so` (the MTK custom camera
   HAL plugin) in the KL5 blob set is built for the KL5 sensor list: its
   `DT_NEEDED` entries reference `hi5022q_mipi_raw_IdxMgr`,
   `s5kjn1_mipi_raw_IdxMgr` etc., and it contains no imx582 code path.
   The stock KL5n `libcameracustom.so` references
   `imx582_mipi_raw_IdxMgr` / `pblcimx582_mipi_raw_IdxMgr` instead.
3. **Data/libs gap** — even with the right HAL, imx582 needs its tuning
   data libs, IdxMgr libs, HDR adapter and anc_siq tuning blobs, none of
   which exist in the KL5 blob set.

**What is NOT broken** (important negative results from the investigation):

* The ROM's `vendor/etc/*.xml` HAL metadata libs
  (`com.mediatek.camera.*`) already contain
  `constructCustStaticMetadata_*_IMX582_MIPI_RAW` — no change needed.
* There is **no** dtbo in the ROM payload and the shared
  `prebuilt/dtbo.img` already lists all sensors (MTK platform DTs are
  inclusive) — no per-variant dtbo needed.
* The MTK camera HAL (`libcameracustom` importers: ~30 modules such as
  `libcam.halsensor`, `libeffecthal.base`, `libfeatureiodrv_mem`,
  `libmtkcam_modulefactory_custom`) only need the *module name*
  `libcameracustom` to exist at build time — swapping which `.so` file
  that module installs is sufficient; no importer changes required.

## 2. The fix — part 1: ROM image (already applied to this workspace's `vendor\`)

The unpacked ROM vendor tree in this workspace (`vendor\`) has already been
patched and is the **source of truth** for the fixed image. All changes are
additive except the two swaps noted below.

| Action | File (under `vendor\`) | Size | SHA256 |
|--------|------------------------|------|--------|
| **swap** | `lib\modules\imgsensor_isp4.ko` | 443384 | `3e2f8a86ed390a9adead9a838babefea13107c456fa16d1b0947cc004cafedc1` |
| **swap** | `lib64\libcameracustom.so` | 3514200 | `e30561cd9c5fa48199eea6842d3e153792e229398eecbb9b72f8181f5f60f48d` |
| add | `lib64\imx582_mipi_raw_IdxMgr.so` | 10504 | `bd7a401997e00e26cbfb0b69ea632ecc5dfcad4e83578f8693c5a0f4f489c7e7` |
| add | `lib64\pblcimx582_mipi_raw_IdxMgr.so` | 10504 | `8b6ac424ca87c2431d199c7468efbcf7c58b3f95ee21fe36c69a4aa844fd678d` |
| add | `lib64\imx582_mipi_raw_tuning.so` | 2617408 | `cbda41573deb572163cde51f77ef742986bb3feec62703d495f770098a807d9e` |
| add | `lib64\pblcimx582_mipi_raw_tuning.so` | 2617416 | `73498ccf72f40365491458dc98663ae268375b1d2d5f5bf23a794f03c8aa9233` |
| add | `lib64\libanc_hdr_adapter_imx582_17201932_back_g81.so` | 4939576 | `15fcdae5057b59864eb378cc3aac7520c813795cbda20147df95e9a69b4956b4` |
| add | `etc\anc_siq\cache_imx582_17201932_back_g81` | 1080533 | `f2e4f5d33544332258f227f5342e7e252ab08f840638a9781a0ddbda747914ed` |
| add | `etc\anc_siq\dgain_mask_imx582_17201932_back_g81.bin` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` (empty on stock too) |
| add | `etc\anc_siq\siq_ocl_cache_imx582_17201932_back_g81` | 106640 | `56f894bd713c1c75b9e52ab731d760547ab8765d1caa9aec94876f600b2c23ba` |
| add | `etc\anc_siq\superiq_model_imx582_17201932_back_g81` | 3360754 | `0e92a258655120034e988b73e621756f07f6d9bcf90acc8fb998e603d06f8139` |

Notes:

* The **imgsensor ko** is the *stock KL5n* module with only its vermagic
  rewritten (`5.10.237-android12-9+` → `5.10.209-android12-9+`); no code
  was patched. The original ROM ko has **no** recoverable copy in this
  workspace (it is only inside the original `vendor.img` in the root
  zip / `payload.bin`) — re-extract from there if ever needed.
* The **libcameracustom.so** swap installs the stock KL5n library. The
  original ROM (KL5) copy is backed up at
  `backup\libcameracustom.KL5.rom.so`
  (3426024 B, SHA256
  `22599c2413c4e54b04bce4631a35ea55d7259cfc107f231f88790a81d23098a7`).
* fs_config and file_contexts entries for the new paths were added in the
  ROM tree (9 new entries each).

### Verification performed on the patched ROM tree

* `imgsensor_isp4.ko`: vermagic `5.10.209-android12-9+ SMP preempt
  mod_unload modversions aarch64`; no residual `5.10.237`; exports the
  full imx582 symbol set incl. `IMX582_MIPI_RAW_SensorInit`,
  `imx582_17201932`; **0 CRC conflicts** in `__versions`.
* `libcameracustom.so` (KL5n) vs the rest of the ROM image: 32 importers
  satisfied, **0 missing symbols**, no versioned references;
  `SensorInfoIdxMgr<1410>::impGetDefaultData` is defined by the imx582
  IdxMgr libs and imported by libcameracustom (gc08a8 uses template
  `<2216>` — template IDs are sensor-specific, no collision).
* Full dlopen chains checked: `%s_tuning.so` for imx582/pblcimx582,
  `libanc_hdr_adapter_imx582_*` by `libanc_hdr.so`,
  `anc_siq/*_imx582_*` by `libmtkcam_3rdparty.customer.so`.
* Only 64-bit camera stack is used by the ROM → the dump's 32-bit
  `vendor\lib\imx582*` files were deliberately **not** copied.

## 3. The fix — part 2: dual-target source tree (this repo)

To make the above reproducible from source, the KL5 device + vendor trees
now build two products. All edits are **additive**; the KL5 build behaves
exactly as before.

### Architecture

```
lineage_KL5.mk                          lineage_KL5n.mk
  SOONG_CONFIG … := kl5                   SOONG_CONFIG … := kl5n
        │                                       │
        ▼                                       ▼
device/tecno/KL5/device.mk   ◄── same file for both ──►
        │  (kl5n only)                                  │
        │  inherit vendor/tecno/KL5/KL5n-camera.mk      │
        ▼                                               ▼
vendor/tecno/KL5/KL5-vendor.mk (identical for both)
        │
        ▼
vendor/tecno/KL5/Android.bp
  libcameracustom  ──soong_config──►  proprietary/…/libcameracustom.so      (kl5)
                                   └► proprietary_kl5n/…/libcameracustom.so (kl5n)
```

### File map — what each piece does

**Vendor tree (`vendor/tecno/KL5`)**

| File | Status | Role |
|------|--------|------|
| `proprietary_kl5n/**` (11 files + Android.bp) | **new, hand-maintained** | The KL5n blobs listed in §2. Layout mirrors `proprietary/` (`vendor/lib64/…`, `vendor/lib/modules/…`, `vendor/etc/anc_siq/…`) under the `proprietary_kl5n/` root. |
| `proprietary_kl5n/Android.bp` | **new, hand-maintained** | soong modules `imx582_mipi_raw_IdxMgr`, `pblcimx582_mipi_raw_IdxMgr` (the two libs that are `DT_NEEDED` by the KL5n libcameracustom). These names did not previously exist in the tree. |
| `KL5n-camera.mk` | **new, hand-maintained** | `PRODUCT_COPY_FILES` for the dlopen'ed libs (2× tuning, hdr adapter, 4× anc_siq) + explicit `PRODUCT_PACKAGES` for the two IdxMgr modules. Inherited only by the kl5n product. |
| `Android.bp` (root, generated) | **hand-patched** | `soong_config_string_variable camera_variant` + `soong_config_module_type cc_prebuilt_library_shared_camera_variant` + `libcameracustom` converted to that type. `srcs` is **only** set inside the soong_config branches (kl5 → `proprietary/…`, kl5n → `proprietary_kl5n/…`); `shared_libs` is the **union** of both variants' `DT_NEEDED` sets so the ELF checker passes for either binary. |
| `KL5-vendor.mk` | unchanged | still installs `libcameracustom` via `PRODUCT_PACKAGES` for both variants — the soong_config switch decides *which file* that module installs. |
| `proprietary/vendor/lib64/libcameracustom.so` | unchanged | still the **KL5** original (SHA256 `22599c24…`). |

**Device tree (`device/tecno/KL5`)**

| File | Status | Role |
|------|--------|------|
| `AndroidProducts.mk` | edited | adds `lineage_KL5n.mk`; adds `COMMON_LUNCH_CHOICES` for both targets. |
| `lineage_KL5.mk` | edited (1 block) | sets `SOONG_CONFIG_tecno_camera_camera_variant := kl5` before inheriting device.mk. Nothing else changed. |
| `lineage_KL5n.mk` | **new** | KL5n product: `SOONG_CONFIG … := kl5n` *before* device.mk inherit; identity props from the stock dump (`PRODUCT_MODEL := TECNO KL5n`, fingerprint/desc `TECNO/KL5n-OP/…/260710V887`); `PRODUCT_DEVICE := KL5` (same device dir). |
| `device.mk` | edited (1 block) | after the `KL5-vendor.mk` inherit: `ifneq ($(filter kl5n,$(SOONG_CONFIG_tecno_camera_camera_variant)),)` → inherit `vendor/tecno/KL5/KL5n-camera.mk`. KL5 never triggers this. |
| `BoardConfig.mk` | edited (1 block) | for `PRODUCT_NAME = lineage_KL5n` only: `filter-out %/imgsensor_isp4.ko` from `BOARD_VENDOR_KERNEL_MODULES`, then re-add `vendor/tecno/KL5/proprietary_kl5n/vendor/lib/modules/imgsensor_isp4.ko`. Same basename → `modules/modules.load.vendor` and `rootdir/bin/init.insmod.sh` / `init.insmod.mt6768.cfg` need no changes. |
| `modules/modules.load.vendor` | unchanged | still lists `imgsensor_isp4.ko`. |

### Why soong_config for the libcameracustom swap?

* ~30 modules declare `shared_libs: ["libcameracustom"]` — the **module
  name must stay `libcameracustom`** for both variants, so two separate
  modules (`libcameracustom` + `libcameracustom.kl5n`) cannot work
  (the KL5 module would still be installed as a shared-lib dependency of
  the importers and clash on the output path).
* `PRODUCT_COPY_FILES` cannot override a file that soong installs.
* Therefore the single soong module must pick its `srcs` per product —
  which is exactly what `soong_config_module_type` does.
* **Gotcha encoded in the patch:** soong_config list properties
  **append** to base properties. If the module had a base `srcs:` *and* a
  `kl5n:` branch `srcs:`, the kl5n build would see two source files and
  fail. Hence `srcs` exists **only** inside the branches and *both*
  product makefiles set the variable explicitly.
* `shared_libs` stays in the base (union) list: extra entries are legal
  for prebuilts and the two new IdxMgr modules are defined unconditionally
  in `proprietary_kl5n/Android.bp`, so the ELF check has every
  `DT_NEEDED` satisfied for either binary. Side effect: a KL5 build
  installs two extra ~10 KB IdxMgr libs — inert, nothing loads them on
  KL5 hardware.

### How to build

```bash
# KL5 (unchanged behavior)
breakfast lineage_KL5-userdebug && m

# KL5n (imx582 back camera)
breakfast lineage_KL5n-userdebug && m
```

`PRODUCT_DEVICE` is `KL5` for both, so the same device dir, kernel tree
path (`KERNEL_PATH := device/tecno/KL5-kernel`, external) and dtbo apply.

### Regeneration caveats (read before running extract-files)

`./extract-files.py --regenerate_makefiles` (aka `setup-makefiles.py`)
rewrites the **root** `Android.bp`, `KL5-vendor.mk` and `Android.mk` of
the vendor tree from `proprietary-files.txt`. Consequences:

1. The hand-patched `libcameracustom` block in the root `Android.bp`
   reverts to a plain `cc_prebuilt_library_shared` with the KL5 srcs.
   **Re-apply the block** — the replacement text is marked with the
   `HAND PATCH — KL5 / KL5n camera split` banner comment in the current
   file; keep a copy of it (this README's §3 plus the committed file).
2. `KL5n-camera.mk` and `proprietary_kl5n/` are **not** listed in
   `proprietary-files.txt` (the imx582 files do not exist in the KL5
   dump), so the tool neither regenerates nor deletes them — they
   survive untouched.
3. `proprietary_kl5n/Android.bp` lives in a subdirectory the tool does
   not touch — safe.
4. The device-tree files (`lineage_KL5n.mk`, `device.mk`,
   `BoardConfig.mk`, `AndroidProducts.mk`) are never touched by the
   vendor tooling.

KL5-only sensor files (hi5022q/s5kjn1) remain in the shared blob set on
purpose: extra files are harmless on KL5n, while removing them would
break the KL5 build.

## 4. Recovery / rollback

* ROM `vendor\` tree: restore `libcameracustom.so` from
  `backup\libcameracustom.KL5.rom.so` to return to the original ROM HAL.
  The original `imgsensor_isp4.ko` must be re-extracted from the original
  `vendor.img` (root zip / `payload.bin`) — no local copy exists.
* Source tree: every edit is a clearly marked additive block
  (`HAND PATCH` banner in Android.bp; `## KL5n:` comments in
  BoardConfig.mk; the `ifneq … kl5n` block in device.mk). Deleting those
  blocks plus `proprietary_kl5n/`, `KL5n-camera.mk` and
  `lineage_KL5n.mk` returns both trees to pure-KL5 state.
* Known **pre-existing** issue (not introduced here): `lineage_KL5.mk`
  line ~30 is missing a trailing `\` after the `BuildFingerprint=` line,
  so the following `SystemModel=`/`SystemName=`/`ProductModel=`/
  `DeviceProduct=` overrides are silently ignored in the KL5 build.
  Left as-is deliberately (fixing it would change KL5 build.prop
  output); `lineage_KL5n.mk` is written correctly.

## 5. Workspace layout (this folder)

```
Project_Infinity-X-3.12-KL5-05.10.2026-GAPPS-UNOFFICIAL/
├── android_device_tecno_KL5-lineage-23.2/   ← this tree (README lives here)
├── android_vendor_tecno_KL5-lineage-23.2/   ← vendor blobs (+ proprietary_kl5n/, KL5n-camera.mk)
├── android_tools_extract-utils-lineage-23.0/← extract tooling
├── vendor/                                  ← unpacked ROM vendor.img (PATCHED, §2)
├── TECNO-KL5n-KL5n-XK678ORUWXAdAeAfP-U-OP-260710V808/ ← stock KL5n dump
├── backup/                                  ← libcameracustom.KL5.rom.so
├── payload.bin / vendor.img / *.img         ← original ROM payload
└── config/, META-INF/                       ← ROM repack scaffolding
```
