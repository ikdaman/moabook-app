import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum Mood { a, c }

class DesignPalette {
  const DesignPalette(this.mood);
  final Mood mood;
  bool get dark => mood == Mood.c;
  Color get background =>
      dark ? const Color(0xff121212) : const Color(0xfff4f1ea);
  Color get ink => dark ? const Color(0xfff4f1ea) : const Color(0xff1b1b1b);
  Color get muted => dark ? const Color(0xffaaaaaa) : const Color(0xff68665e);
  Color get card => dark ? const Color(0xff1e1e1e) : const Color(0xfffffdf8);
  Color get line => dark ? const Color(0xff454545) : const Color(0xffc9c4b6);
  Color get accent => dark ? const Color(0xffc8f031) : const Color(0xffff5a36);
  Color get orange => dark ? const Color(0xffff5b2e) : const Color(0xffff5a36);
  Color get blue => dark ? const Color(0xff6a4bff) : const Color(0xff2b45e0);
  Color get yellow => dark ? const Color(0xffc8f031) : const Color(0xfff2c200);
  Color get gift => dark ? const Color(0xffe8c9a0) : const Color(0xff1b1b1b);
  Color get button => dark ? accent : ink;
  Color get onButton => dark ? const Color(0xff121212) : card;
  TextStyle text(
    double size, {
    int weight = 400,
    Color? color,
    double height = 1.5,
    bool serif = false,
    bool mono = false,
  }) => TextStyle(
    fontFamily: mono
        ? 'PlexMono'
        : serif && !dark
        ? 'GowunBatang'
        : 'PlexKR',
    fontSize: size,
    fontWeight:
        FontWeight.values[((dark && weight > 600 ? 600 : weight) ~/ 100) - 1],
    color: color ?? ink,
    height: height,
    letterSpacing: mono ? .5 : -.3,
  );
  ThemeData get theme => ThemeData(
    brightness: dark ? Brightness.dark : Brightness.light,
    fontFamily: 'PlexKR',
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: accent,
      brightness: dark ? Brightness.dark : Brightness.light,
    ).copyWith(primary: accent, surface: background),
    splashFactory: NoSplash.splashFactory,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: accent,
      selectionColor: accent.withValues(alpha: .25),
    ),
  );
}

class DesignIcon extends StatelessWidget {
  const DesignIcon(this.name, {super.key, required this.color, this.size = 22});
  final String name;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/design_preview/icons/$name.svg',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  );
}

class RuledPaper extends CustomPainter {
  RuledPaper(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = .6;
    for (double y = 22; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(RuledPaper oldDelegate) => color != oldDelegate.color;
}
