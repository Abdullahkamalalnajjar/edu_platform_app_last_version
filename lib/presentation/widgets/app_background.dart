import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:edu_platform_app/core/constants/app_colors.dart';

/// A reusable animated red-tinted background used across all screens.
/// Matches the Login screen aesthetic with pulsing gradient + red orbs.
class AppBackground extends StatefulWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        // ── Animated gradient base ────────────────────────────────────
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final t = _ctrl.value;
              return Container(
                decoration: BoxDecoration(
                  gradient: isDark
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: const [
                            Color(0xFF0A0000),
                            Color(0xFF1A0000),
                            Color(0xFF0A0000),
                          ],
                          stops: [
                            0.0,
                            0.5 + 0.15 * math.sin(t * 2 * math.pi),
                            1.0,
                          ],
                        )
                      : LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: const [
                            Colors.white,
                            Color(0xFFFFF5F5),
                            Colors.white,
                          ],
                          stops: [
                            0.0,
                            0.5 + 0.15 * math.sin(t * 2 * math.pi),
                            1.0,
                          ],
                        ),
                ),
              );
            },
          ),
        ),

        // ── Orb — top left ────────────────────────────────────────────
        Positioned(
          top: -120,
          left: -80,
          child: Container(
            width: 340,
            height: 340,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withOpacity(isDark ? 0.30 : 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // ── Orb — bottom right ────────────────────────────────────────
        Positioned(
          bottom: -80,
          right: -80,
          child: Container(
            width: 360,
            height: 360,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withOpacity(isDark ? 0.20 : 0.12),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // ── Orb — dark mode middle right ──────────────────────────────
        if (isDark)
          Positioned(
            top: size.height * 0.4,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFB71C1C).withOpacity(0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

        // ── Child content ─────────────────────────────────────────────
        widget.child,
      ],
    );
  }
}
