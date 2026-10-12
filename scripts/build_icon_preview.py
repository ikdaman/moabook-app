"""Build an offline visual comparison of the former and current icon sets."""
import html
from pathlib import Path
from design_asset_urls import version_links

ROOT = Path(__file__).resolve().parents[1]
LABELS = {
    'library': '기본 서가', 'layers': '주제 서가', 'library-active': '기본 서가 · 활성', 'layers-active': '주제 서가 · 활성',
    'book-open': '읽는 중 · 이북', 'bookmark': '책 저장', 'search': '검색', 'pencil': '편집 · 자유 기록',
    'quote': '마음에 든 문장', 'message-circle': '누구랑 얘기함', 'repeat-2': '다시 떠오름', 'handshake': '빌려줌', 'heart': '또 만남',
    'gift': '선물', 'calendar-days': '날짜 선택', 'circle-check': '완독', 'circle-pause': '쉬고 있음', 'check-check': '기록 완료',
    'camera': '표지 촬영', 'scan-barcode': '바코드', 'image': '갤러리', 'settings-2': '시안 설정', 'download': '이미지 저장',
    'plus': '추가', 'x': '닫기', 'check': '선택', 'chevron-left': '뒤로', 'chevron-right': '다음', 'chevron-down': '목록 펼치기',
    'arrow-left': '이전', 'arrow-right': '계속', 'sliders-horizontal': '필터', 'grid-2x2': '격자', 'list': '목록',
}


def build_icon_preview(output, version):
    rows = []
    for name, label in LABELS.items():
        previous_name = name.removesuffix('-active')
        previous = (ROOT / 'tools/design_gallery/previous-icons' / f'{previous_name}.svg').read_text()
        current = (ROOT / 'assets/design_preview/icons' / f'{name}.svg').read_text()
        rows.append(f'<article><h2>{html.escape(label)}</h2><div class="pair"><figure><div class="glyph">{previous}</div><figcaption>이전 · Lucide</figcaption></figure><figure><div class="glyph">{current}</div><figcaption>교체 · Bold</figcaption></figure></div></article>')
    page = '''<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>모아북 · 아이콘 교체 비교</title><link rel="stylesheet" href="fonts.css"><style>
*{box-sizing:border-box}body{margin:0;background:#F4F1EA;color:#1B1B1B;font-family:'IBM Plex Sans KR',sans-serif;line-height:1.5}main{max-width:1100px;margin:auto;padding:40px 24px}nav{display:flex;gap:20px;font-size:13px;margin-bottom:32px}h1{font-family:'Gowun Batang',serif;font-size:32px;margin:0 0 12px}p{font-size:14px;color:#68665e;max-width:680px}.grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:16px;margin-top:32px}article{border:1.5px solid #1B1B1B;background:#FFFDF8;padding:16px;border-radius:8px}h2{font-size:13px;font-weight:500;margin:0 0 18px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:10px}figure{margin:0;text-align:center}.glyph{height:62px;display:grid;place-items:center}.glyph svg{width:32px;height:32px}figcaption{font-size:10px;color:#68665e;margin-top:10px}footer{font-size:12px;margin-top:32px;color:#68665e}a{color:inherit}@media(max-width:800px){.grid{grid-template-columns:repeat(2,minmax(0,1fr))}}@media(max-width:400px){main{padding:24px 16px}article{padding:12px}figcaption{font-size:9px}}
</style></head><body><main><nav><a href="index.html">전체 화면 비교</a><a href="design-guide.html">디자인 가이드</a></nav><h1>아이콘 교체 비교</h1><p>기능과 의미를 유지하면서 아이콘의 형태를 Phosphor Bold 계열로 바꿨습니다. 작은 크기에서도 선이 또렷하도록 굵기를 맞췄습니다. 서가·컬렉션·독서·기록·촬영을 같은 세트로 맞추고, 활성 탭은 채워진 형태로 구분합니다. 실제 화면에 적용한 모습은 전체 화면 비교에서 확인할 수 있습니다.</p><section class="grid">'''+''.join(rows)+'''</section><footer>이전 Lucide · ISC / 현재 <a href="https://github.com/phosphor-icons/core">Phosphor Icons</a> · MIT</footer></main></body></html>'''
    notices = 'Lucide (comparison only)\n' + (ROOT / 'tools/design_gallery/previous-icons/LICENSE').read_text() + '\nPhosphor Icons\n' + (ROOT / 'assets/design_preview/icons/LICENSE').read_text()
    page = page.replace('<head>', '<head><!--\n' + notices.replace('--', '—') + '\n-->')
    (output / 'icons-preview.html').write_text(version_links(page, version))
    (output / 'icon-licenses.txt').write_text(notices)
