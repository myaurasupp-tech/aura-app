#!/usr/bin/env bash
# ===========================================================================
#  AURA — הרשאות מצלמה ומיקרופון לאפליקציית אנדרואיד
#
#  למה הסקריפט הזה קיים:
#    בכל בנייה `npx cap add android` יוצר את תיקיית android/ **מאפס**, ולכן
#    כל עריכה ידנית במניפסט או ב-MainActivity נעלמת. לכן זה חייב לרוץ בכל בנייה.
#
#  למה זה קובץ נפרד ולא בתוך ה-workflow:
#    YAML דורש שכל שורה בתוך `run: |` תהיה מוזחת, וקוד רב-שורתי נשבר בקלות.
#    קובץ bash אמיתי = אפס הפתעות.
#
#  שני דברים נדרשים, ושניהם חסרו:
#    1. הצהרה ב-AndroidManifest.xml
#    2. **בקשה בזמן ריצה** ב-MainActivity — בלי זה אנדרואיד מסרב גם כשההצהרה
#       קיימת, והאתר פשוט לא מקבל הרשאה.
# ===========================================================================
set -euo pipefail

MAN=android/app/src/main/AndroidManifest.xml

if [ ! -f "$MAN" ]; then
  echo "ERROR: $MAN not found — the Android platform was not generated"
  exit 1
fi

echo "manifest : $MAN"

# ---- 1. הצהרת ההרשאות במניפסט --------------------------------------------
if grep -q "android.permission.CAMERA" "$MAN"; then
  echo "manifest : permissions already present"
else
  sed -i 's~<application~<uses-permission android:name="android.permission.CAMERA" />\n    <uses-permission android:name="android.permission.RECORD_AUDIO" />\n    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />\n\n    <application~' "$MAN"
  echo "manifest : permissions added"
fi

echo "--- manifest permissions now ---"
grep -n "uses-permission" "$MAN" || echo "(WARNING: no uses-permission found)"

# ---- 2. בקשה בזמן ריצה (MainActivity) -----------------------------------
ACT=$(find android/app/src/main/java -name MainActivity.java | head -1)

if [ -z "$ACT" ]; then
  echo "ERROR: MainActivity.java not found under android/app/src/main/java"
  exit 1
fi

echo "activity : $ACT"

cat > "$ACT" <<'AURA_JAVA'
package com.aura.gamer;

import android.Manifest;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Bundle;

import androidx.core.content.ContextCompat;

import com.getcapacitor.BridgeActivity;

/**
 * AURA - Android shell.
 *
 * The WebView shows the LIVE site (capacitor.config.json -> server.url),
 * so every web update reaches the app immediately.
 *
 * Camera and microphone need BOTH of these, and both were missing:
 *   1. a declaration in AndroidManifest.xml  -> done by scripts/patch-android.sh
 *   2. a RUNTIME request                     -> this file. Without it Android
 *      refuses even when the declaration exists, and the web page gets nothing.
 */
public class MainActivity extends BridgeActivity {
    private static final int AURA_AV_PERMISSIONS = 9001;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            boolean needCam = ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
                    != PackageManager.PERMISSION_GRANTED;
            boolean needMic = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
                    != PackageManager.PERMISSION_GRANTED;

            if (needCam || needMic) {
                requestPermissions(new String[] {
                        Manifest.permission.CAMERA,
                        Manifest.permission.RECORD_AUDIO
                }, AURA_AV_PERMISSIONS);
            }
        }
    }
}
AURA_JAVA

echo "activity : replaced"
echo "done"
