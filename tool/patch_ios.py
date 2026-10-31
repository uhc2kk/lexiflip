"""Patches the files `flutter create` generates for iOS (run in CI).

- app name shown under the icon: LexiFlip
- exported/imported JSON files are visible in the Files app
- minimum iOS version for the plugins (Podfile)
- notification delegate so the daily reminder can be shown
"""
import pathlib
import re

plist = pathlib.Path('ios/Runner/Info.plist')
p = plist.read_text(encoding='utf-8')


def set_key(text, key, value_xml):
    pat = re.compile(r'<key>' + re.escape(key) + r'</key>\s*<[^>]+>[^<]*(</[^>]+>)?')
    if pat.search(text):
        return pat.sub(f'<key>{key}</key>\n\t{value_xml}', text, count=1)
    return text.replace('<dict>', f'<dict>\n\t<key>{key}</key>\n\t{value_xml}', 1)


p = set_key(p, 'CFBundleDisplayName', '<string>LexiFlip</string>')
p = set_key(p, 'CFBundleName', '<string>LexiFlip</string>')
p = set_key(p, 'UIFileSharingEnabled', '<true/>')
p = set_key(p, 'LSSupportsOpeningDocumentsInPlace', '<true/>')
p = set_key(p, 'ITSAppUsesNonExemptEncryption', '<false/>')
plist.write_text(p, encoding='utf-8')

podfile = pathlib.Path('ios/Podfile')
if podfile.exists():
    pf = podfile.read_text(encoding='utf-8')
    pf = re.sub(r"^#?\s*platform :ios, '[\d.]+'", "platform :ios, '13.0'", pf, flags=re.M)
    if "platform :ios" not in pf:
        pf = "platform :ios, '13.0'\n" + pf
    podfile.write_text(pf, encoding='utf-8')

# Let flutter_local_notifications show notifications.
for name in ('AppDelegate.swift',):
    f = pathlib.Path('ios/Runner') / name
    if f.exists():
        s = f.read_text(encoding='utf-8')
        if 'UNUserNotificationCenter' not in s:
            # First line of application(_:didFinishLaunchingWithOptions:).
            s = re.sub(
                r'(didFinishLaunchingWithOptions[^{]*\{)',
                r'\1\n    UNUserNotificationCenter.current().delegate = self',
                s,
                count=1,
            )
            if 'import UserNotifications' not in s:
                s = s.replace('import UIKit', 'import UIKit\nimport UserNotifications', 1)
            f.write_text(s, encoding='utf-8')
        print(s)

print(plist.read_text(encoding='utf-8'))
print(podfile.read_text(encoding='utf-8') if podfile.exists() else 'no Podfile yet')
