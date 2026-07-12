# 표지 크롭 재-OCR 설계

**날짜**: 2026-07-13
**대상**: 표지 OCR 실험화면(`CoverOcrLabScreen`)
**선행 작업**: `e773612` (top5 + 후보 정제 + 라운드로빈 병합)

## 배경 / 문제

실기기(Galaxy A52s, Android 14) ML Kit 검증 결과, 오버레이 자막·저자명 병합·광택·각도로 **인식 단계에서 깨지는** 케이스(img3 눈물을 마시는 새, img4 제자리에 있다는 것, img5 프로젝트 헤일메리)는 후처리(top5·정제·라운드로빈)로 못 고친다. 원인이 잘못된 텍스트 인식이라 쿼리 레벨 개선의 사정거리 밖.

사용자가 이미지에서 **제목/표지 영역만 직접 크롭**하면 오버레이·배경이 제거되어 ML Kit가 깨끗하게 읽는다. 알라딘은 이미지 검색이 없으므로 크롭 후 **재-OCR로 텍스트를 다시 뽑아** 기존 검색 파이프라인에 태운다.

## 스코프

**포함**:
- `CoverOcrLabScreen`에 크롭 진입 버튼 + 크롭 화면 + 재-OCR·재검색.

**제외 (YAGNI)**:
- 프로덕션 결과화면(`CoverOcrResultScreen`) / 바코드 플로우 이관 — lab 검증 후 별도 작업.
- 크롭 후 후보 수동 선택 — 자동 재검색으로 결정.
- 회전·확대 등 고급 편집.

## 의존성

- `crop_your_image: ^2.0.0` — 순수 Flutter 크롭 위젯. 네이티브 설정 불필요.
  - `Crop(image: Uint8List, controller: CropController, onCropped: (CropResult))`
  - `CropController.crop()` 트리거 → 결과는 `onCropped`로 도착.
  - `CropResult`는 sealed: `.success(croppedImage: Uint8List)` / `.error(error)`.
- `path_provider` — 크롭 bytes를 임시 파일로 저장. `recognizeBookCover`가 `InputImage.fromFilePath(path)` 파일경로 입력이라 필요.

## 플로우

```
촬영/갤러리(기존) → _imagePath 보관
  → [영역 직접 선택] 버튼(이미지 선택 시 항상 노출)
  → 크롭 화면: 이미지 bytes를 Crop 위젯에 로드
  → 사용자 영역 조정 → [확인] → controller.crop()
  → onCropped(CropResult.success: Uint8List croppedBytes)  ← 크롭 화면이 bytes 반환하고 pop
  → lab: 임시 jpg 저장(getTemporaryDirectory)
       → recognizeBookCover(임시경로)
       → buildOcrQueries → 알라딘 검색(기존 _searchTopCandidates 재사용)
       → 후보/결과 갱신
  → 임시 파일 정리(finally)
```

## 컴포넌트 (격리)

| 유닛 | 역할 | 인터페이스 | 의존 |
|------|------|-----------|------|
| `cover_crop_screen.dart` (신규) | 이미지 bytes를 받아 Crop UI 표시, 크롭본 bytes를 pop 결과로 반환 | 입력: `Uint8List imageBytes`. 출력: `Navigator.pop(Uint8List?)` (취소 시 null). OCR·검색·파일 로직 없음 | `crop_your_image` |
| `CoverOcrLabScreen` | 크롭 진입, 반환 bytes → 임시파일 → 기존 OCR/검색 파이프라인 재호출, 결과 갱신 | 기존 `_pick`/`_searchTopCandidates` 재사용 | `path_provider`, `image_picker` |
| `book_cover_ocr.dart` | **변경 없음** — 파일경로 입력 유지 | `recognizeBookCover(String path)` | ML Kit |
| `cover_ocr_search.dart` | **변경 없음** — `buildOcrQueries`/`mergeCoverSearchResults` 재사용 | — | 알라딘 |

경계 원칙: 크롭 화면은 "이미지 bytes → 크롭 bytes" 순수 변환만 안다. OCR·검색·임시파일은 lab 화면이 조율. 크롭 위젯 내부를 몰라도 소비 가능, 내부 바꿔도 소비자 안 깨짐.

## 에러 처리

- `CropResult.error` → 스낵바 안내, lab 상태 원복.
- 크롭 취소(뒤로가기) → 아무 동작 없음(null 반환).
- 크롭 후 재-OCR 텍스트 0건 → 기존 `_error = '텍스트를 인식하지 못했어요.'` 경로 재사용.
- 임시 파일은 `try/finally`로 항상 삭제(성공·실패 무관).

## 테스트

- **크롭 화면 위젯 스모크**: 이미지 bytes로 렌더 크래시 없음 + 확인 시 `onCropped` 콜백 경유 bytes 반환(가능 범위). ML Kit 미의존이라 위젯테스트 가능.
- **재-OCR 파이프라인**: `recognizeBookCover`는 ML Kit=기기 전용 → 유닛 불가. 기기 수동 검증(임시 배치 하네스 재활용).
- **검색 로직**: 기존 `cover_ocr_search_test.dart`가 이미 커버(`buildOcrQueries`, `mergeCoverSearchResults`).

## 수동 검증 계획

기기(Galaxy A52s)에서 인식 실패 3장(img3·4·5)을 갤러리로 불러와 → 제목 영역 크롭 → 재-OCR 후보/검색 결과가 개선되는지 `[OCRTEST]` 로깅 또는 화면 확인.
