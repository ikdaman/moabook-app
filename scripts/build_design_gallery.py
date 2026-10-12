#!/usr/bin/env python3
"""Build the portable Moabook screenshot gallery from its capture manifest."""
import argparse
import html
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

def build(output):
    manifest = json.loads((output / 'manifest.json').read_text())
    screens = [x for x in manifest['screens'] if x['style'] == 'A']
    def group(key):
        if key.startswith('shelf'): return '서가'
        if key.startswith('collection'): return '컬렉션'
        if key.startswith('card'): return '독서카드'
        if key.startswith('record') or key == 'date-picker': return '기록'
        return '책 추가'
    notes = {
        'shelf':'90권의 책을 3단 서가에 배치하고 좌우 드래그로 페이지를 넘깁니다.',
        'collection':'표지에 붙는 진한 색 띠지로 저장 이유를 구분합니다.',
        'collections':'지금 보고 있는 컬렉션을 표시하고 다른 서가로 이동합니다.',
        'card-front':'검은 오프셋 그림자, A 괘선·스탬프와 C 컬러 히어로.',
        'card-back':'책과 함께한 시간을 날짜 순으로 모아봅니다.',
        'record-options':'기록 종류는 유지하면서 글씨와 선택 영역을 키웠습니다.',
        'save-wish':'읽고 싶은 이유를 남깁니다. 저장 상태는 세 가지를 유지합니다.',
        'save-reading':'읽기 시작한 날짜를 기록합니다.',
        'save-read':'시작한 날과 다 읽은 날을 함께 기록합니다.',
    }
    links=[];cards=[]
    for n,x in enumerate(screens,1):
        key=x['screen'];name=html.escape(x['label']);g=group(key)
        links.append(f'<a href="#{key}" data-group="{g}"><span>{n:02}</span>{name}</a>')
        figures=[]
        for style in ['A','C']:
            f=next(v['file'] for v in manifest['screens'] if v['screen']==key and v['style']==style)
            if not (output/f).is_file(): raise FileNotFoundError(f)
            figures.append(f'''<figure data-style="{style}"><figcaption><span class="style-dot {style.lower()}"></span><strong>{style}</strong><span>{'종이와 기록' if style=='A' else '색과 대비'}</span><a href="{f}" download aria-label="{style} {name} PNG 다운로드">PNG ↓</a></figcaption><button class="shot" data-src="{f}" data-name="{style} · {name}" aria-label="{style} {name} 확대"><img src="{f}" width="1206" height="2622" loading="{'eager' if n==1 else 'lazy'}" alt="{style} 시안 · {name}"><span class="enlarge">확대 보기 ↗</span></button></figure>''')
        pagination = ''
        if key == 'shelf':
            for page_number in sorted({item['page'] for item in manifest.get('shelfPages', [])}):
                page_figures = []
                for style in ['A', 'C']:
                    shot = next(item for item in manifest['shelfPages'] if item['page'] == page_number and item['style'] == style)
                    f = html.escape(shot['file'], quote=True)
                    caption = f'{style} · 서가 {page_number + 1} / {shot["pageCount"]}'
                    page_figures.append(f'<figure data-style="{style}"><figcaption><strong>{caption}</strong><a href="{f}" download>PNG ↓</a></figcaption><button class="shot" data-src="{f}" data-name="{caption}" aria-label="{caption} 확대"><img src="{f}" width="1206" height="2622" loading="lazy" alt="{caption}"><span class="enlarge">확대 보기 ↗</span></button></figure>')
                pagination += f'<section style="margin-top:32px"><h3 style="font-size:16px">서가 · {page_number + 1}페이지</h3><div class="pair">{"".join(page_figures)}</div></section>'
        cards.append(f'''<article id="{key}" data-group="{g}" data-label="{name}"><div class="screen-heading"><div><p class="overline">{g} <span>/{n:02}</span></p><h2>{name}</h2><p class="description">{html.escape(notes.get(key,'입력, 선택, 빈 화면까지 같은 디자인 원칙으로 연결합니다.'))}</p></div><a class="permalink" href="#{key}" aria-label="{name} 바로가기">#</a></div><div class="pair">{''.join(figures)}</div>{pagination}</article>''')
    template=(ROOT/'tools/design_gallery/index.template.html').read_text()
    page=template.replace('<!-- SCREEN_LINKS -->','\n'.join(links)).replace('<!-- SCREEN_CARDS -->','\n'.join(cards))
    (output/'index.html').write_text(page)
    (output/'.nojekyll').touch()
    from build_design_guide import build_guide
    build_guide(output, manifest)
    print(f'Gallery ready: {output / "index.html"} ({len(screens)} screens / {len(manifest['screens']) + len(manifest.get('shelfPages', []))} images)')

if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--output',type=Path,default=ROOT/'output/design-preview/2026-10-09')
    build(parser.parse_args().output)
