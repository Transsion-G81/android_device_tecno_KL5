package com.shade.handler;

import android.app.Service;
import android.content.BroadcastReceiver;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.res.Resources;
import android.database.ContentObserver;
import android.hardware.display.DisplayManager;
import android.net.Uri;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.provider.Settings;
import android.util.Log;
import android.view.Display;

import java.lang.reflect.Method;

public class QSShadeHandler extends Service {
    private static final String TAG = "QSShadeHandler";
    private static final String SETTING_QS_EXPANDED = "qs.fps.expanded";
    private static final String SETTING_PEAK_REFRESH_RATE = "peak_refresh_rate";
    private static final String SETTING_MIN_REFRESH_RATE = "min_refresh_rate";
    private static final long RESTORE_DELAY_MS = 150L;
    private static final long WAKE_BOUNCE_TIMEOUT_MS = 120L;

    private final Handler handler = new Handler(Looper.getMainLooper());
    private DisplayManager displayManager;
    private ContentObserver fpsObserver;
    private BroadcastReceiver screenReceiver;
    private DisplayManager.DisplayListener displayListener;

    private boolean shadeApplied = false;
    private String savedAnimScale = null;

    private boolean wasScreenOff = false;
    private boolean wakeBouncing = false;
    private boolean wakeChangedMin = false;
    private float wakeLowestFps = 60.0f;
    private String savedPeakRaw = null;
    private String savedMinRaw = null;

    private final Runnable restoreRunnable = new Runnable() {
        @Override
        public void run() {
            restoreAfterShade();
        }
    };

    private final Runnable wakeRestoreRunnable = new Runnable() {
        @Override
        public void run() {
            finishWakeBounce();
        }
    };

    @Override
    public void onCreate() {
        super.onCreate();
        displayManager = getSystemService(DisplayManager.class);

        fpsObserver = new ContentObserver(handler) {
            @Override
            public void onChange(boolean selfChange, Uri uri) {
                syncFpsExpanded();
            }
        };
        getContentResolver().registerContentObserver(
                Settings.System.getUriFor(SETTING_QS_EXPANDED), false, fpsObserver);

        screenReceiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                if (intent == null) {
                    return;
                }
                String action = intent.getAction();
                if (Intent.ACTION_SCREEN_OFF.equals(action)) {
                    wasScreenOff = true;
                    if (wakeBouncing) {
                        finishWakeBounce();
                    }
                } else if (Intent.ACTION_SCREEN_ON.equals(action)) {
                    if (wasScreenOff) {
                        wasScreenOff = false;
                        reapplyRefreshRateOnWake();
                    }
                }
            }
        };
        IntentFilter filter = new IntentFilter();
        filter.addAction(Intent.ACTION_SCREEN_OFF);
        filter.addAction(Intent.ACTION_SCREEN_ON);
        registerReceiver(screenReceiver, filter);

        syncFpsExpanded();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        handler.removeCallbacks(restoreRunnable);
        finishWakeBounce();
        if (screenReceiver != null) {
            unregisterReceiver(screenReceiver);
            screenReceiver = null;
        }
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
            shadeApplied = true;
        } catch (Exception e) {
            Log.e(TAG, "Failed to apply shade tuning", e);
        }
    }

    private void restoreAfterShade() {
        ContentResolver resolver = getContentResolver();
        try {
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

    private void reapplyRefreshRateOnWake() {
        if (displayManager == null) {
            return;
        }
        Display display = displayManager.getDisplay(Display.DEFAULT_DISPLAY);
        if (display == null) {
            return;
        }
        Display.Mode currentMode = display.getMode();
        Display.Mode[] modes = display.getSupportedModes();
        if (currentMode == null || modes == null || modes.length < 2) {
            return;
        }

        float lowestFps = Float.MAX_VALUE;
        float highestFps = 0f;
        for (Display.Mode m : modes) {
            if (m.getPhysicalWidth() == currentMode.getPhysicalWidth()
                    && m.getPhysicalHeight() == currentMode.getPhysicalHeight()) {
                float r = m.getRefreshRate();
                if (r < lowestFps) lowestFps = r;
                if (r > highestFps) highestFps = r;
            }
        }
        if (highestFps - lowestFps < 1.0f) {
            return;
        }

        ContentResolver resolver = getContentResolver();
        String peakRaw = Settings.System.getString(resolver, SETTING_PEAK_REFRESH_RATE);
        String minRaw = Settings.System.getString(resolver, SETTING_MIN_REFRESH_RATE);
        float defaultPeak = getDefaultPeakRefreshRate(highestFps);
        float peakVal = parseRefreshSetting(peakRaw, defaultPeak, highestFps);
        float minVal = parseRefreshSetting(minRaw, 0f, highestFps);
        if (Math.max(peakVal, minVal) <= lowestFps + 1.0f) {
            return;
        }

        finishWakeBounce();

        savedPeakRaw = peakRaw;
        savedMinRaw = minRaw;
        wakeLowestFps = lowestFps;
        wakeChangedMin = minVal > lowestFps + 1.0f;
        wakeBouncing = true;

        final boolean wasAboveLowest = currentMode.getRefreshRate() > lowestFps + 1.0f;
        if (wasAboveLowest) {
            displayListener = new DisplayManager.DisplayListener() {
                @Override
                public void onDisplayAdded(int displayId) {}

                @Override
                public void onDisplayRemoved(int displayId) {}

                @Override
                public void onDisplayChanged(int displayId) {
                    if (displayId != Display.DEFAULT_DISPLAY || !wakeBouncing || displayManager == null) {
                        return;
                    }
                    Display d = displayManager.getDisplay(Display.DEFAULT_DISPLAY);
                    if (d != null && d.getMode() != null
                            && d.getMode().getRefreshRate() <= wakeLowestFps + 1.0f) {
                        finishWakeBounce();
                    }
                }
            };
            displayManager.registerDisplayListener(displayListener, handler);
        }

        handler.postDelayed(wakeRestoreRunnable, WAKE_BOUNCE_TIMEOUT_MS);
        try {
            if (wakeChangedMin) {
                Settings.System.putFloat(resolver, SETTING_MIN_REFRESH_RATE, lowestFps);
            }
            Settings.System.putFloat(resolver, SETTING_PEAK_REFRESH_RATE, lowestFps);
        } catch (Exception e) {
            Log.e(TAG, "Failed to bounce refresh rate on wake", e);
            finishWakeBounce();
        }
    }

    private void finishWakeBounce() {
        handler.removeCallbacks(wakeRestoreRunnable);
        if (displayListener != null && displayManager != null) {
            displayManager.unregisterDisplayListener(displayListener);
            displayListener = null;
        }
        if (!wakeBouncing) {
            return;
        }
        wakeBouncing = false;
        ContentResolver resolver = getContentResolver();
        try {
            if (wakeChangedMin) {
                Settings.System.putString(resolver, SETTING_MIN_REFRESH_RATE, savedMinRaw);
            }
            Settings.System.putString(resolver, SETTING_PEAK_REFRESH_RATE, savedPeakRaw);
        } catch (Exception e) {
            Log.e(TAG, "Failed to restore refresh rate after wake", e);
        } finally {
            wakeChangedMin = false;
            savedPeakRaw = null;
            savedMinRaw = null;
        }
    }

    private static float getDefaultPeakRefreshRate(float fallback) {
        try {
            Resources res = Resources.getSystem();
            int id = res.getIdentifier("config_defaultPeakRefreshRate", "integer", "android");
            if (id != 0) {
                int val = res.getInteger(id);
                if (val > 0) {
                    return (float) val;
                }
            }
        } catch (Exception ignored) {
        }
        return fallback;
    }

    private static float parseRefreshSetting(String raw, float defaultVal, float highestFps) {
        if (raw == null) {
            return defaultVal;
        }
        try {
            float val = Float.parseFloat(raw);
            return Float.isInfinite(val) ? highestFps : val;
        } catch (NumberFormatException e) {
            return defaultVal;
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
}
