// lib/features/onboarding/onboarding_prefs.dart
import 'package:shared_preferences/shared_preferences.dart';

/// 온보딩을 한 번이라도 본(또는 건너뛴) 적이 있는지 저장하는 키.
/// 설치 후 첫 진입에서만 온보딩을 노출하기 위해 사용한다.
const String kOnboardingSeenKey = 'onboarding_seen';

Future<void> markOnboardingSeen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(kOnboardingSeenKey, true);
}
