import 'package:flutter/material.dart';

import '../theme/zova_colors.dart';

/// The zova brand wordmark used on splash, onboarding and paywalls.
class ZovaLogo extends StatelessWidget {
  const ZovaLogo({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [ZovaColors.gradientStart, ZovaColors.gradientEnd],
            ),
            borderRadius: BorderRadius.circular(size * 0.28),
          ),
          child: Center(
            child: Text(
              'z',
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.55,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'zova',
          style: TextStyle(
            color: ZovaColors.textPrimary,
            fontSize: size * 0.45,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
