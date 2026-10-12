"""Build the reference design guide with latest simulator captures and local fonts."""
import html
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def build_guide(output, manifest):
    fonts = output / 'fonts'
    fonts.mkdir(exist_ok=True)
    rules = []
    families = [
        ('IBM Plex Sans KR', 'IBMPlexSansKR', [('Regular', 400), ('Medium', 500), ('SemiBold', 600), ('Bold', 700)]),
        ('Gowun Batang', 'GowunBatang', [('Regular', 400), ('Bold', 700)]),
        ('IBM Plex Mono', 'IBMPlexMono', [('Medium', 500)]),
    ]
    for family, prefix, weights in families:
        for suffix, weight in weights:
            file = f'{prefix}-{suffix}.ttf'
            shutil.copy2(ROOT / 'assets/design_preview/fonts' / file, fonts / file)
            rules.append(f"@font-face{{font-family:'{family}';font-weight:{weight};font-style:normal;font-display:swap;src:url('fonts/{file}') format('truetype')}}")
    for license_file in (ROOT / 'assets/design_preview/fonts').rglob('*OFL*'):
        shutil.copy2(license_file, fonts / license_file.name)
    css = '\n'.join(rules)
    (output / 'fonts.css').write_text(css)
    page = (ROOT / 'tools/design_gallery/design-guide.template.html').read_text()
    page = page.replace('<!-- LOCAL_FONTS -->', '<link rel="stylesheet" href="fonts.css">')
    def screen(match):
        style, key = match.groups()
        shot = next(item for item in manifest['screens'] if item['style'] == style and item['screen'] == key)
        file = html.escape(shot['file'], quote=True)
        label = html.escape(f"{style} · {shot['label']}", quote=True)
        return f'<a class="actual-link" href="index.html#{key}" aria-label="{label} 비교"><img class="actual" src="{file}" alt="{label}" width="1206" height="2622" loading="lazy"></a>'
    page = re.sub(r'<!-- GUIDE_SCREEN_([AC])_([\w-]+) -->', screen, page)
    (output / 'design-guide.html').write_text(page)
    shutil.copytree(ROOT / 'assets/design_preview/reference', output / 'reference', dirs_exist_ok=True)

    from build_icon_preview import build_icon_preview
    build_icon_preview(output)
