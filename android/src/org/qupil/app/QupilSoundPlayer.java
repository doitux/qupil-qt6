package org.qupil.app;

import android.content.Context;
import android.media.AudioAttributes;
import android.media.MediaPlayer;

import java.io.File;

/** Small native player for foreground reminder previews.
 *
 * Qupil only needs Qt Multimedia's integrated QSoundEffect path on Android for
 * metronome/tuning WAVs. Custom reminder files are handed to Android's own
 * MediaPlayer so the large Qt FFmpeg media backend does not have to ship in
 * the APK.
 */
public final class QupilSoundPlayer {
    private static MediaPlayer activePlayer;

    private QupilSoundPlayer() {}

    public static synchronized void play(Context context, String profile, String path, int volume) {
        stopLocked();
        if (context == null)
            return;

        final int clamped = Math.max(0, Math.min(10, volume));
        if (clamped == 0)
            return;

        Context app = context.getApplicationContext();
        AudioAttributes attributes = new AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build();

        MediaPlayer player = null;
        if (path != null && !path.isEmpty() && new File(path).isFile()) {
            try {
                player = new MediaPlayer();
                player.setAudioAttributes(attributes);
                player.setDataSource(path);
                player.prepare();
            } catch (Exception ignored) {
                if (player != null)
                    player.release();
                player = null;
            }
        }

        if (player == null) {
            boolean lessonEnd = "lessonEnd".equals(profile);
            player = MediaPlayer.create(app, lessonEnd ? R.raw.lesson_end : R.raw.reminder,
                    attributes, 0);
        }
        if (player == null)
            return;

        final MediaPlayer current = player;
        activePlayer = current;
        float gain = clamped / 10.0f;
        current.setVolume(gain, gain);
        current.setOnCompletionListener(mp -> releaseIfCurrent(mp));
        current.setOnErrorListener((mp, what, extra) -> {
            releaseIfCurrent(mp);
            return true;
        });
        current.start();
    }

    private static synchronized void releaseIfCurrent(MediaPlayer player) {
        try {
            player.release();
        } catch (Exception ignored) {
        }
        if (activePlayer == player)
            activePlayer = null;
    }

    private static void stopLocked() {
        if (activePlayer == null)
            return;
        try {
            activePlayer.stop();
        } catch (Exception ignored) {
        }
        try {
            activePlayer.release();
        } catch (Exception ignored) {
        }
        activePlayer = null;
    }
}
