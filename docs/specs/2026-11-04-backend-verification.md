# 백엔드 재확인 결과

확인일: 2026-11-04. 문서와 코드의 확인 결과이며, 인증 후 실제 저장 테스트나 배포 확인 결과는 아니다.

**사용자 합의 후 변경:** 아래의 최초 조사에서 지적한 날짜 우선 상태 계산은 더 이상 구현 기준이 아니다. 현재 상태는 기록 날짜와 무관하게 마지막으로 성공적으로 추가한 상태 기록을 따르기로 확정했다. 확인한 서버 `addRecord()`의 순차 처리 방향과 일치하므로 날짜 우선 계산 추가를 서버 요구 사항에서 제외한다. 기록 목록은 날짜 내림차순을 유지한다. 띠지의 이유 선택과 동시 요청 순서는 별도 확인 항목이다. 원본 Claude 정책서는 변경하지 않았다.

## 결론

API 문서만으로도 새 서가 조회, 기록 입력 형식, 컬렉션 9칸과 편집 방식은 확인된다. 그러나 처음 질문한 네 항목은 문서만으로 확정되지 않는다. 추가로 살펴본 서버 코드에는 일부 답과 정책 불일치가 있어, 이를 실제 배포 계약과 맞추는 일이 남았다.

삭제 폴더의 다섯 항목은 **개편 앱에서 미사용할 구 방식**으로 분류한다. 같은 주소를 쓰는 새 기능까지 삭제하는 뜻은 아니다. 서버가 이미 해당 경로를 중단했는지는 별도다.

## 확인 근거

- [Postman 문서](https://documenter.getpostman.com/view/43782154/2sBXcAH2xj)의 공개 컬렉션을 다시 내려받아 폴더·요청·응답·헤더를 확인했다. 문서 소개에는 여전히 목업 안내가 있다.
- 서버 저장소 `ikdaman/damda-server`의 `main`, 커밋 `49b6e82bb7e6ae56ca3f6fd9252795898fd2fbe4`를 읽었다. 아래 코드는 모두 이 버전 기준이다. 다른 브랜치나 배포 서버와 동일하다고 전제하지 않는다.
- 로컬 `../damda-server`는 7월 코드여서 이번 판정 근거로 사용하지 않았다. 원격의 고정 커밋을 별도로 읽었고 저장소를 변경하지 않았다.
- 앱의 datasource, 저장 provider, 상세 편집, 히스토리, 공유 확장의 호출 위치를 대조했다.
- 공개 문서에 포함된 인증 예제는 재사용하지 않았다. 서버 인증·생성·수정·삭제 요청은 수행하지 않았다.

## 네 가지 질문의 답

| 질문 | API 문서에서 확인 | 코드에서 추가 확인 | 최종 판단 |
| --- | --- | --- | --- |
| 저장된 책 ID는 어떻게 받는가? | 책 저장 성공 예제는 응답 본문·Location이 명시되지 않음 | 서비스는 ID가 든 결과를 만들지만 controller가 버리고 본문 없는 201 반환 | 클라이언트가 받을 ID 응답 계약 보완 필요 |
| 최초 기록은 누가 만드는가? | 기록 추가 API는 있으나 책 저장 시 자동 생성 설명 없음 | `addMyBook()`은 책만 저장하고 Record를 생성하지 않음. DTO·서비스는 문서에서 제거했다는 `historyInfo`도 아직 사용 | 선택한 상태·날짜로 첫 기록 정확히 1개를 만드는 저장 흐름 확정 필요 |
| 이미 있는 책을 어떻게 찾는가? | 목록의 keyword는 제목/저자 검색. 정확 식별·기존 책 ID를 반환하는 중복 응답 없음 | 책 저장 서비스에서 회원별 동일 책 중복 검사를 찾지 못함. 컬렉션 서비스에는 알라딘 ID로 기존 내 책을 찾는 처리가 있지만, 사전 확인 controller 경로는 없음 | 컬렉션 내부 처리를 서가 중복 조회 API처럼 사용할 수 없음. 정확 조회 또는 중복 응답 계약 필요 |
| 상태와 띠지는 어떻게 결정하는가? | 앞면에 상태·이유가 있으나 최신 기록/동률 계산 규칙 설명 없음 | 기록 추가 시 날짜 비교 없이 상태를 덮어쓰고, TODO면 이유를 덮어씀. 목록은 기록 날짜 내림차순만 지정 | 과거 기록을 나중에 추가하면 정책과 다른 상태가 될 수 있음. 최신 날짜와 같은 날짜 생성 순서 처리 필요 |

관련 소스: [책 controller](https://github.com/ikdaman/damda-server/blob/49b6e82bb7e6ae56ca3f6fd9252795898fd2fbe4/src/main/java/com/damda/domain/mybook/controller/MyBookController.java), [책·기록 service](https://github.com/ikdaman/damda-server/blob/49b6e82bb7e6ae56ca3f6fd9252795898fd2fbe4/src/main/java/com/damda/domain/mybook/service/MyBookServiceImpl.java), [기록 정렬](https://github.com/ikdaman/damda-server/blob/49b6e82bb7e6ae56ca3f6fd9252795898fd2fbe4/src/main/java/com/damda/domain/mybook/repository/RecordRepository.java).

## 삭제 폴더의 다섯 항목과 앱 대응

| 삭제 폴더 항목 | 현재 앱 호출 | 개편 시 대응 |
| --- | --- | --- |
| 나의 책 추가 — 직접 추가 (`POST /mybooks`, CUSTOM) | `book_search/provider/book_search_provider.dart`의 `saveManualBook`, 수동 등록 화면 | 직접 추가 진입과 CUSTOM 저장을 제외. 새 ALADIN 책 저장은 같은 POST 주소로 계속 사용 |
| 독서 시작 (`PATCH /mybooks/{id}/reading-status`) | `home/provider/home_provider.dart`의 `startReading` → datasource | INPROGRESS/DONE 기록 추가로 대체. 최초 저장의 기록 생성과는 별개로 구분 |
| 나의 책 정보 수정 (`PATCH /mybooks/{id}`) | `book_info/provider/book_info_provider.dart`의 `applyEdit` → datasource | 구 편집 호출 제거. 상태·이유는 새 기록으로 남김. 제목·저자 수정의 새 대체 API는 문서에 없음 |
| 히스토리 목록 (`GET /mybooks/history`) | `history/provider/history_provider.dart`의 `load/loadMore` → datasource | 전체 책은 새 서가, 한 책의 기록은 `/mybooks/{id}/records`로 구분 |
| [삭제]기본서가목록조회 (`GET /mybooks/53` 예제) | 구 중첩 응답을 읽는 `getMyBookDetail` | 경로 이름으로만 판단하지 않음. 최신 문서의 카드 앞면 GET도 `/mybooks/{id}`이므로 새 앞면 응답 파서로 교체 |

**삭제 API와 DELETE 메서드는 다르다.** 책 삭제 `DELETE /mybooks/{id}`는 MyBook 폴더에 남아 있다. 신규 기록 삭제 API도 존재하지만 이번 정책의 UI 범위에는 추가하지 않는다.

확인한 서버 main에는 예전 PATCH 두 개와 `/history`도 아직 존재한다. 이는 삭제 폴더와 모순되는 사용 권고가 아니라 구 버전 호환 코드일 수 있다. 따라서 **새 앱에서는 사용하지 않고**, 운영 서버의 실제 폐기 시점만 담당자 확인 항목으로 남긴다.

## 확인되어 바로 설계에 쓸 수 있는 내용

문서에서 확인:

- 기본 서가는 전체 상태의 책을 조회하며 키워드 없이 전체 목록을 요청한다.
- 기록은 14종, 날짜는 필수, memo는 최대 400자이며 FREE만 내용 필수다.
- 기록 목록은 현재 페이지 구분 없이 최신순 전체 조회다.
- 컬렉션은 9칸, 이름으로 생성, PUT은 이름과 최종 책 목록 전체 교체다. 컬렉션에서 빠져도 서가 책은 남는다.

코드에서 추가 확인, 배포 계약과 일치 여부는 아직 미확인:

- 기록 목록 controller는 최상위 배열을 반환한다. 문서 표의 `records` 객체 형태와 구분한다.
- 앞면 모델은 `myBookId`, `totalRecords`, `aladinId`를 포함한다. 문서 표의 `mybookId`와 철자가 다르다.
- `RecordRes.recordId`에 `@JsonIgnore`가 있어 목록 응답에서는 ID가 빠진다. ID가 포함된 문서 예제와 다르다.
- 컬렉션 목록은 오래된 생성순 → 최신순이다. 생성 응답은 문서의 요약 응답보다 상세한 9칸 상세 타입이다.
- 컬렉션 편집에는 9권 제한·같은 책 중복·슬롯 범위/중복·소유권 검사가 있으며, 지정 슬롯 보존과 생략 시 첫 빈 칸 배정이 구현되어 있다.
- 컬렉션 수정은 행 잠금을 사용한다. 다만 오래된 클라이언트의 최종 목록이 덮어쓰는 문제까지 막는 버전 충돌 계약은 확인되지 않았다.
- 컬렉션 서비스는 문서에 없는 신규 책 정보도 받아 기존 서가 책을 알라딘 ID로 재사용하거나 새로 저장할 수 있다. 문서가 확정되기 전 이 확장 기능을 앱 저장 경로로 채택하지 않는다.

관련 소스: [앞면 모델](https://github.com/ikdaman/damda-server/blob/49b6e82bb7e6ae56ca3f6fd9252795898fd2fbe4/src/main/java/com/damda/domain/mybook/model/MyBookDetailRes.java), [기록 응답](https://github.com/ikdaman/damda-server/blob/49b6e82bb7e6ae56ca3f6fd9252795898fd2fbe4/src/main/java/com/damda/domain/mybook/model/RecordRes.java), [컬렉션 controller](https://github.com/ikdaman/damda-server/blob/49b6e82bb7e6ae56ca3f6fd9252795898fd2fbe4/src/main/java/com/damda/domain/collection/controller/CollectionController.java), [컬렉션 service](https://github.com/ikdaman/damda-server/blob/49b6e82bb7e6ae56ca3f6fd9252795898fd2fbe4/src/main/java/com/damda/domain/collection/service/CollectionServiceImpl.java).

## 실제 서버에 적용하기 전 남은 확인

1. **저장 규칙:** 위 표의 ID 반환, 최초 기록, 정확 중복 조회를 실제 배포 계약에 맞추기. 상태는 사용자 합의로 마지막 추가한 상태 기록 우선이며, 날짜 우선 재계산은 요구하지 않는다. 띠지 이유 선택은 별도 확인한다.
2. **문서·코드 차이:** 목록 경로가 문서는 `/mybooks/store`, 코드 main은 `GET /mybooks`다. 문서의 `limit`과 코드의 Pageable(`size`, 기본 5)도 다르다. 코드의 키워드 쿼리는 제목만 검색하므로 문서의 저자 검색과 차이가 있다.
3. **응답 맞추기:** 앞면 ID 철자, 기록 목록 ID 포함 여부, 컬렉션 생성 응답, 기록 목록 배열을 최종 명세에 반영하기.
4. **배포 환경:** 실제 호출할 주소와 기준 브랜치, 구 API 종료 시점 확인.

연결 수준의 읽기 전용 점검에서는 이 환경에서 `api.ikdaman.shop`의 DNS 조회가 실패했다. 앱 기본 주소 `moabook.shop/mybooks/store`의 무인증 GET은 JSON 500을 반환했다. 이 결과로 신규 API의 배포 여부·인증 후 정상 동작·영구 장애를 판단할 수 없다. 인증 예제나 로컬 비밀정보를 꺼내 사업 동작을 임의 검증하지 않았다.

화면 수정, 입력 검증, 9슬롯 표시, 공통 컴포넌트 분리는 진행 가능하다. 실제 저장 연결은 위 계약을 확인한 뒤 진행한다. 담당자에게 질문을 전송하거나 서버 코드를 수정하지 않았다.
