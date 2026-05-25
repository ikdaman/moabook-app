sealed class LoginState {
  const LoginState();
}

class LoginLoading extends LoginState {
  const LoginLoading();
}

class LoginSuccess extends LoginState {
  const LoginSuccess();
}

// 서버에 계정 없음(404) → 닉네임 입력 화면으로
class LoginSignupRequired extends LoginState {
  final String socialToken;
  final String provider;
  final String providerId;

  const LoginSignupRequired({
    required this.socialToken,
    required this.provider,
    required this.providerId,
  });
}

class LoginError extends LoginState {
  final String message;

  const LoginError(this.message);
}
