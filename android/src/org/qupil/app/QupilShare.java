package org.qupil.app;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;

public final class QupilShare {
    private QupilShare() {}

    public static void sharePdf(Context context, String fileName, String title) {
        Uri uri = new Uri.Builder()
                .scheme("content")
                .authority(context.getPackageName() + ".shareprovider")
                .appendPath(fileName)
                .build();
        Intent send = new Intent(Intent.ACTION_SEND);
        send.setType("application/pdf");
        send.putExtra(Intent.EXTRA_STREAM, uri);
        send.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        Intent chooser = Intent.createChooser(send, title);
        if (!(context instanceof android.app.Activity))
            chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        context.startActivity(chooser);
    }
}
