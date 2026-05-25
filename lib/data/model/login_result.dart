class LoginResult {
  final String provider;
  final String authorization;
  final String refreshToken;
  final String nickname;

  const LoginResult({
    required this.provider,
    required this.authorization,
    required this.refreshToken,
    required this.nickname,
  });
}
