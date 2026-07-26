// 갤러리 공유(ACTION_SEND) 전용 Flutter entrypoint.
//
// 투명 ShareActivity가 이 엔트리포인트로 별도 엔진을 띄운다.
// 본앱 main()과 달리 Firebase/Kakao/위젯/라우터 초기화가 없다 —
// 공유 플로우는 OCR + 알라딘 + 저장 API만 쓰기 때문.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screen/share_import_sheet.dart';

@pragma('vm:entry-point')
void shareMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: ShareImportApp()));
}

class ShareImportApp extends StatelessWidget {
  const ShareImportApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // 투명 Activity 위에 시트만 보이도록 배경을 비운다.
      color: Colors.transparent,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.transparent,
        fontFamily: 'WantedSans',
      ),
      home: const ShareImportSheet(),
    );
  }
}
