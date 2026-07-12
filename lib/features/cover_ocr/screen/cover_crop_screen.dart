// 표지 이미지에서 제목/표지 영역을 직접 크롭하는 화면.
//
// 입력: 이미지 bytes. 출력: Navigator.pop<Uint8List>(크롭본 bytes).
// OCR·검색·파일 저장은 호출자(lab 화면)가 담당 — 이 화면은 순수 크롭만.

import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';

class CoverCropScreen extends StatefulWidget {
  const CoverCropScreen({super.key, required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<CoverCropScreen> createState() => _CoverCropScreenState();
}

class _CoverCropScreenState extends State<CoverCropScreen> {
  final _controller = CropController();
  bool _cropping = false;

  void _onCropped(CropResult result) {
    if (!mounted) return;
    switch (result) {
      case CropSuccess(:final croppedImage):
        Navigator.of(context).pop<Uint8List>(croppedImage);
      case CropFailure():
        setState(() => _cropping = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('크롭에 실패했어요. 다시 시도해 주세요.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDefault,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDefault,
        title: Text(
          '영역 선택',
          style: AppTypography.dungGeunMoHeader
              .copyWith(color: AppColors.textPrimary),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Crop(
              image: widget.imageBytes,
              controller: _controller,
              onCropped: _onCropped,
              interactive: true,
              baseColor: AppColors.backgroundDefault,
              maskColor: Colors.black.withValues(alpha: 0.5),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('crop_confirm_button'),
                  onPressed: _cropping
                      ? null
                      : () {
                          setState(() => _cropping = true);
                          _controller.crop();
                        },
                  child: Text(_cropping ? '처리 중...' : '이 영역으로 검색'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
