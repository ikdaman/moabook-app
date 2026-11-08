import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/app/router/app_router.dart';
import 'package:moabook/app/router/routes.dart';
import 'package:moabook/shared/widgets/bottom_nav_bar.dart';
import 'package:moabook/features/notification/provider/push_settings_provider.dart';
import 'package:moabook/features/settings/screen/settings_screen.dart';

class LocalPushSettings extends PushSettingsNotifier {
  @override
  Future<bool> build() async => true;
}

void main() {
  testWidgets('settings route has no bottom navigation tabs', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'nickname': '모아북'});
    appRouter.go(Routes.setting);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pushSettingsProvider.overrideWith(LocalPushSettings.new)],
        child: MaterialApp.router(routerConfig: appRouter),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(BottomNavBar), findsNothing);
    for (final label in ['읽고 싶은 책', '책 추가', '히스토리', '기본 서가', '주제 서가']) {
      expect(find.text(label), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'nickname editing remains usable on a narrow screen with keyboard',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({'nickname': '모아북'});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 740);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [pushSettingsProvider.overrideWith(LocalPushSettings.new)],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('모아북님, 안녕하세요!'), findsOneWidget);
      await tester.tap(find.text('수정'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '   ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('닉네임을 입력해주세요.'), findsOneWidget);
      await tester.ensureVisible(find.text('취소'));
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.text('모아북'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
