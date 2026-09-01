import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// A stylized, abstract "map" backdrop: a water blob, a park block, a road
/// grid, and a walking route traced across it. Stands in for a real map SDK
/// while the app runs on mock location data.
class RouteMap extends StatelessWidget {
  final double progress; // 0..1 reveal of the route path
  final bool showPulse;
  final RouteVariant variant;

  /// Overrides variant.waypoints with a real, normalized (0..1) route
  /// shape — see [normalizeRoutePoints] — so the Riwayat history cards can
  /// show each session's actual traced path instead of the mock zigzag,
  /// while keeping this lightweight painted backdrop rather than an
  /// interactive map per list item.
  final List<Offset>? customWaypoints;

  const RouteMap({
    super.key,
    this.progress = 1,
    this.showPulse = false,
    this.variant = RouteVariant.summary,
    this.customWaypoints,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RouteMapPainter(progress: progress, variant: variant, customWaypoints: customWaypoints),
      child: showPulse
          ? _PulseDot(anchor: variant.startAnchor)
          : const SizedBox.expand(),
    );
  }
}

/// Maps real lat/lng points into the 0..1 fractional coordinate space
/// [RouteVariant] waypoints use, so a real decoded route can be drawn by
/// the same lightweight painter as the mock zigzags. Degenerate routes
/// (a single point, or no GPS movement at all) fall back to a short flat
/// stub rather than dividing by zero.
List<Offset> normalizeRoutePoints(List<({double lat, double lng})> points, {double padding = 0.16}) {
  if (points.length < 2) {
    return const [Offset(0.2, 0.5), Offset(0.8, 0.5)];
  }

  var minLat = points.first.lat, maxLat = points.first.lat;
  var minLng = points.first.lng, maxLng = points.first.lng;
  for (final p in points) {
    if (p.lat < minLat) minLat = p.lat;
    if (p.lat > maxLat) maxLat = p.lat;
    if (p.lng < minLng) minLng = p.lng;
    if (p.lng > maxLng) maxLng = p.lng;
  }

  final latSpan = maxLat - minLat;
  final lngSpan = maxLng - minLng;
  if (latSpan == 0 && lngSpan == 0) {
    return const [Offset(0.2, 0.5), Offset(0.8, 0.5)];
  }

  final span = math.max(latSpan, lngSpan) == 0 ? 1.0 : math.max(latSpan, lngSpan);
  final usable = 1 - padding * 2;

  return points.map((p) {
    final x = lngSpan == 0 ? 0.5 : (p.lng - minLng) / span;
    final y = latSpan == 0 ? 0.5 : (maxLat - p.lat) / span; // north = up
    return Offset(padding + x * usable, padding + y * usable);
  }).toList();
}

enum RouteVariant {
  mini(
    waypoints: [
      Offset(0.10, 0.86), Offset(0.22, 0.60), Offset(0.32, 0.68),
      Offset(0.45, 0.28), Offset(0.62, 0.20), Offset(0.80, 0.10),
    ],
    startAnchor: Offset(0.10, 0.86),
  ),
  summary(
    waypoints: [
      Offset(0.20, 0.86), Offset(0.20, 0.62), Offset(0.42, 0.52),
      Offset(0.30, 0.32), Offset(0.55, 0.22), Offset(0.70, 0.20), Offset(0.66, 0.06),
    ],
    startAnchor: Offset(0.20, 0.86),
  ),
  live(
    waypoints: [
      Offset(0.20, 0.90), Offset(0.20, 0.72), Offset(0.42, 0.65),
      Offset(0.25, 0.48), Offset(0.48, 0.44), Offset(0.68, 0.38),
      Offset(0.62, 0.28), Offset(0.58, 0.12),
    ],
    startAnchor: Offset(0.20, 0.90),
  );

  final List<Offset> waypoints;
  final Offset startAnchor;
  const RouteVariant({required this.waypoints, required this.startAnchor});
}

class _RouteMapPainter extends CustomPainter {
  final double progress;
  final RouteVariant variant;
  final List<Offset>? customWaypoints;
  _RouteMapPainter({required this.progress, required this.variant, this.customWaypoints});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.bg);

    // Water blob.
    final waterPath = Path()
      ..moveTo(-size.width * 0.05, size.height * 0.28)
      ..quadraticBezierTo(size.width * 0.32, size.height * 0.16,
          size.width * 0.55, size.height * 0.34)
      ..quadraticBezierTo(size.width * 0.95, size.height * 0.42,
          size.width * 1.05, size.height * 0.48)
      ..lineTo(size.width * 1.05, size.height * 0.62)
      ..lineTo(-size.width * 0.05, size.height * 0.62)
      ..close();
    canvas.drawPath(waterPath, Paint()..color = AppColors.mapWater);

    // Park block.
    final parkRect = Rect.fromLTWH(
      -size.width * 0.06, size.height * 0.66, size.width * 0.5, size.height * 0.34);
    canvas.drawRRect(
      RRect.fromRectAndRadius(parkRect, const Radius.circular(10)),
      Paint()..color = AppColors.mapPark,
    );

    // Road grid — major then minor.
    final major = Paint()
      ..color = AppColors.mapRoadMajor
      ..strokeWidth = size.width * 0.024
      ..strokeCap = StrokeCap.round;
    final minor = Paint()
      ..color = AppColors.mapRoadMinor
      ..strokeWidth = size.width * 0.009;
    for (final fx in [0.12, 0.60]) {
      canvas.drawLine(Offset(size.width * fx, -10), Offset(size.width * fx, size.height + 10), major);
    }
    canvas.drawLine(Offset(-10, size.height * 0.5), Offset(size.width + 10, size.height * 0.5), major);
    for (final fx in [0.34, 0.82]) {
      canvas.drawLine(Offset(size.width * fx, -10), Offset(size.width * fx, size.height + 10), minor);
    }
    canvas.drawLine(Offset(-10, size.height * 0.16), Offset(size.width + 10, size.height * 0.16), minor);

    // Route path.
    final waypoints = customWaypoints ?? variant.waypoints;
    final pts = waypoints.map((o) => Offset(o.dx * size.width, o.dy * size.height)).toList();
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final prev = pts[i - 1];
      final cur = pts[i];
      final mid = Offset((prev.dx + cur.dx) / 2, (prev.dy + cur.dy) / 2);
      path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
      if (i == pts.length - 1) path.lineTo(cur.dx, cur.dy);
    }

    Path revealed = path;
    if (progress < 1) {
      final metrics = path.computeMetrics().toList();
      revealed = Path();
      for (final m in metrics) {
        revealed.addPath(m.extractPath(0, m.length * progress), Offset.zero);
      }
    }

    canvas.drawPath(
      revealed,
      Paint()
        ..color = AppColors.route
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.02
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(
      revealed,
      Paint()
        ..color = AppColors.route
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.02
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Start marker.
    final start = pts.first;
    canvas.drawCircle(start, size.width * 0.022, Paint()..color = AppColors.bg);
    canvas.drawCircle(
      start,
      size.width * 0.022,
      Paint()
        ..color = AppColors.route
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.012,
    );
  }

  @override
  bool shouldRepaint(covariant _RouteMapPainter old) =>
      old.progress != progress || old.variant != variant || old.customWaypoints != customWaypoints;
}

class _PulseDot extends StatefulWidget {
  final Offset anchor;
  const _PulseDot({required this.anchor});
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final center = Offset(
        widget.anchor.dx * constraints.maxWidth,
        widget.anchor.dy * constraints.maxHeight,
      );
      return AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          return Stack(children: [
            Positioned(
              left: center.dx - 13 - 13 * t * 1.6,
              top: center.dy - 13 - 13 * t * 1.6,
              child: Opacity(
                opacity: (1 - t).clamp(0, 1) * 0.55,
                child: Container(
                  width: 26 + 26 * t * 1.6,
                  height: 26 + 26 * t * 1.6,
                  decoration: const BoxDecoration(color: AppColors.route, shape: BoxShape.circle),
                ),
              ),
            ),
            Positioned(
              left: center.dx - 9,
              top: center.dy - 9,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.route,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.bg, width: 3),
                  boxShadow: const [BoxShadow(color: AppColors.route, blurRadius: 10)],
                ),
              ),
            ),
          ]);
        },
      );
    });
  }
}
