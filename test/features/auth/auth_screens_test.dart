import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/domain/model/login_state.dart';
import 'package:moabook/domain/model/signup_state.dart';
import 'package:moabook/features/auth/provider/auth_provider.dart';
import 'package:moabook/features/auth/screen/login_screen.dart';
import 'package:moabook/features/auth/screen/signup_screen.dart';

class TestAuth extends AuthNotifier {
  int loginCalls = 0, signupCalls = 0;
  Completer<void>? signupGate;
  @override
  Future<void> kakaoLogin() async {
    loginCalls++;
    ref.read(loginStateProvider.notifier).state = const LoginLoading();
  }

  @override
  Future<void> signup({
    required String socialToken,
    required String provider,
    required String providerId,
    required String nickname,
  }) async {
    signupCalls++;
    ref.read(signupStateProvider.notifier).state = const SignupLoading();
    await signupGate?.future;
    ref.read(signupStateProvider.notifier).state =
        const SignupNicknameDuplicate();
  }
}

const signup = SignupScreen(
  socialToken: 'fixture-only',
  provider: 'KAKAO',
  providerId: 'fixture',
);

void main() {
  testWidgets(
    'login scrolls on a short screen and blocks repeat social taps while loading',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.reset);
      final auth = TestAuth();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authNotifierProvider.overrideWith(() => auth)],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final action = find.text('카카오 로그인');
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pump();
      expect(auth.loginCalls, 1);
      expect(
        tester
            .widget<OutlinedButton>(find.byType(OutlinedButton).first)
            .onPressed,
        isNull,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    'signup remains usable with keyboard and prevents duplicate submissions',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.reset);
      final auth = TestAuth()..signupGate = Completer<void>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authNotifierProvider.overrideWith(() => auth)],
          child: const MaterialApp(home: signup),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), '새 닉네임');
      await tester.pump();
      expect(find.text('완료').hitTestable(), findsOneWidget);
      await tester.tap(find.text('완료'));
      await tester.pump();
      expect(auth.signupCalls, 1);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      auth.signupGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('중복된 닉네임이에요.\n닉네임을 다시 확인해주세요.'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), '다른 이름');
      await tester.pump();
      expect(find.text('중복된 닉네임이에요.\n닉네임을 다시 확인해주세요.'), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
