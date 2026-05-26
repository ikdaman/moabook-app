sealed class SignupState {
  const SignupState();
}

class SignupLoading extends SignupState {
  const SignupLoading();
}

class SignupSuccess extends SignupState {
  const SignupSuccess();
}

class SignupError extends SignupState {
  final String message;

  const SignupError(this.message);
}

class SignupNicknameDuplicate extends SignupState {
  const SignupNicknameDuplicate();
}
