"""Découpe l'icône Collega rendue par render_icon_test.dart en toutes les tailles iOS."""
import json
from pathlib import Path

from PIL import Image

root = Path(__file__).resolve().parents[2]
icon = Image.open(root / 'build/icon/app_icon_1024.png').convert('RGB')  # App Store : pas de transparence
appicon = root / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
for entry in json.loads((appicon / 'Contents.json').read_text())['images']:
    points = float(entry['size'].split('x')[0])
    px = round(points * int(entry['scale'].rstrip('x')))
    icon.resize((px, px), Image.LANCZOS).save(appicon / entry['filename'])
    print(entry['filename'], px)

launch = Image.open(root / 'build/icon/launch_360.png').convert('RGBA')
out = root / 'ios/Runner/Assets.xcassets/LaunchImage.imageset'
for name, px in [('LaunchImage.png', 120), ('LaunchImage@2x.png', 240), ('LaunchImage@3x.png', 360)]:
    launch.resize((px, px), Image.LANCZOS).save(out / name)
    print(name, px)
