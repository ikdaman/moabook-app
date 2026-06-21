import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 도트 게임 느낌의 픽셀 폭죽 애니메이션.
///
/// - 사각형 파티클(`drawRect`) + anti-alias off → crisp 픽셀 엣지
/// - 위치를 [pixelUnit] 격자에 스냅 → 청키한 도트 이동
/// - 시간을 [fps] 로 양자화 → 레트로 choppy 모션
/// - 제한 팔레트(밝은 레트로색) + 흰색→색상→fade
/// - 여러 burst 를 시차로 발사 + 로켓 상승 후 폭발
class PixelFireworks extends StatefulWidget {
  const PixelFireworks({
    super.key,
    this.pixelUnit = 5,
    this.fps = 14,
    this.cycle = const Duration(milliseconds: 4500),
    this.seed = 7,
  });

  /// 도트 한 칸 크기(px).
  final double pixelUnit;

  /// 양자화 프레임레이트(레트로 choppy 느낌).
  final int fps;

  /// 한 사이클 길이(반복).
  final Duration cycle;

  /// 결정적 랜덤 시드(테스트/일관성).
  final int seed;

  @override
  State<PixelFireworks> createState() => _PixelFireworksState();
}

class _PixelFireworksState extends State<PixelFireworks>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  late List<_Burst> _bursts;

  @override
  void initState() {
    super.initState();
    _bursts = _buildBursts();
    _ctrl = AnimationController(vsync: this, duration: widget.cycle)..repeat();
  }

  /// 한 사이클 안의 폭죽 스케줄을 시드 기반으로 생성.
  /// - 높이(apexY) 다양
  /// - 발마다 크기/입자수/속도/대칭 패턴 랜덤 변주
  /// - 동시에 화면에 보이는 발은 최대 3개로 제한
  List<_Burst> _buildBursts() {
    final rnd = math.Random(widget.seed);
    final target = 6 + rnd.nextInt(3); // 후보 6~8발
    const life = _FireworksPainter.burstLife; // 1발 점유 시간(사이클 비율)

    // 시작 시각을 뽑되, 한 시점에 3발 초과로 겹치지 않게 거른다.
    final starts = <double>[];
    var attempts = 0;
    while (starts.length < target && attempts < 80) {
      attempts++;
      final c = rnd.nextDouble() * 0.85; // 끝 15% 정적
      final concurrent = starts.where((s) => (c - s).abs() < life).length;
      if (concurrent < 3) starts.add(c); // 최대 3개 동시
    }
    starts.sort();

    // 시간순 연속 발끼리 위치가 가깝지 않도록 최소 간격(0.3) 두고 launchX 배정.
    final xs = <double>[];
    for (var i = 0; i < starts.length; i++) {
      var x = 0.15 + rnd.nextDouble() * 0.7;
      for (var a = 0; a < 24 && xs.isNotEmpty && (x - xs.last).abs() < 0.3; a++) {
        x = 0.15 + rnd.nextDouble() * 0.7;
      }
      xs.add(x);
    }

    return List.generate(starts.length, (i) {
      final launchX = xs[i];
      // 발마다 크기 변주.
      final reachFactor = 0.28 + rnd.nextDouble() * 0.18; // 0.28~0.46
      // 대칭 ring vs 산개 패턴 랜덤.
      final symmetric = rnd.nextDouble() < 0.45;
      final particleCount = 16 + rnd.nextInt(22); // 16~37
      final speedBase = 0.4 + rnd.nextDouble() * 0.15;
      final speedSpread = 0.55 + rnd.nextDouble() * 0.7;
      final particles = List.generate(particleCount, (k) {
        final angle = symmetric
            ? (k / particleCount) * math.pi * 2 +
                (rnd.nextDouble() - 0.5) * 0.12
            : rnd.nextDouble() * math.pi * 2;
        final speed = speedBase + rnd.nextDouble() * speedSpread;
        return _Particle(angle: angle, speed: speed);
      });
      return _Burst(
        launchX: launchX,
        apexY: 0.20 + rnd.nextDouble() * 0.48, // 0.20~0.68 (높이 다양)
        startT: starts[i],
        reachFactor: reachFactor,
        particles: particles,
      );
    });
  }

  @override
  void reassemble() {
    // 핫리로드 시 _Burst 구조 변경에도 안전하게 재생성(dev 편의).
    super.reassemble();
    _bursts = _buildBursts();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        // fps 로 양자화한 사이클 진행도(0~1).
        final raw = _ctrl.value;
        final frames = (widget.cycle.inMilliseconds / 1000 * widget.fps).round();
        final t = (raw * frames).floor() / frames;
        return CustomPaint(
          painter: _FireworksPainter(
            t: t,
            bursts: _bursts,
            pixelUnit: widget.pixelUnit,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _Particle {
  const _Particle({required this.angle, required this.speed});
  final double angle;
  final double speed;
}

class _Burst {
  const _Burst({
    required this.launchX,
    required this.apexY,
    required this.startT,
    required this.reachFactor,
    required this.particles,
  });
  final double launchX; // 0~1
  final double apexY; // 0~1 (폭발 높이)
  final double startT; // 0~1 (사이클 내 발사 시각)
  final double reachFactor; // 폭발 반경 비율(크기 변주)
  final List<_Particle> particles;
}

class _FireworksPainter extends CustomPainter {
  _FireworksPainter({
    required this.t,
    required this.bursts,
    required this.pixelUnit,
  });

  final double t;
  final List<_Burst> bursts;
  final double pixelUnit;

  static const _riseDur = 0.08; // 로켓 상승 구간
  static const _explodeDur = 0.20; // 폭발 지속 구간(짧을수록 빠른 burst)
  static const _gravity = 0.7;

  /// 1발이 화면에 보이는 총 시간(사이클 비율). 동시 발 수 제한에 사용.
  static const burstLife = _riseDur + _explodeDur;

  @override
  void paint(Canvas canvas, Size size) {
    // 박스 영역 밖으로 새는 픽셀 컷.
    canvas.clipRect(Offset.zero & size);
    final paint = Paint()..isAntiAlias = false;
    final u = pixelUnit;

    Offset snap(Offset p) => Offset(
          (p.dx / u).round() * u,
          (p.dy / u).round() * u,
        );

    for (final b in bursts) {
      // 사이클 내 burst 로컬 시간(래핑).
      var local = t - b.startT;
      if (local < 0) local += 1.0;
      final launchPx = Offset(b.launchX * size.width, size.height);
      final apexPx = Offset(b.launchX * size.width, b.apexY * size.height);

      // 1) 로켓 상승.
      if (local < _riseDur) {
        final p = local / _riseDur;
        final y = launchPx.dy + (apexPx.dy - launchPx.dy) * p;
        final pos = snap(Offset(launchPx.dx, y));
        paint.color = Colors.white;
        canvas.drawRect(Rect.fromLTWH(pos.dx, pos.dy, u, u), paint);
        // 짧은 꼬리.
        paint.color = Colors.white.withValues(alpha: 0.5);
        canvas.drawRect(Rect.fromLTWH(pos.dx, pos.dy + u, u, u), paint);
        continue;
      }

      // 2) 폭발.
      final e = local - _riseDur;
      if (e > _explodeDur) continue;
      final ep = e / _explodeDur; // 0~1
      // 박스 안에 들어오도록 반경 축소 + 발마다 크기 변주.
      final reach = size.height * b.reachFactor;

      // 폭발 순간 플래시(밝은 2x2 코어).
      if (ep < 0.1) {
        paint.color = Colors.white;
        final fa = apexPx;
        for (final off in const [
          Offset(0, 0),
          Offset(1, 0),
          Offset(0, 1),
          Offset(1, 1),
        ]) {
          final fp = snap(fa + Offset(off.dx * u, off.dy * u));
          canvas.drawRect(Rect.fromLTWH(fp.dx, fp.dy, u, u), paint);
        }
      }

      // 중력 처짐(시간 기준, ray 전체에 동일 적용).
      final droop = _gravity * reach * ep * ep;
      // 수명 끝 35%만 전체 fade.
      final lifeAlpha =
          ep < 0.65 ? 1.0 : (1 - (ep - 0.65) / 0.35).clamp(0.0, 1.0);
      // streak 꼬리 길이(폭발 진행에 비례, 상한).
      final trailLen = math.min(0.34 * reach, ep * reach * 1.1);

      for (final part in b.particles) {
        final cosA = math.cos(part.angle);
        final sinA = math.sin(part.angle);
        final headR = part.speed * ep * reach;
        final tailR = math.max(0.0, headR - trailLen * part.speed);
        // 중심→바깥으로 뻗는 선분을 픽셀 단위로 스텝.
        for (double r = tailR; r <= headR; r += u) {
          final pos = snap(Offset(
            apexPx.dx + cosA * r,
            apexPx.dy + sinA * r + droop,
          ));
          // head 밝고 tail 어둡게 → 뻗어나가는 streak.
          final frac = headR > tailR ? (r - tailR) / (headR - tailR) : 1.0;
          final a = lifeAlpha * (0.25 + 0.75 * frac);
          paint.color = Colors.white.withValues(alpha: a.clamp(0.0, 1.0));
          canvas.drawRect(Rect.fromLTWH(pos.dx, pos.dy, u, u), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_FireworksPainter old) => old.t != t;
}
