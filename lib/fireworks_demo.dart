import 'package:flutter/material.dart';
import 'features/onboarding/widget/pixel_fireworks.dart';

// 임시 데모 — 픽셀 폭죽 미리보기용. 확인 후 삭제.
void main() => runApp(const _DemoApp());

class _DemoApp extends StatelessWidget {
  const _DemoApp();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF010196), // figma 6번 네이비 bg
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // figma 폭죽 박스 크기 268x150, 투명 배경 위 흰색 폭죽
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                ),
                child: SizedBox(
                  width: 268,
                  height: 150,
                  child: PixelFireworks(),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'BOOK SAVED !',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
