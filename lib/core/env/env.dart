abstract final class Env {
  static const kakaoAppKey =
      String.fromEnvironment('KAKAO_APP_KEY');
  static const naverClientId =
      String.fromEnvironment('NAVER_CLIENT_ID');
  static const naverClientSecret =
      String.fromEnvironment('NAVER_CLIENT_SECRET');
  static const googleClientId =
      String.fromEnvironment('GOOGLE_CLIENT_ID');
  static const baseUrl =
      String.fromEnvironment('BASE_URL', defaultValue: 'https://moabook.shop');
}
