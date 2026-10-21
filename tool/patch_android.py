"""Patches the files `flutter create` generates for Android (run in CI).

- INTERNET permission (auto-fill), TTS service query (Android 11+)
- daily reminder: boot receiver, scheduled-notification receivers
- core library desugaring (required by flutter_local_notifications)
"""
import pathlib
import re

root = pathlib.Path('android/app')
manifest = root / 'src/main/AndroidManifest.xml'
m = manifest.read_text(encoding='utf-8')

perms = [
    'android.permission.INTERNET',
    'android.permission.RECEIVE_BOOT_COMPLETED',
]
for p in perms:
    if p not in m:
        m = m.replace('<application', f'<uses-permission android:name="{p}"/>\n    <application', 1)

if 'android.intent.action.TTS_SERVICE' not in m:
    m = m.replace('</manifest>', '''    <queries>
        <intent>
            <action android:name="android.intent.action.TTS_SERVICE"/>
        </intent>
    </queries>
</manifest>''')

if 'ScheduledNotificationReceiver' not in m:
    m = m.replace('</application>', '''    <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
    </application>''', 1)
manifest.write_text(m, encoding='utf-8')

kts = root / 'build.gradle.kts'
groovy = root / 'build.gradle'
if kts.exists():
    g = kts.read_text(encoding='utf-8')
    if 'isCoreLibraryDesugaringEnabled' not in g:
        g = re.sub(r'compileOptions\s*\{', 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true', g, count=1)
        g += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
    kts.write_text(g, encoding='utf-8')
elif groovy.exists():
    g = groovy.read_text(encoding='utf-8')
    if 'coreLibraryDesugaringEnabled' not in g:
        g = re.sub(r'compileOptions\s*\{', 'compileOptions {\n        coreLibraryDesugaringEnabled true', g, count=1)
        g += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
    groovy.write_text(g, encoding='utf-8')

print(manifest.read_text(encoding='utf-8'))
print((kts if kts.exists() else groovy).read_text(encoding='utf-8'))
