package com.shade.handler;

import android.app.Service;
import android.content.ContentResolver;
import android.content.Intent;
import android.database.ContentObserver;
import android.net.Uri;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.Parcel;
import android.provider.Settings;
import android.util.Log;

import java.lang.reflect.Method;

public class QSShadeHandler extends Service {
    private static final String TAG = "QSShadeHandler";
    private static final String SETTING_QS_EXPANDED = "qs.fps.expanded";
    private static final String SETTING_DISABLE_BLURS = "disable_window_blurs";
    private static final int SF_TX_SET_DEBUG_MODE = 1035;
    private static final long RESTORE_DELAY_MS = 150L;

    private final Handler handler = new Handler(Looper.getMainLooper());
    private ContentObserver fpsObserver;
    private boolean shadeApplied = false;
    private String savedAnimScale = null;

    private final Runnable restoreRunnable = new Runnable() {
        @Override
        public void run() {
            restoreAfterShade();
        }
    };

    @Override
    public void onCreate() {
        super.onCreate();
        fpsObserver = new ContentObserver(handler) {
            @Override
            public void onChange(boolean selfChange, Uri uri) {
                syncFpsExpanded();
            }
        };
        getContentResolver().registerContentObserver(
                Settings.System.getUriFor(SETTING_QS_EXPANDED), false, fpsObserver);
        syncFpsExpanded();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        handler.removeCallbacks(restoreRunnable);
        if (fpsObserver != null) {
            getContentResolver().unregisterContentObserver(fpsObserver);
            fpsObserver = null;
        }
        if (shadeApplied) {
            restoreAfterShade();
        }
        super.onDestroy();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    private void syncFpsExpanded() {
        ContentResolver resolver = getContentResolver();
        int limited = getProp("qs.limited", 0);
        if (limited != 1) {
            return;
        }
        int expanded = Settings.System.getInt(resolver, SETTING_QS_EXPANDED, 0);
        if (expanded == 1) {
            handler.removeCallbacks(restoreRunnable);
            applyForShade(resolver);
        } else if (shadeApplied) {
            handler.removeCallbacks(restoreRunnable);
            handler.postDelayed(restoreRunnable, RESTORE_DELAY_MS);
        }
    }

    private void applyForShade(ContentResolver resolver) {
        try {
            if (!shadeApplied) {
                savedAnimScale = Settings.Global.getString(
                        resolver, Settings.Global.ANIMATOR_DURATION_SCALE);
                int animLimited = getProp("qs.anim.limited", 1);
                if (animLimited == 1) {
                    float currentScale = parseFloat(savedAnimScale, 1.0f);
                    if (savedAnimScale == null || (currentScale > 0.9f && currentScale < 1.09f)) {
                        Settings.Global.putString(
                                resolver, Settings.Global.ANIMATOR_DURATION_SCALE, "0.85");
                    } else {
                        savedAnimScale = null;
                    }
                } else {
                    savedAnimScale = null;
                }
            }

            int blursDisabled = Settings.Global.getInt(resolver, SETTING_DISABLE_BLURS, 0);
            int targetMode = (blursDisabled == 0)
                    ? getProp("qs.blur.fps.limited", 1)
                    : getProp("qs.fps.limited", 1);
            forceFps(targetMode);
            shadeApplied = true;
        } catch (Exception e) {
            Log.e(TAG, "Failed to apply shade tuning", e);
        }
    }

    private void restoreAfterShade() {
        ContentResolver resolver = getContentResolver();
        try {
            forceFps(-1);
            if (savedAnimScale != null && getProp("qs.anim.limited", 1) == 1) {
                Settings.Global.putString(
                        resolver, Settings.Global.ANIMATOR_DURATION_SCALE, savedAnimScale);
            }
        } catch (Exception e) {
            Log.e(TAG, "Failed to restore after shade", e);
        } finally {
            shadeApplied = false;
            savedAnimScale = null;
        }
    }

    private static float parseFloat(String val, float fallback) {
        if (val == null) {
            return fallback;
        }
        try {
            return Float.parseFloat(val);
        } catch (NumberFormatException e) {
            return fallback;
        }
    }

    private static int getProp(String key, int fallback) {
        try {
            Class<?> sp = Class.forName("android.os.SystemProperties");
            Method getInt = sp.getMethod("getInt", String.class, int.class);
            Object res = getInt.invoke(null, key, fallback);
            if (res instanceof Integer) {
                return (Integer) res;
            }
        } catch (Exception e) {
            Log.w(TAG, "getProp failed for " + key, e);
        }
        return fallback;
    }

    private static void forceFps(int mode) {
        try {
            Class<?> sm = Class.forName("android.os.ServiceManager");
            Method getService = sm.getMethod("getService", String.class);
            IBinder sf = (IBinder) getService.invoke(null, "SurfaceFlinger");
            if (sf == null) {
                return;
            }
            Parcel data = Parcel.obtain();
            try {
                data.writeInterfaceToken("android.ui.ISurfaceComposer");
                data.writeInt(mode);
                sf.transact(SF_TX_SET_DEBUG_MODE, data, null, 0);
            } finally {
                data.recycle();
            }
        } catch (Exception e) {
            Log.w(TAG, "Failed to set SurfaceFlinger mode " + mode, e);
        }
    }
}
