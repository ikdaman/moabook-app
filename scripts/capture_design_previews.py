#!/usr/bin/env python3
"""Capture real iOS simulator PNGs from the offline Flutter design host.

Usage: python3 scripts/capture_design_previews.py --vm-url URL --device UDID
The URL is the Dart VM service URL printed by flutter run --machine.
No backend calls or user account data are used.
"""
import argparse
import datetime
import json
from pathlib import Path
import re
import subprocess
import time
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--vm-url', required=True)
    parser.add_argument('--device', required=True)
    parser.add_argument('--output', type=Path, default=ROOT / 'output/design-preview/2026-10-09')
    args = parser.parse_args()
    base = args.vm_url.replace('ws://', 'http://').replace('wss://', 'https://').removesuffix('/ws').rstrip('/') + '/'

    def rpc(method, **params):
        with urllib.request.urlopen(base + method + '?' + urllib.parse.urlencode(params), timeout=30) as response:
            payload = json.load(response)
        if 'error' in payload:
            raise RuntimeError(payload['error'])
        return payload['result']

    isolates = rpc('getVM')['isolates']
    isolate = next(item['id'] for item in isolates if item['name'] == 'main')
    registry = (ROOT / 'lib/design_preview/sample_data.dart').read_text().split('const previewScreens', 1)[1]
    screens = re.findall(r"^\s*'([^']+)': '([^']+)',", registry, re.M)
    if not screens:
        raise RuntimeError('Screen registry is empty')
    args.output.mkdir(parents=True, exist_ok=True)
    manifest = {
        'device': 'iPhone 17', 'deviceId': args.device,
        'capturedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'source': 'xcrun simctl io screenshot; rendered by Flutter on iOS Simulator',
        'screens': [],
    }
    for style in ['A', 'C']:
        folder = args.output / style
        folder.mkdir(exist_ok=True)
        for index, (screen, label) in enumerate(screens, 1):
            result = rpc('ext.moabook.preview', isolateId=isolate, style=style, screen=screen)
            if result != {'screen': screen, 'style': style}:
                raise RuntimeError(f'Unexpected rendered screen: {result}')
            # Allow native compositor and local cover/font assets to finish presenting.
            time.sleep(.6)
            file = folder / f'{index:02}-{screen}.png'
            subprocess.run(['xcrun', 'simctl', 'io', args.device, 'screenshot', str(file)], check=True, capture_output=True)
            if file.stat().st_size < 10000:
                raise RuntimeError(f'Unexpected screenshot size: {file}')
            manifest['screens'].append({'style': style, 'screen': screen, 'label': label, 'file': str(file.relative_to(args.output))})
            print(f'{style} {index:02}/{len(screens)} {screen}', flush=True)
    (args.output / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2))
    from build_design_gallery import build
    build(args.output)
    print(f'Saved {len(manifest["screens"])} screenshots to {args.output}')
    # Leave the simulator on the editorial home for hands-on review.
    rpc('ext.moabook.preview', isolateId=isolate, style='A', screen='shelf')


if __name__ == '__main__':
    main()
