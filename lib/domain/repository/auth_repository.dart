import '../model/login_state.dart';
import '../model/logout_state.dart';
import '../model/signup_state.dart';

abstract interface class AuthRepository {
  Stream<LoginState> kakaoLogin();
  Stream<LoginState> naverLogin();
  Stream<LoginState> googleLogin();
  Stream<LoginState> appleLogin();

  Stream<LogoutState> kakaoLogout();
  Stream<LogoutState> naverLogout();
  Stream<LogoutState> googleLogout();
  Stream<LogoutState> appleLogout();

  Stream<SignupState> signup({
    required String socialToken,
    required String provider,
    required String providerId,
    required String nickname,
  });

  Future<String?> getProvider();
  Future<bool> isLoggedIn();
}
