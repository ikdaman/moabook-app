# 표지 크롭 재-OCR 구현 플랜

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** OCR 인식 실패 시 사용자가 이미지에서 제목/표지 영역을 직접 크롭 → 재-OCR → 기존 검색 파이프라인으로 재검색하는 기능을 `CoverOcrLabScreen`에 추가한다.

**Architecture:** 순수 크롭 화면(`CoverCropScreen`)이 이미지 bytes를 받아 크롭본 bytes를 반환한다. lab 화면은 반환 bytes를 임시 파일로 저장한 뒤 기존 OCR/검색 로직(`recognizeBookCover` → `buildOcrQueries` → 알라딘)을 그대로 재호출한다. OCR/검색 코드는 건드리지 않는다.

**Tech Stack:** Flutter, Riverpod, `crop_your_image ^2.0.0`, `path_provider`, `image_picker`(기존), `google_mlkit_text_recognition`(기존).

## Global Constraints

- 스코프는 `CoverOcrLabScreen` 한정. 프로덕션 결과화면/바코드 플로우는 건드리지 않는다.
- `book_cover_ocr.dart`, `cover_ocr_search.dart`는 **변경 금지** (재사용만).
- 크롭 임시 파일은 `try/finally`로 항상 삭제.
- 패키지명 import prefix: `package:moabook/...`.
- 커밋 메시지 끝에 `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- crop_your_image 2.0.0 API: `Crop(image: Uint8List, controller: CropController, onCropped: (CropResult))`, `CropController.crop()` 트리거, `CropResult`는 sealed — `CropSuccess(croppedImage: Uint8List)` / `CropFailure(cause)`.

---

### Task 1: 의존성 추가

**Files:**
- Modify: `pubspec.yaml`

**Interfaces:**
- Consumes: 없음
- Produces: `crop_your_image`, `path_provider` 패키지가 프로젝트에서 import 가능.

- [ ] **Step 1: pubspec.yaml에 의존성 추가**

`dependencies:` 블록에서 `image_picker: ^1.2.3` 아래에 두 줄 추가:

```yaml
  image_picker: ^1.2.3
  crop_your_image: ^2.0.0
  path_provider: ^2.1.4
```

- [ ] **Step 2: pub get 실행**

Run: `flutter pub get`
Expected: `Got dependencies!` (에러 없이 종료)

- [ ] **Step 3: 커밋**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore(cover-ocr): 크롭 재-OCR용 의존성 추가 (crop_your_image, path_provider)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: 크롭 화면 (CoverCropScreen)

이미지 bytes를 받아 Crop UI를 표시하고, 확인 시 크롭본 bytes를 `Navigator.pop`으로 반환하는 순수 화면. OCR·검색·파일 로직 없음.

**Files:**
- Create: `lib/features/cover_ocr/screen/cover_crop_screen.dart`
- Test: `test/features/cover_ocr/cover_crop_screen_test.dart`

**Interfaces:**
- Consumes: `crop_your_image`의 `Crop`, `CropController`, `CropResult`(`CropSuccess`/`CropFailure`).
- Produces:
  - `class CoverCropScreen extends StatefulWidget` — 생성자 `const CoverCropScreen({super.key, required this.imageBytes})`, 필드 `final Uint8List imageBytes;`
  - 확인 완료 시 `Navigator.pop<Uint8List>(context, croppedBytes)`.
  - 취소(앱바 뒤로) 시 pop 결과 없음(null).

- [ ] **Step 1: 위젯 스모크 테스트 작성 (실패 확인용)**

`test/features/cover_ocr/cover_crop_screen_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/features/cover_ocr/screen/cover_crop_screen.dart';

// 1x1 투명 PNG (crop_your_image가 디코드 가능한 유효 이미지)
final _pngBytes = Uint8List.fromList(base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M8AAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
));

void main() {
  testWidgets('CoverCropScreen — 렌더 + 확인 버튼 노출', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: CoverCropScreen(imageBytes: _pngBytes)),
    );
    await tester.pump();

    expect(find.text('영역 선택'), findsOneWidget);
    expect(find.byKey(const Key('crop_confirm_button')), findsOneWidget);
  });
}
```

- [ ] **Step 2: 테스트 실행해 실패 확인**

Run: `flutter test test/features/cover_ocr/cover_crop_screen_test.dart`
Expected: FAIL — `cover_crop_screen.dart` 없음 / `CoverCropScreen` 미정의.

- [ ] **Step 3: CoverCropScreen 구현**

`lib/features/cover_ocr/screen/cover_crop_screen.dart`:

```dart
// 표지 이미지에서 제목/표지 영역을 직접 크롭하는 화면.
//
// 입력: 이미지 bytes. 출력: Navigator.pop<Uint8List>(크롭본 bytes).
// OCR·검색·파일 저장은 호출자(lab 화면)가 담당 — 이 화면은 순수 크롭만.

import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';

class CoverCropScreen extends StatefulWidget {
  const CoverCropScreen({super.key, required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<CoverCropScreen> createState() => _CoverCropScreenState();
}

class _CoverCropScreenState extends State<CoverCropScreen> {
  final _controller = CropController();
  bool _cropping = false;

  void _onCropped(CropResult result) {
    if (!mounted) return;
    switch (result) {
      case CropSuccess(:final croppedImage):
        Navigator.of(context).pop<Uint8List>(croppedImage);
      case CropFailure():
        setState(() => _cropping = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('크롭에 실패했어요. 다시 시도해 주세요.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDefault,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDefault,
        title: Text(
          '영역 선택',
          style: AppTypography.dungGeunMoHeader
              .copyWith(color: AppColors.textPrimary),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Crop(
              image: widget.imageBytes,
              controller: _controller,
              onCropped: _onCropped,
              interactive: true,
              baseColor: AppColors.backgroundDefault,
              maskColor: Colors.black.withValues(alpha: 0.5),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('crop_confirm_button'),
                  onPressed: _cropping
                      ? null
                      : () {
                          setState(() => _cropping = true);
                          _controller.crop();
                        },
                  child: Text(_cropping ? '처리 중...' : '이 영역으로 검색'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 테스트 실행해 통과 확인**

Run: `flutter test test/features/cover_ocr/cover_crop_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: analyze 확인**

Run: `flutter analyze lib/features/cover_ocr/screen/cover_crop_screen.dart`
Expected: `No issues found!`

- [ ] **Step 6: 커밋**

```bash
git add lib/features/cover_ocr/screen/cover_crop_screen.dart test/features/cover_ocr/cover_crop_screen_test.dart
git commit -m "feat(cover-ocr): 표지 영역 크롭 화면 CoverCropScreen 추가

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: lab 화면 OCR 파이프라인 추출 (리팩터, 동작 변화 없음)

`_pick`의 "경로 → OCR → 검색 → 상태갱신" 부분을 `_runOcrPipeline(String path)`로 추출해 크롭 플로우가 재사용할 수 있게 한다. 기존 촬영/갤러리 동작은 그대로.

**Files:**
- Modify: `lib/features/cover_ocr/screen/cover_ocr_lab_screen.dart:40-90` (`_pick` 메서드)

**Interfaces:**
- Consumes: 기존 `recognizeBookCover`, `_searchTopCandidates`.
- Produces: `Future<void> _runOcrPipeline(String path)` — 주어진 이미지 경로로 OCR+검색 실행하고 `_candidates`/`_results`/`_error`/타이밍/`_running` 상태를 갱신. Task 4가 크롭본 임시경로로 호출.

- [ ] **Step 1: _pick을 _runOcrPipeline 호출로 분리**

`cover_ocr_lab_screen.dart`의 기존 `_pick` 메서드(현재 40~90행) 전체를 아래로 교체:

```dart
  Future<void> _pick(ImageSource source) async {
    final file = await _picker.pickImage(source: source, imageQuality: 90);
    if (file == null) return;
    await _runOcrPipeline(file.path);
  }

  /// 주어진 이미지 경로로 OCR + 알라딘 검색을 돌리고 화면 상태를 갱신한다.
  /// 촬영/갤러리 픽과 크롭본(임시파일)이 공유한다.
  Future<void> _runOcrPipeline(String path) async {
    setState(() {
      _imagePath = path;
      _candidates = [];
      _results = [];
      _error = null;
      _ocrElapsed = null;
      _searchElapsed = null;
      _running = true;
    });

    try {
      final ocrWatch = Stopwatch()..start();
      final candidates = await recognizeBookCover(path);
      ocrWatch.stop();

      if (!mounted) return;
      setState(() {
        _candidates = candidates;
        _ocrElapsed = ocrWatch.elapsed;
      });

      if (candidates.isEmpty) {
        setState(() {
          _error = '텍스트를 인식하지 못했어요.';
          _running = false;
        });
        return;
      }

      final searchWatch = Stopwatch()..start();
      final results = await _searchTopCandidates(candidates);
      searchWatch.stop();

      if (!mounted) return;
      setState(() {
        _results = results;
        _searchElapsed = searchWatch.elapsed;
        _running = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '실패: $e';
        _running = false;
      });
    }
  }
```

- [ ] **Step 2: analyze 확인**

Run: `flutter analyze lib/features/cover_ocr/screen/cover_ocr_lab_screen.dart`
Expected: `No issues found!`

- [ ] **Step 3: 기존 테스트 회귀 확인**

Run: `flutter test test/features/cover_ocr/`
Expected: 전부 PASS (검색 로직 테스트 회귀 없음).

- [ ] **Step 4: 커밋**

```bash
git add lib/features/cover_ocr/screen/cover_ocr_lab_screen.dart
git commit -m "refactor(cover-ocr): lab OCR 파이프라인을 _runOcrPipeline로 추출

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: 크롭 진입 + 크롭본 재-OCR 연결

lab 화면에 "영역 직접 선택" 버튼을 추가한다. 현재 이미지 파일을 bytes로 읽어 `CoverCropScreen`을 띄우고, 반환된 크롭본 bytes를 임시 jpg로 저장한 뒤 `_runOcrPipeline`으로 재검색한다.

**Files:**
- Modify: `lib/features/cover_ocr/screen/cover_ocr_lab_screen.dart` (import 추가, `_cropAndReSearch` 메서드 추가, build의 버튼 영역)

**Interfaces:**
- Consumes: Task 2의 `CoverCropScreen(imageBytes:)` → `Navigator.push<Uint8List>`; Task 3의 `_runOcrPipeline(String path)`; `path_provider`의 `getTemporaryDirectory()`.
- Produces: 없음 (기능 완결).

- [ ] **Step 1: import 추가**

`cover_ocr_lab_screen.dart` 상단 import 블록에 추가 (기존 `import 'dart:io';` 아래, 그리고 화면 import 근처):

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
```

그리고 화면 import 그룹에 추가:

```dart
import 'cover_crop_screen.dart';
```

- [ ] **Step 2: _cropAndReSearch 메서드 추가**

`_runOcrPipeline` 메서드 바로 아래에 추가:

```dart
  /// 현재 선택된 이미지를 크롭 화면으로 넘겨 영역을 고르게 하고,
  /// 크롭본을 임시 파일로 저장해 재-OCR + 재검색한다.
  Future<void> _cropAndReSearch() async {
    final path = _imagePath;
    if (path == null) return;

    final bytes = await File(path).readAsBytes();
    if (!mounted) return;

    final cropped = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => CoverCropScreen(imageBytes: bytes),
      ),
    );
    if (cropped == null || !mounted) return;

    final dir = await getTemporaryDirectory();
    final tmp = File(
      '${dir.path}/cover_crop_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    try {
      await tmp.writeAsBytes(cropped);
      await _runOcrPipeline(tmp.path);
    } finally {
      if (await tmp.exists()) {
        await tmp.delete();
      }
    }
  }
```

- [ ] **Step 3: "영역 직접 선택" 버튼 추가**

build 메서드에서 이미지 미리보기(`if (_imagePath != null) ClipRRect(...)`) 블록 **바로 아래**에 추가:

```dart
          if (_imagePath != null) ...[
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: _running ? null : _cropAndReSearch,
              icon: const Icon(Icons.crop),
              label: const Text('영역 직접 선택'),
            ),
          ],
```

- [ ] **Step 4: analyze 확인**

Run: `flutter analyze lib/features/cover_ocr/`
Expected: `No issues found!`

- [ ] **Step 5: 전체 cover_ocr 테스트 확인**

Run: `flutter test test/features/cover_ocr/`
Expected: 전부 PASS.

- [ ] **Step 6: 커밋**

```bash
git add lib/features/cover_ocr/screen/cover_ocr_lab_screen.dart
git commit -m "feat(cover-ocr): lab에 영역 직접 크롭 → 재-OCR 재검색 연결

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: 기기 수동 검증

실기기에서 인식 실패 케이스가 크롭으로 개선되는지 확인. (ML Kit는 기기 전용이라 자동 테스트 불가.)

**Files:** 없음 (검증만)

- [ ] **Step 1: 기기에 앱 실행**

Run: `flutter run -d <android-device-id> --debug`
Expected: 앱 실행, 홈 진입.

- [ ] **Step 2: lab 화면 진입**

- 홈 우상단 기어 → 설정. (임시 진입 메뉴가 없다면 이전 세션의 `🔬 표지 OCR 실험` 임시 메뉴를 설정 화면에 다시 넣거나, 라우트 `Routes.coverOcrLab`로 직접 이동.)
- `표지 OCR 실험` 진입.

- [ ] **Step 3: 크롭 재-OCR 검증**

- `갤러리` → 인식 실패 이미지 선택 (`눈물을 마시는 새`/`제자리에 있다는 것`/`프로젝트 헤일메리` 중 하나).
- 1차 OCR 결과(부실) 확인.
- `영역 직접 선택` → 제목 부분만 크롭 → `이 영역으로 검색`.
- 재-OCR 후보/검색 결과가 개선(정답 등장/상승)되는지 확인.

Expected: 최소 1개 실패 케이스에서 크롭 후 제목 후보/검색 결과가 개선. 개선 없으면 원인(크롭 후에도 인식 깨짐 등) 기록 후 후속 논의.

---

## 참고: 임시 진입 메뉴

lab 화면은 아직 프로덕션 UI 진입점이 없다(라우트만 존재). 검증용으로 설정 화면에 임시 메뉴가 필요하면 `settings_screen.dart`의 회원탈퇴 아래에:

```dart
              const SizedBox(height: 4),
              // TEMP: 표지 OCR 실험 진입 (검증 후 제거)
              _MenuItem(
                text: '🔬 표지 OCR 실험',
                onTap: () => context.push(Routes.coverOcrLab),
              ),
```

이 임시 메뉴는 커밋하지 않는다.
