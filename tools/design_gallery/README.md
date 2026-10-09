# 모아북 디자인 비교 웹페이지

`index.template.html`과 실제 시뮬레이터 캡처 manifest로 만드는 정적 갤러리입니다. 빌드 도구나 외부 CDN 없이 HTML과 로컬 이미지로 실행됩니다.

```sh
# 프로젝트 루트
python3 scripts/build_design_gallery.py
python3 -m http.server 8000 --bind 127.0.0.1 --directory output/design-preview/2026-10-09
```

http://127.0.0.1:8000 에서 확인합니다. 전체 캡처 스크립트 실행 시 갤러리도 자동 갱신됩니다.

기능: 화면 분류(서가/컬렉션/책 추가/독서카드/기록), A/C 비교 또는 단독 보기, 화면별 앵커 링크, 이미지 확대(전체/읽기/원본), PNG 다운로드, 모바일 바로가기. 확대 창은 Escape로 닫을 수 있으며 닫은 뒤 버튼으로 포커스가 돌아갑니다. 이미지는 지연 로딩합니다.

GitHub Pages에는 결과 폴더의 `index.html`, `.nojekyll`, `A`, `C`를 같은 구조로 올립니다. `output/moabook-design-share.zip`은 이 파일만 포함하는 업로드용 묶음입니다. 웹사이트는 정적 디자인 갤러리이고 앱을 웹에서 실행하는 것은 아닙니다.

현재 저장소의 Pages는 `main` 브랜치의 `/ (root)`를 배포합니다. 루트 `index.html`이 최신 갤러리로 이동시키고, `.nojekyll`로 정적 파일을 그대로 제공합니다.

공유 주소: https://ikdaman.github.io/moabook-app/
