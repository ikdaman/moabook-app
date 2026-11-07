# Android 실기기 검증 — 2026-11-07~08

연결된 Galaxy A52s(SM-A528N), Android 14, 1080×2400, 밀도 450에서 실행했다. 앱은 2.0.21(56) Debug이며 기존 `env/prod.json`의 개발 서버 `https://moabook.shop`을 사용했다. 인증은 사용자 검증을 재사용했다. 기존 서가 2권과 기록은 수정하지 않았으며 별도 테스트 책 10권과 컬렉션으로 검증했다.

## 이번에 수정한 항목

- **무한 스크롤:** 정상 상태의 ‘더 불러오기’를 제거했다. 하단 320dp 이내에서 다음 페이지를 요청하며 동시 요청, 마지막 페이지, 짧은 페이지, 검색어 변경과 늦은 응답을 처리한다. 실패하면 기존 결과와 같은 페이지의 재시도 버튼을 유지한다.
- **앱 글자 크기 고정(최종 사용자 선택):** 시스템 폰트 배율을 앱 전체에서 적용하지 않고 각 화면이 정한 폰트 크기를 유지한다. 키보드 영역과 Safe Area 정보는 보존한다.
- **글자 배치 보완:** 책등 제목은 추가 행간 없이 한 문단으로 세로 배치하고 원문의 띄어쓰기를 유지한다. 첫 글자·마지막 글자의 실제 폰트 높이까지 재서 잘림을 막으며, 공간을 넘는 제목만 말줄임한다. 하단 탭과 기록 추가 버튼 크기를 글씨에 맞추고, 카드의 기록 개수와 추가 동작은 좁으면 줄바꿈한다. 이 배치 보완은 개별 UI 부품에도 남겼으며, 실제 앱은 위의 고정 배율 규칙을 사용한다.
- **세로 고정:** Flutter 시작 설정, Android MainActivity, iOS 방향 설정에 반영했다. iOS는 plist 구조만 확인했으며 실제 빌드·기기 검증 결과는 아니다.

무한 스크롤은 기기에서 `1984` 검색 결과 **244/244권**, 요청 페이지 **1~5**와 마지막 페이지의 요청 종료를 확인했다. 화면 (`output/device-qa/2026-11-07/47-infinite-search-total-count.png`) · 요청 주소 (`output/device-qa/2026-11-07/infinite-scroll-requests.txt`).

폰트 고정 정책을 선택하기 전에는 1.5배와 2배에서 개별 부품의 배치를 확인했다. 아래 큰 글씨 캡처는 이 보완 과정의 증거이며 최종 앱의 폰트 정책은 시스템 배율 미반영이다. 가로 회전을 강제해도 새 빌드는 1080×2400 세로를 유지했다. 1.5배 책등 (`output/device-qa/2026-11-07/55-fixed-shelf-font-1_5.png`) · 2배 책등 (`output/device-qa/2026-11-07/57-fixed-shelf-font-2_0.png`) · 세로 고정 (`output/device-qa/2026-11-07/58-fixed-portrait-rotation.png`). 카드의 2배 글씨에서 추가로 발견한 겹침도 수정했다. 수정 전 (`output/device-qa/2026-11-07/70-card-font-2_0.png`) · 수정 후 (`output/device-qa/2026-11-07/71-fixed-card-font-2_0.png`) · 2배 글씨에서 기록 추가 진입 (`output/device-qa/2026-11-07/72-fixed-record-options-font-2_0.png`).

## 통과한 실기기·서버 시나리오

| 항목 | 확인한 결과 | 증거 |
| --- | --- | --- |
| 기존 데이터 | 이유 없는 책과 이유 있는 책 모두 표시, 기존 두 책의 기록은 0개 | 빈 카드 (`output/device-qa/2026-11-07/03-existing-empty-card.png`) |
| 제목 검색·상세 | 표지·저자·출판사·444쪽·출간일 표시 | 검색 (`output/device-qa/2026-11-07/06-search-results-keyboard.png`), 상세 (`output/device-qa/2026-11-07/07-book-info.png`) |
| 저장·키보드 | 400자 입력 제한, 399자 이유 저장, 저장 버튼 접근 가능 | 입력 제한 (`output/device-qa/2026-11-07/10-save-reason-limit.png`) |
| 책과 기록 분리 | 새 책 저장 직후 기록 0개, 첫 기록은 명시적으로 추가할 때만 생성 | 새 책의 빈 카드 (`output/device-qa/2026-11-07/11-qa-book-empty-card.png`) |
| 이유 생략 | 기존 사용자 저장 책의 `reason=null` 확인. 테스트 책 9권도 이유를 생략한 API 요청으로 저장 성공 | 기존 빈 카드 (`output/device-qa/2026-11-07/03-existing-empty-card.png`) |
| 기록 14종 | 14종 모두 실제 UI로 저장, 서버 목록에서 종류 14개·총 14개 확인 | 응답 (`output/device-qa/2026-11-07/record-verification.json`) |
| FREE 검증 | 빈 값·공백만 입력하면 완료 불가, 내용 입력 후 정상 저장 | 빈 입력 (`output/device-qa/2026-11-07/13-free-empty.png`), 저장 완료 (`output/device-qa/2026-11-07/14-free-saved.png`) |
| 과거 날짜·상태 | 완독 이후 과거 날짜 INPROGRESS를 추가하면 현재 상태는 읽는 중, 목록은 날짜 내림차순 | 목록 (`output/device-qa/2026-11-07/18-backdated-timeline.png`), 앞면 (`output/device-qa/2026-11-07/20-card-front-long-reason.png`) |
| 비상태 기록 | 구매 기록을 추가해도 현재 읽는 상태 유지 | 구매 후 앞면 (`output/device-qa/2026-11-07/21-purchase-preserves-status.png`) |
| 같은 날짜 상태 | 같은 날짜 DONE→INPROGRESS를 API로 추가해 마지막 성공 상태 반영 확인 | 응답 (`output/device-qa/2026-11-07/status-reason-verification.json`) |
| 빈 TODO | 내용 없는 ‘읽고 싶은 책’ 기록 저장 성공, 기존 이유 제거 | 14종 응답의 TODO (`output/device-qa/2026-11-07/record-verification.json`) |
| 날짜 변환 | UI 11/8 기록이 UTC 11/7 15:00으로 전송되고 다시 11/8로 표시 | 저장 완료 (`output/device-qa/2026-11-07/14-free-saved.png`) |
| 컬렉션 생성 | 빈 이름은 생성 불가, 이름 입력 후 서버 ID와 빈 9칸 표시 | 생성 화면 (`output/device-qa/2026-11-07/25-collection-create-empty.png`), 생성 후 (`output/device-qa/2026-11-07/27-collection-empty.png`) |
| 빈 이미지 저장 | 빈 컬렉션은 ‘저장할 책이 없어요’ 안내 | 안내 (`output/device-qa/2026-11-07/28-empty-export-notice.png`) |
| 기존 책 담기 | 저장된 책은 새 책 저장 시트 없이 컬렉션에 연결 | 한 권 담기 (`output/device-qa/2026-11-07/30-collection-one-book.png`) |
| 중간 칸 제거·채우기 | 2번 칸만 제거, 3·4번 위치와 원래 서가 책 유지. 다시 추가하면 첫 빈 칸 사용 | 빈 칸 (`output/device-qa/2026-11-07/35-collection-middle-gap.png`), 다시 채운 칸 (`output/device-qa/2026-11-07/37-refilled-gap.png`) |
| 중복·9칸 제한 | UI 중복 안내, API 중복 409, 10번 칸 요청 400. 실패 후 기존 9칸 보존 | 중복 화면 (`output/device-qa/2026-11-07/39-collection-duplicate.png`), 검증 응답 (`output/device-qa/2026-11-07/collection-limit-verification.json`) |
| 긴 컬렉션 이름 | 서버가 허용하는 50자 이름 저장, 제목은 두 줄 말줄임, 그리드는 스크롤 가능 | 큰 글씨와 긴 제목 (`output/device-qa/2026-11-07/56-fixed-collection-font-1_5.png`) |
| 사진 저장 | 1·4·9권이 각각 1080×812 / 1080×1266 / 1080×1720 PNG로 실제 사진 보관함에 저장 | 파일 크기 (`output/device-qa/2026-11-07/gallery-verification.json`) |
| 사진 열기 | 저장 PNG를 Samsung 갤러리에서 직접 열기 성공 | 갤러리 (`output/device-qa/2026-11-07/43-native-gallery-open.png`) |
| 여러 장 저장 | 서가 12권을 2장으로 저장. 마지막 장 미리보기와 2장 저장 완료 확인 | 마지막 미리보기 (`output/device-qa/2026-11-07/66-export-last-preview.png`), 완료 (`output/device-qa/2026-11-07/67-export-multiple-saved.png`) |
| 재시작 | 강제 종료 후 서가·컬렉션·기록 재조회 성공 | 재시작 후 9권 컬렉션 (`output/device-qa/2026-11-07/41-collection-nine.png`) |
| 오프라인·복구 | Wi-Fi/데이터 차단 시 오류와 재시도 표시, 복구 후 같은 12권 조회 | 오류 (`output/device-qa/2026-11-07/53-network-offline-error.png`), 복구 (`output/device-qa/2026-11-07/54-network-recovered.png`) |
| 카메라 권한 | 거부 시 안내, 권한 복구 후 재진입 성공 | 거부 (`output/device-qa/2026-11-07/60-camera-permission-denied.png`), 복구 (`output/device-qa/2026-11-07/61-camera-restored.png`) |
| 토치·생명주기 | 토치 켜짐, 홈 이동 후 복귀 시 토치 꺼짐·카메라 재연결. 화면 종료 후 활성 카메라 클라이언트 없음 | 토치 (`output/device-qa/2026-11-07/62-camera-torch-on.png`), 복귀 (`output/device-qa/2026-11-07/63-camera-resumed.png`) |

## 남은 문제

### 1. 과거 TODO가 최신 날짜 이유를 덮어씀 — 서버

11/8 TODO `QA_latest_reason`을 저장한 뒤 11/4 TODO `QA_older_reason`을 추가하자 카드 이유가 `QA_older_reason`으로 바뀌었다. 현재 상태를 마지막 추가 기록으로 결정하는 규칙은 정상이나, 이유의 날짜 우선 규칙과는 다르다. 재현 응답 (`output/device-qa/2026-11-07/status-reason-verification.json`).

확인한 [서버 서비스](https://github.com/ikdaman/damda-server/blob/a0f8c174819bd7780feb1efce119e6e3385211c3/src/main/java/com/damda/domain/mybook/service/MyBookServiceImpl.java)는 TODO 추가 시 날짜 비교 없이 `myBook.updateReason(recordReq.getMemo())`를 호출한다. 이유는 TODO 날짜를 기준으로 결정하도록 서버 수정이 필요하다.

### 2. 일부 검색어에서 외부 API 오류 500 — 서버 확인 필요

`GET /books?query=QAzzNoSuchBook938472&page=1&pageSize=50` 및 숫자 임의 검색어에서 HTTP 500, `5000005`가 재현됐다. 앱은 오류와 재시도 화면을 표시했다. 명세의 결과 없음 `200/null` 처리와 외부 API 오류 구분을 확인해야 한다. 외부 서버가 실제로 어떤 상태·본문을 반환했는지는 확인하지 않았다. 응답 (`output/device-qa/2026-11-07/search-negative.json`).

### 3. 설정·사진 저장 화면의 디자인 차이 — 앱

설정은 이전 픽셀 글꼴과 ‘읽고 싶은 책 / 책 추가 / 히스토리’ 하단 메뉴가 남아 있다. ‘히스토리’ 경로는 현재 컬렉션으로 연결되므로 이름도 새 구조에 맞춰야 한다. 사진 저장은 기본 Material 상단바와 보라색 둥근 버튼을 사용한다. 본문 서가의 색·글꼴·직각 버튼과 통일이 필요하다. 설정 (`output/device-qa/2026-11-07/64-settings.png`), 사진 저장 (`output/device-qa/2026-11-07/31-export-one-preview.png`).

### 4. 추가 계약 차이 — 서버·명세

- 서가는 `limit=100`을 무시하고 기본 5권씩 반환한다. `size=100`은 적용된다. 앱은 모든 페이지를 읽으므로 이번 12권 조회에 누락은 없었으나 기본 파라미터를 `size`로 정리할 필요가 있다.
- 같은 날짜 기록의 상대 순서는 안정적이지 않았다. 확인한 서버 정렬은 `recordDate DESC`만 사용한다. 날짜가 같을 때 생성 시각·ID 등 보조 정렬 기준을 확정해야 한다. 현재 상태는 별도 카드 응답을 사용하므로 이 순서에서 추측하지 않는다.

## 정리와 검증 범위

테스트 책 354~363은 서가에서 제거했다. 기존 두 책과 이유·기록은 검증 시작 전 응답과 동일함을 비교했다. 컬렉션 삭제 API가 없어 **`QA_1108_device`(ID 1) 한 개를 빈 상태로 남겼다.** 테스트로 저장한 사진 5장은 기기에서 정리하고 원본 PNG는 아래 산출물 폴더에 보관했다. 데이터 정리 결과 (`output/device-qa/2026-11-07/cleanup-verification.json`).

폰트 배율 1.1, 자동 회전·사용자 회전 값, Wi-Fi·모바일 데이터, 카메라 권한은 원래 상태로 복구했다. 앱은 새 세로 고정 설정을 유지한다.

인증·계정 전환, 푸시 실제 수신, iOS 빌드·기기 검증은 이번 범위에서 제외했다. 실제 책을 카메라 앞에 제시하는 물리적 바코드 인식은 앞선 사용자 성공 확인을 재사용했으며, 이번 자동 조작에서는 카메라·권한·토치·복귀까지만 새로 확인했다. 저장 공간 부족·사진 저장 중간 실패·응답 유실·다른 기기와의 동시 수정은 실기기에서 강제 재현하지 않았으며 기존 주입 테스트와 구분한다.

계정 정보가 포함될 수 있는 캡처와 실서버 응답 원본은 공개 저장소에서 제외하고 로컬에만 보관한다. 산출물은 산출물 폴더 (`output/device-qa/2026-11-07/`)에 있다. 이 폴더에는 인증 토큰을 저장하지 않았다.

## 최종 검증·설치

- `flutter test --no-pub --reporter expanded`: **169개 통과**. 무한 스크롤과 1.5/2배 글씨의 좁은 화면·빈 카드·기록 추가 동작 회귀 테스트를 포함한다.
- `flutter analyze --no-pub`: 문제 없음. 변경 파일의 `git diff --check` 통과.
- `plutil -lint ios/Runner/Info.plist`와 Android/iOS 세로 방향 설정 구조 확인 통과.
- `flutter build apk --debug --target-platform android-arm64 --dart-define-from-file=env/prod.json`: 성공. 연결 기기에 `adb install --no-streaming -r`로 업데이트하고 실행했다.
- 배율 대응 보완 빌드에서 2배 글씨 카드의 기록 개수·첫 기록 버튼과 카테고리 시트 진입을 확인했다. 최종 빌드는 앱 폰트 크기를 고정하는 사용자 선택을 추가로 반영한다. 해당 새 프로세스의 렌더링 오류 로그는 0개다. 로그 결과 (`output/device-qa/2026-11-07/final-layout-errors.json`).
- 앱을 원래 두 권이 보이는 기본 서가로 돌려놓았다. 최종 화면 (`output/device-qa/2026-11-07/73-final-shelf.png`).

자동 검증 요약 (`output/device-qa/2026-11-07/validation-summary.txt`) · 설치 APK 식별 정보 (`output/device-qa/2026-11-07/build-info.json`)

### 최종 폰트 고정 정책 실기기 확인

최종 사용자 선택에 따라 앱 전체의 시스템 폰트 배율을 미반영한다. 각 화면에 지정한 글자 크기 자체를 하나로 통일하는 것이 아니라, 제목·본문 등 디자인별 크기를 그대로 유지한다. 시스템 배율 0.8과 2.0에서 서가 제목·권수·책 추가·하단 탭 및 카드의 기록 개수·첫 기록 버튼의 화면 좌표가 모두 동일함을 비교했다. 폰의 원래 배율 1.1로 복구한 뒤에도 앱은 고정 크기를 사용한다.

- 서가: 시스템 0.8 (`output/device-qa/2026-11-07/75-fixed-font-system-0_8-shelf.png`) · 시스템 2.0 (`output/device-qa/2026-11-07/76-fixed-font-system-2_0-shelf.png`)
- 카드: 시스템 0.8 (`output/device-qa/2026-11-07/77-fixed-font-system-0_8-card.png`) · 시스템 2.0 (`output/device-qa/2026-11-07/78-fixed-font-system-2_0-card.png`)
- 좌표 비교 결과 (`output/device-qa/2026-11-07/fixed-font-geometry.json`): `sameGeometry=true`. 새 프로세스 렌더링 오류 0개.
- 자동 테스트는 0.8/1.0/1.5/2.0에서 실제 텍스트 크기가 같고 키보드 inset·Safe Area가 보존됨을 확인한다. 전체 169개 통과, 정적 분석 문제 없음.

## 책등 세로 조판 후속

글자마다 추가했던 행간과 여백을 제거하고 한 문단으로 촘촘하게 배치했다. 원문 띄어쓰기는 빈 칸으로 보존한다. 첫 줄·마지막 줄의 폰트 높이는 잘리지 않게 측정하며, 공간을 넘는 제목만 말줄임한다. 시스템 폰트 배율 미반영과 세로 고정은 유지한다. 전체 Flutter 테스트 169개 및 정적 분석 통과 후 Android 기기에 설치·실행했다. 최종 로컬 캡처: `output/device-qa/2026-11-07/80-compact-spine-word-spaces.png`.
