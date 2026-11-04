abstract final class Env {
  static const kakaoAppKey = String.fromEnvironment('KAKAO_APP_KEY');
  static const naverClientId = String.fromEnvironment('NAVER_CLIENT_ID');
  static const naverClientSecret = String.fromEnvironment(
    'NAVER_CLIENT_SECRET',
  );
  static const googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
  static const baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://moabook.shop',
  );
  static const catalogSearchPath = String.fromEnvironment('YES24_SEARCH_PATH');
  static const catalogDetailPath = String.fromEnvironment('YES24_DETAIL_PATH');
  static const useNewReadingUi = bool.fromEnvironment(
    'USE_NEW_READING_UI',
    defaultValue: true,
  );
  static const readingShelfPath = String.fromEnvironment(
    'READING_SHELF_PATH',
    defaultValue: '/mybooks/store',
  );
  static const readingPageSizeKey = String.fromEnvironment(
    'READING_PAGE_SIZE_KEY',
    defaultValue: 'limit',
  );
}
