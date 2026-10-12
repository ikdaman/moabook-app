"""Content versions for portable gallery assets and navigation."""
import hashlib
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def asset_url(output, file):
    version = hashlib.sha256((output / file).read_bytes()).hexdigest()[:12]
    return f'{file}?v={version}'


def gallery_version(output, manifest):
    digest = hashlib.sha256((output / 'manifest.json').read_bytes())
    for shot in manifest['screens'] + manifest.get('shelfPages', []):
        digest.update(asset_url(output, shot['file']).encode())
    for folder in ['scripts', 'tools/design_gallery', 'assets/design_preview/icons', 'assets/design_preview/fonts', 'assets/design_preview/reference']:
        for file in sorted((ROOT / folder).rglob('*')):
            if file.is_file() and file.suffix in {'.py', '.html', '.svg', '.json', '.ttf'}:
                digest.update(file.relative_to(ROOT).as_posix().encode())
                digest.update(file.read_bytes())
    return digest.hexdigest()[:12]


def version_links(page, version):
    return re.sub(r'href="(index\.html|design-guide\.html|icons-preview\.html|fonts\.css)(?=["#])',
                  lambda match: f'href="{match[1]}?v={version}', page)
