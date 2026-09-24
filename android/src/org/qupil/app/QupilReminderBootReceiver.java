package org.qupil.app;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

public final class QupilReminderBootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        QupilReminderScheduler.restore(context.getApplicationContext());
    }
}
