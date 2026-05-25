import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/app/theme/app_colors.dart';

void main() {
  test('primary color is 0xFF010196', () {
    expect(AppColors.primary.toARGB32(), 0xFF010196);
  });
  test('backgroundDefault is 0xFFEBEEF3', () {
    expect(AppColors.backgroundDefault.toARGB32(), 0xFFEBEEF3);
  });
  test('dangerAccent is 0xFFE24646', () {
    expect(AppColors.dangerAccent.toARGB32(), 0xFFE24646);
  });
}
