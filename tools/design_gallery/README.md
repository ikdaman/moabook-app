# 모아북 디자인 비교 웹페이지

`index.template.html`과 실제 시뮬레이터 캡처 manifest로 만드는 정적 갤러리입니다. 빌드 도구나 외부 CDN 없이 HTML과 로컬 이미지로 실행됩니다.

```sh
# 프로젝트 루트
python3 scripts/build_design_gallery.py
python3 -m http.server 8000 --bind 127.0.0.1 --directory output/design-preview/2026-10-09
```

http://127.0.0.1:8000 에서 확인합니다. 전체 캡처 스크립트 실행 시 갤러리도 자동 갱신됩니다.

기능: 화면 분류(서가/컬렉션/책 추가/독서카드/기록), A/C 비교 또는 단독 보기, 화면별 앵커 링크, 이미지 확대(전체/읽기/원본), PNG 다운로드, 모바일 바로가기. 확대 창은 Escape로 닫을 수 있으며 닫은 뒤 버튼으로 포커스가 돌아갑니다. 이미지는 지연 로딩합니다.

GitHub Pages에는 결과 폴더의 `index.html`, `design-guide.html`, `fonts.css`, `.nojekyll`, `A`, `C`, `fonts`, `reference`를 같은 구조로 올립니다. `output/moabook-design-share.zip`은 이 파일만 포함하는 업로드용 묶음입니다. 웹사이트는 정적 디자인 갤러리이고 앱을 웹에서 실행하는 것은 아닙니다.

현재 저장소의 Pages는 `main` 브랜치의 `/ (root)`를 배포합니다. 루트 `index.html`이 최신 갤러리로 이동시키고, `.nojekyll`로 정적 파일을 그대로 제공합니다.

공유 주소: https://ikdaman.github.io/moabook-app/

## 디자인 가이드와 최신 캡처

`design-guide.template.html`은 원본 Claude 가이드의 색·서체·선·컴포넌트 규격과 SVG 12개를 보관합니다. 생성되는 `design-guide.html`의 대표 화면 10장은 같은 manifest의 최신 실측 캡처입니다. SVG 복사와 A/C 가이드 바로가기를 사용할 수 있고, 각 화면을 누르면 전체 비교 갤러리로 이동합니다. 웹폰트와 라이선스, SVG도 로컬 파일로 함께 생성합니다.

2026-10-12에 원본의 선 굵기, 표지 그림자, 세로 책등 글자, 스탬프·괘선·탭바·띠지·4단 계단을 복원하고 전체 52장을 다시 촬영했습니다. 공유 시 `fonts.css`, `fonts`, `reference`, `design-guide.html`도 포함합니다.

요약 비교 이미지와 연락 시트도 다시 만들려면:

```sh
uv run --with pillow python scripts/build_design_contact_sheets.py
```

`icons-preview.html`에서는 이전 Lucide와 현재 Phosphor Bold 아이콘 34개 슬롯을 비교할 수 있습니다. 비교 기준 SVG는 `previous-icons/`에 보관하고, 새 아이콘의 고정 리비전·출처는 `assets/design_preview/icons/sources.json`에 기록합니다.

공유 ZIP에는 `icons-preview.html`과 `icon-licenses.txt`도 포함합니다. 아이콘은 32개 bold와 활성 탭 전용 fill 2개이며, 비교 HTML에 양쪽 라이선스 고지를 보관합니다.

서가 추가 페이지는 manifest의 `shelfPages`에 보관하며, 갤러리의 기본 서가 항목 아래에 A/C 비교로 표시합니다. 기본 52장과 각 스타일의 2페이지 이후를 모두 캡처합니다. 현재 iPhone 17에서는 90권이 3페이지, 페이지마다 3단으로 보입니다. 좁은 화면에서는 한 줄의 권수와 페이지 수를 자동 계산합니다.


## 2026-10-17 피드백 반영

주제 서가는 최신 생성순으로 진입하며, 좌우 스와이프로 책장을 넘긴다. 목록은 제목 우측 메뉴로 열고 마지막 페이지에는 새 책장 만들기를 둔다. 기본/주제 탭 간 스와이프는 없다. 다음 책장과 마지막 화면을 캡처 항목에 추가해 28개 화면 × A/C와 기본 서가 추가 4장, 총 60장을 제공한다.

이유 없는 책의 띠지와 `저장 이유 없음` 표기를 제거하고, 주제 서가 샘플은 대부분 띠지 없는 책으로 구성했다. 미확정 추천/WISH/선물/소개 칩과 범례를 제거했다. 기존 색 매핑은 변경하지 않았다. 공통 빈 화면의 아이콘 박스를 없애고 책 추가를 `+ 책 추가`로 표시한다. 독서카드는 기존 구성을 유지하며 서체와 메타 정보, 타임라인 장식을 정돈했다. 기록 작성의 본문·메모·날짜 입력만 직각 모서리로 바꾸고 다른 입력 스타일은 유지했다.

기획 확인이 필요한 컬렉션 부제목·편집 범위·현재 컬렉션 표시·문장/페이지 입력은 유지했다. 별도 제외 요청한 컬러칩 변경, 표지 테두리 조정, 독서카드 영역 재구성은 반영하지 않았다. 디자인 가이드의 원본 SVG 예시는 참고 자료이며, 최신 반영 화면은 실제 캡처에서 확인한다.
