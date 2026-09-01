import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';

/// The big circular step-progress ring on the home screen: an animated
/// mint-green arc with the step count centered inside.
class StepRing extends StatelessWidget {
  final double progress;
  final int steps;
  final int goal;
  final double size;

  const StepRing({
    super.key,
    required this.progress,
    required this.steps,
    required this.goal,
    this.size = 224,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).round();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        Container(
          width: size,
          height: size * 0.98,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              AppColors.accent.withValues(alpha: 0.28),
              AppColors.accent.withValues(alpha: 0.06),
              Colors.transparent,
            ], stops: const [0, 0.55, 0.72]),
          ),
        ),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress),
          duration: const Duration(milliseconds: 1400),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(value),
          ),
        ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.directions_walk, size: 20, color: AppColors.accent),
          const SizedBox(height: 4),
          Text('$steps', style: AppText.num(size: 48)),
          const SizedBox(height: 4),
          Text('dari ${_fmt(goal)} langkah', style: AppText.body(size: 12, color: AppColors.mut)),
          const SizedBox(height: 9),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.accentTint,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$pct% tercapai',
                style: AppText.body(size: 11, color: AppColors.accent)),
          ),
        ]),
      ]),
    );
  }

  static String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  _RingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 6;
    final track = Paint()
      ..color = const Color(0xFF262626)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;
    canvas.drawCircle(center, radius, track);

    final arc = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708, // -90deg
      progress * 6.28319,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}
