class SocialLoginResult {
  final bool isSuccess;
  final String? socialAccessToken;
  final String? provider;
  final String? providerId;
  final String? errorMessage;

  const SocialLoginResult({
    required this.isSuccess,
    this.socialAccessToken,
    this.provider,
    this.providerId,
    this.errorMessage,
  });
}
