import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../models/hole.dart';

/// Where a hole sits on the diagram. [x] and [radius] are fractions of the
/// diagram width, [y] is a fraction of its height.
class _HoleSpot {
  const _HoleSpot(this.x, this.y, this.radius);

  final double x;
  final double y;
  final double radius;
}

const Map<Hole, _HoleSpot> _spots = {
  Hole.l1: _HoleSpot(0.30, 0.34, 0.034),
  Hole.l2: _HoleSpot(0.39, 0.29, 0.036),
  Hole.l3: _HoleSpot(0.48, 0.29, 0.036),
  Hole.l4: _HoleSpot(0.555, 0.41, 0.026),
  Hole.r1: _HoleSpot(0.635, 0.34, 0.036),
  Hole.r2: _HoleSpot(0.725, 0.29, 0.038),
  Hole.r3: _HoleSpot(0.815, 0.33, 0.036),
  Hole.r4: _HoleSpot(0.885, 0.46, 0.026),
  Hole.leftSub: _HoleSpot(0.47, 0.53, 0.016),
  Hole.rightSub: _HoleSpot(0.80, 0.56, 0.016),
  Hole.leftThumb: _HoleSpot(0.37, 0.74, 0.030),
  Hole.rightThumb: _HoleSpot(0.68, 0.74, 0.030),
};

/// Colour of a fingertip covering a hole. Deliberately far from the clay
/// palette so covered and open holes are easy to tell apart.
const Color kCoveredColor = Color(0xFF1F7A6E);

/// Aspect ratio (width / height) of the diagram.
const double kDiagramAspectRatio = 2.0;

/// A top-down drawing of a 12-hole ocarina showing which holes are covered.
///
/// Changes to [covered] animate smoothly, which lets a sequence of notes play
/// back like a short fingering video. When [onHoleTap] is set, holes can be
/// tapped to toggle them.
class OcarinaDiagram extends StatefulWidget {
  const OcarinaDiagram({
    super.key,
    required this.covered,
    this.highlight = const {},
    this.onHoleTap,
    this.showLabels = true,
  });

  final Set<Hole> covered;
  final Set<Hole> highlight;
  final ValueChanged<Hole>? onHoleTap;
  final bool showLabels;

  @override
  State<OcarinaDiagram> createState() => _OcarinaDiagramState();
}

class _OcarinaDiagramState extends State<OcarinaDiagram>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );
  late Map<Hole, double> _from = _target(widget.covered);
  late Map<Hole, double> _to = _from;

  static Map<Hole, double> _target(Set<Hole> covered) => {
    for (final h in Hole.values) h: covered.contains(h) ? 1.0 : 0.0,
  };

  Map<Hole, double> get _current {
    final t = Curves.easeOut.transform(_controller.value);
    return {for (final h in Hole.values) h: lerpDouble(_from[h], _to[h], t)!};
  }

  @override
  void didUpdateWidget(OcarinaDiagram oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _target(widget.covered);
    if (!_sameCoverage(next, _to)) {
      _from = _current;
      _to = next;
      _controller.forward(from: 0);
    }
  }

  static bool _sameCoverage(Map<Hole, double> a, Map<Hole, double> b) =>
      Hole.values.every((h) => a[h] == b[h]);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Hole? _hitTest(Offset position, Size size) {
    Hole? best;
    var bestDistance = double.infinity;
    for (final entry in _spots.entries) {
      final spot = entry.value;
      final center = Offset(spot.x * size.width, spot.y * size.height);
      final distance = (position - center).distance;
      final reach = math.max(spot.radius * size.width * 1.6, 22.0);
      if (distance <= reach && distance < bestDistance) {
        best = entry.key;
        bestDistance = distance;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: kDiagramAspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final painter = AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              size: size,
              painter: _OcarinaPainter(
                coverage: _current,
                highlight: widget.highlight,
                showLabels: widget.showLabels,
                scheme: scheme,
              ),
            ),
          );
          final label =
              'Ocarina diagram. Covered: '
              '${widget.covered.isEmpty ? 'none' : widget.covered.map((h) => h.label).join(', ')}';
          if (widget.onHoleTap == null) {
            return Semantics(label: label, child: painter);
          }
          return Semantics(
            label: label,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final hole = _hitTest(details.localPosition, size);
                if (hole != null) widget.onHoleTap!(hole);
              },
              child: painter,
            ),
          );
        },
      ),
    );
  }
}

/// Public for tests: the centre of [hole] on a diagram of [size].
Offset holeCenter(Hole hole, Size size) {
  final spot = _spots[hole]!;
  return Offset(spot.x * size.width, spot.y * size.height);
}

class _OcarinaPainter extends CustomPainter {
  _OcarinaPainter({
    required this.coverage,
    required this.highlight,
    required this.showLabels,
    required this.scheme,
  });

  final Map<Hole, double> coverage;
  final Set<Hole> highlight;
  final bool showLabels;
  final ColorScheme scheme;

  static const _clay = Color(0xFFC98A55);
  static const _clayDark = Color(0xFF8A5530);
  static const _holeInside = Color(0xFF3B2414);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Mouthpiece, drawn first so the body overlaps it.
    final mouth = RRect.fromRectAndRadius(
      Rect.fromLTRB(0.02 * w, 0.40 * h, 0.2 * w, 0.62 * h),
      Radius.circular(0.03 * w),
    );
    canvas.drawRRect(mouth, Paint()..color = _clayDark);
    canvas.drawRRect(mouth.deflate(0.006 * w), Paint()..color = _clay);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(0.025 * w, 0.475 * h, 0.07 * w, 0.545 * h),
        Radius.circular(0.01 * w),
      ),
      Paint()..color = _holeInside,
    );

    // Body: a slightly egg-shaped oval.
    final body = Path()
      ..moveTo(0.14 * w, 0.5 * h)
      ..cubicTo(0.14 * w, 0.12 * h, 0.55 * w, 0.06 * h, 0.8 * w, 0.14 * h)
      ..cubicTo(0.99 * w, 0.2 * h, 0.99 * w, 0.8 * h, 0.8 * w, 0.88 * h)
      ..cubicTo(0.55 * w, 0.96 * h, 0.14 * w, 0.88 * h, 0.14 * w, 0.5 * h)
      ..close();
    final bounds = body.getBounds();
    canvas.drawShadow(body, Colors.black, 4, false);
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE0A874), _clay, Color(0xFFA86B3D)],
        ).createShader(bounds),
    );
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.006 * w
        ..color = _clayDark,
    );

    // Window / labium (the sound-producing edge).
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(0.17 * w, 0.44 * h, 0.23 * w, 0.56 * h),
        Radius.circular(0.008 * w),
      ),
      Paint()..color = _holeInside,
    );

    for (final hole in Hole.values) {
      _paintHole(canvas, size, hole);
    }
  }

  void _paintHole(Canvas canvas, Size size, Hole hole) {
    final spot = _spots[hole]!;
    final center = Offset(spot.x * size.width, spot.y * size.height);
    final r = spot.radius * size.width;
    final amount = coverage[hole] ?? 0;

    if (highlight.contains(hole)) {
      canvas.drawCircle(
        center,
        r * 1.7,
        Paint()..color = scheme.tertiary.withValues(alpha: 0.45),
      );
    }

    if (hole.isThumb) {
      // Underside hole: dashed ring on a lighter patch.
      canvas.drawCircle(
        center,
        r,
        Paint()..color = _clayDark.withValues(alpha: 0.25),
      );
      _dashedCircle(canvas, center, r, _holeInside, size.width * 0.004);
    } else {
      canvas.drawCircle(center, r * 1.12, Paint()..color = _clayDark);
      canvas.drawCircle(center, r, Paint()..color = _holeInside);
    }

    if (amount > 0) {
      // A fingertip pad that grows as the hole is covered.
      final pad = r * (0.4 + 0.75 * amount);
      canvas.drawCircle(
        center,
        pad,
        Paint()..color = kCoveredColor.withValues(alpha: 0.35 + 0.65 * amount),
      );
      canvas.drawCircle(
        center,
        pad,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.004
          ..color = Colors.white.withValues(alpha: 0.7 * amount),
      );
    }

    if (showLabels) {
      final painter = TextPainter(
        text: TextSpan(
          text: hole.shortLabel,
          style: TextStyle(
            fontSize: math.max(9, size.width * 0.022),
            fontWeight: FontWeight.w600,
            color: const Color(0xFF3B2414),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final below = hole.isThumb ? r + 2 : r * 1.2 + 1;
      painter.paint(canvas, center + Offset(-painter.width / 2, below));
    }
  }

  void _dashedCircle(
    Canvas canvas,
    Offset center,
    double r,
    Color color,
    double stroke,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    const dashes = 12;
    const sweep = 2 * math.pi / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        i * sweep,
        sweep * 0.6,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_OcarinaPainter old) =>
      old.coverage != coverage ||
      old.highlight != highlight ||
      old.showLabels != showLabels ||
      old.scheme != scheme;
}

/// Small key explaining the diagram's symbols.
class DiagramLegend extends StatelessWidget {
  const DiagramLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    Widget item(Widget icon, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 4),
        Text(text, style: style),
      ],
    );
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: [
        item(
          const Icon(Icons.circle, size: 14, color: kCoveredColor),
          'covered',
        ),
        item(
          const Icon(Icons.circle, size: 14, color: Color(0xFF3B2414)),
          'open',
        ),
        item(
          const Icon(Icons.radio_button_unchecked, size: 14),
          'thumb (underside)',
        ),
      ],
    );
  }
}
