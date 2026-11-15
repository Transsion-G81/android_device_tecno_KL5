# patches/systemui

`0001-SystemUI-publish-shade-expanded-state.patch`

Adds to `NotificationShadeWindowControllerImpl.onShadeOrQsExpanded()`:

```java
Settings.System.putInt(mContext.getContentResolver(), "qs.fps.expanded",
        isExpanded ? 1 : 0);
```

ShadeProvider (`com.shade.handler`, packaged by `device.mk`) observes that setting and,
while the shade is open, lowers the SurfaceFlinger display mode index (`qs.fps.limited` /
`qs.blur.fps.limited`) and shortens `animator_duration_scale` to `0.85` when `qs.limited=1`.
No import change is needed - `Settings`, `Log`, `TAG` and `mContext` already exist in that class.

Applied by `vendorsetup.sh` on every `envsetup.sh` run, once, idempotently; opt out with
`PATCH_SHADE=0`. By hand, from `frameworks/base`:

```sh
git apply ../../device/tecno/KL5/patches/systemui/0001-*.patch
git apply --reverse ../../device/tecno/KL5/patches/systemui/0001-*.patch
```

Generated against lineage-23.2 `NotificationShadeWindowControllerImpl.java`,
sha256 `26561C2CB02F18FE60B1BC50210CE630188F77A9E03FC77ACCAED8237425D98F` (47936 bytes).
If that file changes the patch stops applying - `vendorsetup.sh` reports it.
