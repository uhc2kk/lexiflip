"""Patches the files `flutter create` generates for the web (run in CI).

Makes the web build behave like an app when it is added to the iPhone /
Android home screen: proper name, full-screen (standalone) mode, title.
"""
import json
import pathlib
import re

manifest = pathlib.Path('web/manifest.json')
m = json.loads(manifest.read_text(encoding='utf-8'))
m['name'] = 'LexiFlip'
m['short_name'] = 'LexiFlip'
m['description'] = "So'z yodlash kartochkalari"
m['display'] = 'standalone'
m['start_url'] = '.'
m['orientation'] = 'portrait'
manifest.write_text(json.dumps(m, ensure_ascii=False, indent=2), encoding='utf-8')

index = pathlib.Path('web/index.html')
s = index.read_text(encoding='utf-8')
s = re.sub(r'<title>.*?</title>', '<title>LexiFlip</title>', s, flags=re.S)
s = re.sub(r'(<meta name="apple-mobile-web-app-title" content=")[^"]*(")', r'\1LexiFlip\2', s)
if 'apple-mobile-web-app-capable' not in s:
    s = s.replace('</head>', '  <meta name="apple-mobile-web-app-capable" content="yes">\n</head>', 1)
if 'mobile-web-app-capable"' not in s.replace('apple-mobile-web-app-capable', ''):
    s = s.replace('</head>', '  <meta name="mobile-web-app-capable" content="yes">\n</head>', 1)
if 'viewport-fit' not in s:
    s = s.replace(
        '</head>',
        '  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n</head>',
        1,
    )
index.write_text(s, encoding='utf-8')

print(manifest.read_text(encoding='utf-8'))
print(s)
