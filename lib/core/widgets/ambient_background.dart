import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../theme/zova_colors.dart';

/// A soft, drifting dark-navy backdrop for content screens.
///
/// Layers a deep navy gradient with fixed, faint indigo/cyan light glows and
/// a handful of blurred floating "orb" shapes that drift slowly (28s loop),
/// so the dashboard reads as a high-end, depth-of-field 3D scene without
/// stealing attention from the content on top.
///
/// Under `flutter test` the drift is disabled (the environment variable
/// `FLUTTER_TEST` is set there) so the background renders statically and
/// `pumpAndSettle` never blocks on a repeating animation.
class AmbientBackground extends StatefulWidget {
  const AmbientBackground({super.key, required this.child});

  final Widget child;

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground>
    with SingleTickerProviderStateMixin {
  static const List<_DriftOrb> _orbs = [
    // Deep indigo, drifting from the top-left corner.
    _DriftOrb(
      color: Color(0xFF8A7BFF),
      size: 360,
      opacity: 0.30,
      start: Alignment(-0.85, -1.1),
      end: Alignment(-0.45, -0.65),
      phase: 0.0,
    ),
    // Cyan glow, roaming the lower-right third.
    _DriftOrb(
      color: Color(0xFF59C1FF),
      size: 460,
      opacity: 0.24,
      start: Alignment(1.1, 1.05),
      end: Alignment(0.6, 0.6),
      phase: 0.22,
    ),
    // Brand blue accent high on the right edge.
    _DriftOrb(
      color: Color(0xFF3D7BFF),
      size: 300,
      opacity: 0.26,
      start: Alignment(0.75, -1.15),
      end: Alignment(0.35, -0.6),
      phase: 0.45,
    ),
    // Small pale-indigo orb, "closest" to the camera (depth of field).
    _DriftOrb(
      color: Color(0xFFB39CFF),
      size: 220,
      opacity: 0.22,
      start: Alignment(-1.15, 0.55),
      end: Alignment(-0.6, 0.2),
      phase: 0.68,
    ),
  ];

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 28),
  );

  late final bool _animated =
      kIsWeb || !Platform.environment.containsKey('FLUTTER_TEST');

  @override
  void initState() {
    super.initState();
    if (_animated) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ZovaColors.background,
            Color(0xFF141D33),
            ZovaColors.background,
          ],
        ),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return Stack(
            fit: StackFit.expand,
            children: [
              // Fixed ambient light accents (depth of field).
              const _FixedGlow(
                alignment: Alignment(-0.6, -0.8),
                color: Color(0xFF8A7BFF),
                size: 560,
                opacity: 0.12,
              ),
              const _FixedGlow(
                alignment: Alignment(0.75, 0.85),
                color: Color(0xFF59C1FF),
                size: 640,
                opacity: 0.10,
              ),
              // Slowly drifting floating shapes.
              for (final orb in _orbs) _DriftingOrbView(orb: orb, t: t),
              Positioned.fill(child: widget.child),
            ],
          );
        },
      ),
    );
  }
}

/// A large, stationary, very faint light pool (indigo/cyan "ambient light").
class _FixedGlow extends StatelessWidget {
  const _FixedGlow({
    required this.alignment,
    required this.color,
    required this.size,
    required this.opacity,
  });

  final Alignment alignment;
  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: opacity * 0.4),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

/// One floating shape, whose position and scale drift on the shared animation
/// value [t] with its own phase offset.
class _DriftingOrbView extends StatelessWidget {
  const _DriftingOrbView({required this.orb, required this.t});

  final _DriftOrb orb;
  final double t;

  @override
  Widget build(BuildContext context) {
    // A soft sine wave per orb (0..1) so shapes ease in and out of each
    // corner instead of snapping.
    final wave = (1 - math.cos(2 * math.pi * (t + orb.phase))) / 2;
    final alignment = Alignment.lerp(orb.start, orb.end, wave)!;
    final scale = 1 + 0.08 * (wave - 0.5);
    final size = orb.size * scale;

    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // Off-centre focal point lights each orb like a 3D sphere caught
          // by a top-left key light.
          gradient: RadialGradient(
            focal: const Alignment(-0.25, -0.3),
            colors: [
              orb.color.withValues(alpha: orb.opacity),
              orb.color.withValues(alpha: orb.opacity * 0.45),
              orb.color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriftOrb {
  const _DriftOrb({
    required this.color,
    required this.size,
    required this.opacity,
    required this.start,
    required this.end,
    required this.phase,
  });

  final Color color;
  final double size;
  final double opacity;

  /// Where the orb rests when its phase wave is 0 / 1; positions past ±1 are
  /// fine (the Stack clips the soft edge off-screen).
  final Alignment start;
  final Alignment end;

  /// Phase offset (0..1) so each orb drifts on its own timeline.
  final double phase;
}
