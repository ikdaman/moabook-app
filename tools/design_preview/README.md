# 모아북 A/C 디자인 프리뷰

백엔드 없이 실행하는 Flutter iOS 디자인 검토 앱입니다. 앱 코드는 `../../lib/design_preview`, 리소스는 `../../assets/design_preview`를 심볼릭 링크로 공유합니다.

- A: 따뜻한 종이색, 고운바탕 제목, 선과 날짜 도장을 사용한 독서카드.
- C: 어두운 서가, 오렌지 카드, 라임 띠지와 보라색 기록 분류.
- 26개 화면 × 2개 스타일, 실제 책 표지와 Lucide SVG 아이콘 사용.
- 시뮬레이터 화면: `../../output/design-preview/2026-10-09/index.html`.

## 실행

프로젝트 루트에서:

```sh
cd tools/design_preview
flutter pub get
flutter run -d 'iPhone 17'
```

서가 우측 설정 아이콘에서 A/C를 전환합니다. 책 추가 → 검색/촬영/갤러리 → 책 정보 → 세 가지 저장 상태 → 독서카드 → 기록 추가 흐름을 확인할 수 있습니다. 주제서가 제목을 누르면 나의 컬렉션이 열립니다.

기존 앱의 네이티브 플러그인에 영향을 받지 않도록 별도의 가벼운 iOS 호스트를 사용합니다. 기존 앱 진입점은 유지합니다.

## 전체 화면 다시 캡처

Flutter 실행 로그에 표시된 Dart VM Service URL을 사용합니다. 다른 터미널에서 프로젝트 루트로 이동한 뒤:

```sh
xcrun simctl list devices booted
python3 scripts/capture_design_previews.py --vm-url '<Dart VM Service URL>' --device '<시뮬레이터 UDID>'
```

실제 `simctl io screenshot`으로 52개의 원본 PNG(현재 iPhone 17: 1206×2622)를 저장하고 비교 갤러리와 manifest를 생성합니다. 화면 레지스트리는 `lib/design_preview/sample_data.dart`에 있습니다.

## 확인 범위

서가/빈 서가, 주제서가, 컬렉션 목록/빈 목록/생성/편집, 책 추가 방식, 검색/검색 결과 없음, 책 정보, 저장 세 상태/중복 안내, 독서카드 앞/뒤/기록 없음, 기록 종류/이벤트 입력/문장/자유 기록/완독, 날짜 선택, 촬영, 갤러리.

입력과 화면 이동은 로컬 상태로 동작합니다. 검색 결과·날짜·사진은 시안용 데이터이며 서버 저장, 실제 카메라/OCR, 사진 접근, 이미지 다운로드는 연동하지 않았습니다. 앱 재시작 시 입력 데이터는 초기화됩니다. 촬영과 갤러리 화면도 디자인 검토 대상입니다.

## 검증

```sh
flutter analyze lib/design_preview test/design_preview
flutter test test/design_preview
```

위 명령은 프로젝트 루트에서 실행합니다. 402×874 및 320×740 크기에서 A/C의 모든 화면을 렌더링하고 컬렉션 진입, 저장 상태 선택을 확인합니다. 리소스 출처와 라이선스는 `assets/design_preview/RESOURCES.md` 및 `covers/sources.json`에 기록되어 있습니다.

## 라운드와 밀도 개선

버튼/입력칸 8px, 독서카드 12px, 바텀시트 상단 18px로 모서리를 다듬었습니다. 반복하던 27권의 샘플은 서로 다른 9권으로 교체해 책등 높이·폭·색을 달리하고 제목을 키웠습니다. 컬렉션 이유는 표지 아래의 옅은 색상 주석으로 바꾸고, C 하단 내비게이션은 어두운 배경에 작은 라임 포인트만 사용합니다. 기록 내용/선택 항목/입력 라벨의 가독성을 높이고 A 카드의 빈 공간을 조정했습니다.

갤러리는 `tools/design_gallery/index.template.html`에서 생성합니다. `python3 scripts/build_design_gallery.py`로 이미지를 다시 캡처하지 않고 웹페이지를 갱신할 수 있습니다.
