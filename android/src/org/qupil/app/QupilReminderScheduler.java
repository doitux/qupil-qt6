package org.qupil.app;

import android.Manifest;
import android.app.Activity;
import android.app.AlarmManager;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.Calendar;

public final class QupilReminderScheduler {
    static final String PREFS = "qupil_native_reminders";
    static final String PREF_SCHEDULE = "schedule";
    static final String PREF_LESSON_SOUND = "lesson_sound";
    static final String PREF_LESSON_VOLUME = "lesson_volume";
    static final String PREF_REMINDER_SOUND = "reminder_sound";
    static final String PREF_REMINDER_VOLUME = "reminder_volume";
    static final String CHANNEL_ID = "qupil_reminders";
    static final int NOTIFICATION_PERMISSION_REQUEST = 6418;

    private QupilReminderScheduler() {}

    public static void sync(Context context, String scheduleJson,
                            String lessonSoundPath, int lessonVolume,
                            String reminderSoundPath, int reminderVolume) {
        if (context == null)
            return;
        Context app = context.getApplicationContext();
        SharedPreferences prefs = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        String previous = prefs.getString(PREF_SCHEDULE, "[]");
        cancelSchedule(app, previous);
        prefs.edit()
                .putString(PREF_SCHEDULE, scheduleJson == null ? "[]" : scheduleJson)
                .putString(PREF_LESSON_SOUND, lessonSoundPath == null ? "" : lessonSoundPath)
                .putInt(PREF_LESSON_VOLUME, clampVolume(lessonVolume))
                .putString(PREF_REMINDER_SOUND, reminderSoundPath == null ? "" : reminderSoundPath)
                .putInt(PREF_REMINDER_VOLUME, clampVolume(reminderVolume))
                .apply();
        createNotificationChannel(app);
        requestNotificationPermissionIfNeeded(context, scheduleJson);
        restore(app);
    }

    static void restore(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        String json = prefs.getString(PREF_SCHEDULE, "[]");
        try {
            JSONArray array = new JSONArray(json == null ? "[]" : json);
            for (int i = 0; i < array.length(); ++i)
                scheduleSpec(context, array.getJSONObject(i));
        } catch (JSONException ignored) {
        }
    }

    static void rescheduleIdentifier(Context context, String identifier) {
        SharedPreferences prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        try {
            JSONArray array = new JSONArray(prefs.getString(PREF_SCHEDULE, "[]"));
            for (int i = 0; i < array.length(); ++i) {
                JSONObject item = array.getJSONObject(i);
                if (identifier.equals(item.optString("identifier"))) {
                    scheduleSpec(context, item);
                    return;
                }
            }
        } catch (JSONException ignored) {
        }
    }

    static JSONObject findSpec(Context context, String identifier) {
        SharedPreferences prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        try {
            JSONArray array = new JSONArray(prefs.getString(PREF_SCHEDULE, "[]"));
            for (int i = 0; i < array.length(); ++i) {
                JSONObject item = array.getJSONObject(i);
                if (identifier.equals(item.optString("identifier")))
                    return item;
            }
        } catch (JSONException ignored) {
        }
        return null;
    }

    private static void cancelSchedule(Context context, String json) {
        AlarmManager manager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        if (manager == null)
            return;
        try {
            JSONArray array = new JSONArray(json == null ? "[]" : json);
            for (int i = 0; i < array.length(); ++i) {
                String identifier = array.getJSONObject(i).optString("identifier");
                if (!identifier.isEmpty()) {
                    PendingIntent existing = pendingIntent(context, identifier, PendingIntent.FLAG_NO_CREATE);
                    if (existing != null)
                        manager.cancel(existing);
                }
            }
        } catch (JSONException ignored) {
        }
    }

    private static PendingIntent pendingIntent(Context context, String identifier, int extraFlags) {
        Intent intent = new Intent(context, QupilReminderReceiver.class);
        intent.setAction("org.qupil.app.REMINDER." + identifier);
        intent.putExtra("identifier", identifier);
        int flags = PendingIntent.FLAG_IMMUTABLE | extraFlags;
        if ((extraFlags & PendingIntent.FLAG_NO_CREATE) == 0)
            flags |= PendingIntent.FLAG_UPDATE_CURRENT;
        return PendingIntent.getBroadcast(context, identifier.hashCode(), intent, flags);
    }

    private static void scheduleSpec(Context context, JSONObject item) {
        String identifier = item.optString("identifier");
        if (identifier.isEmpty())
            return;
        AlarmManager manager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        if (manager == null)
            return;
        long triggerAt = nextOccurrence(item.optInt("day", 0),
                                        item.optInt("hour", 0),
                                        item.optInt("minute", 0));
        PendingIntent operation = pendingIntent(context, identifier, 0);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !manager.canScheduleExactAlarms()) {
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, operation);
        } else {
            manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, operation);
        }
    }

    private static long nextOccurrence(int mondayBasedDay, int hour, int minute) {
        Calendar now = Calendar.getInstance();
        Calendar target = Calendar.getInstance();
        target.set(Calendar.SECOND, 0);
        target.set(Calendar.MILLISECOND, 0);
        target.set(Calendar.HOUR_OF_DAY, hour);
        target.set(Calendar.MINUTE, minute);
        int targetDay = mondayBasedDay == 6 ? Calendar.SUNDAY : Calendar.MONDAY + mondayBasedDay;
        int delta = (targetDay - now.get(Calendar.DAY_OF_WEEK) + 7) % 7;
        target.add(Calendar.DAY_OF_YEAR, delta);
        if (delta == 0 && target.getTimeInMillis() <= now.getTimeInMillis())
            target.add(Calendar.DAY_OF_YEAR, 7);
        return target.getTimeInMillis();
    }

    public static boolean exactAlarmPermissionGranted(Context context) {
        if (context == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.S)
            return true;
        AlarmManager manager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        return manager != null && manager.canScheduleExactAlarms();
    }

    public static void requestExactAlarmPermission(Context context) {
        if (context == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.S || exactAlarmPermissionGranted(context))
            return;
        Intent intent = new Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                                   Uri.parse("package:" + context.getPackageName()));
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        context.startActivity(intent);
    }

    private static void requestNotificationPermissionIfNeeded(Context context, String scheduleJson) {
        if (Build.VERSION.SDK_INT < 33 || !(context instanceof Activity))
            return;
        if (!containsVisibleReminder(scheduleJson))
            return;
        Activity activity = (Activity) context;
        if (activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED)
            activity.requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, NOTIFICATION_PERMISSION_REQUEST);
    }

    private static boolean containsVisibleReminder(String scheduleJson) {
        try {
            JSONArray array = new JSONArray(scheduleJson == null ? "[]" : scheduleJson);
            for (int i = 0; i < array.length(); ++i) {
                if ("reminder".equals(array.getJSONObject(i).optString("kind")))
                    return true;
            }
        } catch (JSONException ignored) {
        }
        return false;
    }

    static void createNotificationChannel(Context context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O)
            return;
        NotificationManager manager = context.getSystemService(NotificationManager.class);
        if (manager == null)
            return;
        NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID, "Qupil reminders", NotificationManager.IMPORTANCE_DEFAULT);
        channel.setDescription("Lesson and pupil reminders from Qupil");
        channel.setSound(null, null);
        channel.enableVibration(false);
        manager.createNotificationChannel(channel);
    }

    static int clampVolume(int value) {
        return Math.max(0, Math.min(10, value));
    }
}
