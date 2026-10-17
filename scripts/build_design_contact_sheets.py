"""Build overview images from captured PNGs. Run with Pillow installed."""
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'output/design-preview/2026-10-09'


def sheet(items, destination, columns, width=240):
    height = round(width * 2622 / 1206)
    rows = (len(items) + columns - 1) // columns
    result = Image.new('RGB', (columns * (width + 16), rows * (height + 38)), '#e5e2db')
    draw = ImageDraw.Draw(result)
    for n, item in enumerate(items):
        x = (n % columns) * (width + 16) + 8
        y = (n // columns) * (height + 38) + 26
        with Image.open(OUTPUT / item['file']) as image:
            image = image.convert('RGB').resize((width, height), Image.Resampling.LANCZOS)
            result.paste(image, (x, y))
        draw.text((x, y - 19), f"{item['style']} / {item['screen']}", fill='#1b1b1b')
    result.save(destination)


if __name__ == '__main__':
    manifest = json.loads((OUTPUT / 'manifest.json').read_text())
    for style in ['A', 'C']:
        shots = [item for item in manifest['screens'] if item['style'] == style]
        for n in range(2):
            sheet(shots[n * 14:(n + 1) * 14], OUTPUT / f'contact-{style}-{n + 1}.jpg', 4, 240)
    selected = [item for style in ['A', 'C'] for key in ['shelf', 'collection', 'card-front', 'record-options']
                for item in manifest['screens'] if item['style'] == style and item['screen'] == key]
    sheet(selected, OUTPUT / 'comparison.png', 4, 300)
