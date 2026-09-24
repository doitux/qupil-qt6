package org.qupil.app;

import android.Manifest;
import android.app.ActivityManager;
import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.media.AudioAttributes;
import android.media.MediaPlayer;
import android.os.Build;
import android.os.PowerManager;

import org.json.JSONObject;

import java.io.File;

public final class QupilReminderReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        final String identifier = intent == null ? "" : intent.getStringExtra("identifier");
        if (identifier == null || identifier.isEmpty())
            return;
        final JSONObject spec = QupilReminderScheduler.findSpec(context, identifier);
        if (spec == null)
            return;

        final PendingResult pending = goAsync();
        final String kind = spec.optString("kind");
        final boolean inAppReminder = "reminder".equals(kind) && isAppForeground();
        if ("reminder".equals(kind) && !inAppReminder)
            showReminderNotification(context, spec, identifier);

        final boolean playSound = "lessonEnd".equals(kind)
                || (!inAppReminder && spec.optBoolean("sound", false));
        if (playSound)
            playSound(context, kind, pending);
        else
            pending.finish();

        QupilReminderScheduler.rescheduleIdentifier(context, identifier);
    }


    private static boolean isAppForeground() {
        ActivityManager.RunningAppProcessInfo info = new ActivityManager.RunningAppProcessInfo();
        ActivityManager.getMyMemoryState(info);
        return info.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND;
    }

    private static void showReminderNotification(Context context, JSONObject spec, String identifier) {
        if (Build.VERSION.SDK_INT >= 33
                && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED)
            return;
        QupilReminderScheduler.createNotificationChannel(context);
        NotificationManager manager = context.getSystemService(NotificationManager.class);
        if (manager == null)
            return;

        Intent launch = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
        PendingIntent contentIntent = null;
        if (launch != null) {
            launch.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
            contentIntent = PendingIntent.getActivity(context, identifier.hashCode(), launch,
                    PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        }

        Notification.Builder builder = new Notification.Builder(context, QupilReminderScheduler.CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(spec.optString("title", "Qupil"))
                .setContentText(spec.optString("body", ""))
                .setAutoCancel(true)
                .setOnlyAlertOnce(true)
                .setSound(null);
        if (contentIntent != null)
            builder.setContentIntent(contentIntent);
        manager.notify(identifier.hashCode(), builder.build());
    }

    private static void playSound(Context context, String kind, PendingResult pending) {
        PowerManager.WakeLock wakeLock = null;
        try {
            PowerManager power = (PowerManager) context.getSystemService(Context.POWER_SERVICE);
            if (power != null) {
                wakeLock = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Qupil:ReminderSound");
                wakeLock.acquire(35000L);
            }

            boolean lessonEnd = "lessonEnd".equals(kind);
            android.content.SharedPreferences prefs = context.getSharedPreferences(
                    QupilReminderScheduler.PREFS, Context.MODE_PRIVATE);
            String path = prefs.getString(lessonEnd ? QupilReminderScheduler.PREF_LESSON_SOUND
                                                    : QupilReminderScheduler.PREF_REMINDER_SOUND, "");
            int volume = prefs.getInt(lessonEnd ? QupilReminderScheduler.PREF_LESSON_VOLUME
                                               : QupilReminderScheduler.PREF_REMINDER_VOLUME, 7);
            final float gain = QupilReminderScheduler.clampVolume(volume) / 10.0f;

            AudioAttributes audioAttributes = new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build();
            MediaPlayer player = new MediaPlayer();
            player.setAudioAttributes(audioAttributes);
            boolean customReady = false;
            if (path != null && !path.isEmpty() && new File(path).isFile()) {
                try {
                    player.setDataSource(path);
                    customReady = true;
                } catch (Exception ignored) {
                }
            }
            if (!customReady) {
                player.release();
                player = MediaPlayer.create(context, lessonEnd ? R.raw.lesson_end : R.raw.reminder,
                                            audioAttributes, 0);
            } else {
                player.prepare();
            }
            if (player == null) {
                if (wakeLock != null && wakeLock.isHeld()) wakeLock.release();
                pending.finish();
                return;
            }
            final MediaPlayer finalPlayer = player;
            final PowerManager.WakeLock finalWakeLock = wakeLock;
            player.setVolume(gain, gain);
            player.setOnCompletionListener(mp -> {
                mp.release();
                if (finalWakeLock != null && finalWakeLock.isHeld()) finalWakeLock.release();
                pending.finish();
            });
            player.setOnErrorListener((mp, what, extra) -> {
                mp.release();
                if (finalWakeLock != null && finalWakeLock.isHeld()) finalWakeLock.release();
                pending.finish();
                return true;
            });
            player.start();
        } catch (Exception error) {
            if (wakeLock != null && wakeLock.isHeld()) wakeLock.release();
            pending.finish();
        }
    }
}
