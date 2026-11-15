package com.shade.handler;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

public class OnBootCompleteReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent != null && Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction())) {
            try {
                context.startService(new Intent(context, QSShadeHandler.class));
            } catch (RuntimeException ignored) {
            }
        }
    }
}
