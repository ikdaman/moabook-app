import 'package:flutter/material.dart';
import 'app_colors.dart';

final appTheme = ThemeData(
  colorScheme: const ColorScheme.light(
    primary: AppColors.primary,
    surface: AppColors.backgroundDefault,
  ),
  scaffoldBackgroundColor: AppColors.backgroundDefault,
  fontFamily: 'WantedSans',
  useMaterial3: true,
);
