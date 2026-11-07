import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Keep the sizes specified by each screen independent of system font scaling.
Widget fixedAppTextScale(BuildContext context, Widget? child) =>
    MediaQuery.withNoTextScaling(child: child ?? const SizedBox.shrink());

final appTheme = ThemeData(
  colorScheme: const ColorScheme.light(
    primary: AppColors.primary,
    surface: AppColors.backgroundDefault,
  ),
  scaffoldBackgroundColor: AppColors.backgroundDefault,
  fontFamily: 'WantedSans',
  useMaterial3: true,
);
