package com.transsision.audioserver;

import android.app.Service;
import android.content.Intent;
import android.media.AudioDeviceCallback;
import android.media.AudioDeviceInfo;
import android.media.AudioManager;
import android.media.audiofx.Equalizer;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.util.Log;

public class AudioService extends Service {
    private static final String TAG = "TranAudioService";
    private static final short[] SPEAKER_BAND_LEVELS_MB = new short[] {
        -1000, 1325, 1325, 1325, 1325
    };
    private static final int MAX_INIT_RETRIES = 10;
    private static final long RETRY_DELAY_MS = 1000L;

    private final Handler handler = new Handler(Looper.getMainLooper());
    private AudioManager audioManager;
    private Equalizer equalizer;
    private int initRetries = 0;
    private boolean deviceCallbackRegistered = false;

    private final AudioDeviceCallback audioDeviceCallback = new AudioDeviceCallback() {
        @Override
        public void onAudioDevicesAdded(AudioDeviceInfo[] addedDevices) {
            updateEqualizerState();
        }

        @Override
        public void onAudioDevicesRemoved(AudioDeviceInfo[] removedDevices) {
            updateEqualizerState();
        }
    };

    private final Runnable initRetryRunnable = new Runnable() {
        @Override
        public void run() {
            initEqualizer();
        }
    };

    @Override
    public void onCreate() {
        super.onCreate();
        audioManager = getSystemService(AudioManager.class);
        if (audioManager != null) {
            audioManager.registerAudioDeviceCallback(audioDeviceCallback, handler);
            deviceCallbackRegistered = true;
        }
        initEqualizer();
    }

    private void initEqualizer() {
        if (equalizer != null) {
            updateEqualizerState();
            return;
        }
        try {
            equalizer = new Equalizer(0, 0);
            updateEqualizerState();
        } catch (RuntimeException e) {
            if (initRetries < MAX_INIT_RETRIES) {
                initRetries++;
                Log.w(TAG, "Equalizer init failed (attempt " + initRetries + "), retrying", e);
                handler.postDelayed(initRetryRunnable, RETRY_DELAY_MS);
            } else {
                Log.e(TAG, "Equalizer init failed permanently", e);
            }
        }
    }

    private boolean isExternalOutputConnected() {
        if (audioManager == null) {
            return false;
        }
        AudioDeviceInfo[] outputs = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS);
        for (AudioDeviceInfo dev : outputs) {
            switch (dev.getType()) {
                case AudioDeviceInfo.TYPE_WIRED_HEADSET:
                case AudioDeviceInfo.TYPE_WIRED_HEADPHONES:
                case AudioDeviceInfo.TYPE_LINE_ANALOG:
                case AudioDeviceInfo.TYPE_LINE_DIGITAL:
                case AudioDeviceInfo.TYPE_BLUETOOTH_SCO:
                case AudioDeviceInfo.TYPE_BLUETOOTH_A2DP:
                case AudioDeviceInfo.TYPE_HDMI:
                case AudioDeviceInfo.TYPE_HDMI_ARC:
                case AudioDeviceInfo.TYPE_USB_DEVICE:
                case AudioDeviceInfo.TYPE_USB_ACCESSORY:
                case AudioDeviceInfo.TYPE_DOCK:
                case AudioDeviceInfo.TYPE_USB_HEADSET:
                case AudioDeviceInfo.TYPE_HEARING_AID:
                case AudioDeviceInfo.TYPE_BLE_HEADSET:
                case AudioDeviceInfo.TYPE_BLE_SPEAKER:
                case AudioDeviceInfo.TYPE_HDMI_EARC:
                    return true;
                default:
                    break;
            }
        }
        return false;
    }

    private void updateEqualizerState() {
        if (equalizer == null) {
            return;
        }
        boolean externalConnected = isExternalOutputConnected();
        try {
            if (externalConnected) {
                if (equalizer.getEnabled()) {
                    equalizer.setEnabled(false);
                }
            } else {
                short[] range = equalizer.getBandLevelRange();
                short minLevel = range[0];
                short maxLevel = range[1];
                short bands = equalizer.getNumberOfBands();
                int count = Math.min(bands, SPEAKER_BAND_LEVELS_MB.length);
                for (short i = 0; i < count; i++) {
                    short level = SPEAKER_BAND_LEVELS_MB[i];
                    if (level < minLevel) {
                        level = minLevel;
                    } else if (level > maxLevel) {
                        level = maxLevel;
                    }
                    equalizer.setBandLevel(i, level);
                }
                if (!equalizer.getEnabled()) {
                    equalizer.setEnabled(true);
                }
            }
        } catch (RuntimeException e) {
            Log.w(TAG, "Failed to update equalizer state", e);
        }
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        updateEqualizerState();
        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        handler.removeCallbacks(initRetryRunnable);
        if (audioManager != null && deviceCallbackRegistered) {
            audioManager.unregisterAudioDeviceCallback(audioDeviceCallback);
            deviceCallbackRegistered = false;
        }
        if (equalizer != null) {
            try {
                equalizer.setEnabled(false);
            } catch (RuntimeException ignored) {
            }
            equalizer.release();
            equalizer = null;
        }
        super.onDestroy();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}
