import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:edu_platform_app/core/constants/app_colors.dart';

/// Helper class to detect Ramadan period (Egypt time UTC+2)
/// and provide themed widgets during Ramadan.
class RamadanHelper {
  // Ramadan 2026: Feb 17 → Mar 18 (UTC+2 / Egypt Standard Time)
  // We add a small 1-day buffer at the end for moon sighting uncertainty.
  static final _ramadanPeriods = [
    _RamadanPeriod(
      start: DateTime.utc(2026, 2, 17),
      end: DateTime.utc(2026, 3, 19),
    ),
    // Next years can be added here:
    _RamadanPeriod(
      start: DateTime.utc(2027, 2, 6),
      end: DateTime.utc(2027, 3, 8),
    ),
    _RamadanPeriod(
      start: DateTime.utc(2028, 1, 26),
      end: DateTime.utc(2028, 2, 25),
    ),
  ];

  /// Returns true if today falls within a Ramadan period (Egypt UTC+2)
  static bool get isRamadan {
    // Egypt Standard Time = UTC+2 (no DST since 2011)
    final now = DateTime.now().toUtc().add(const Duration(hours: 2));
    final today = DateTime.utc(now.year, now.month, now.day);
    for (final period in _ramadanPeriods) {
      if (!today.isBefore(period.start) && !today.isAfter(period.end)) {
        return true;
      }
    }
    return false;
  }

  /// Day number within Ramadan (1-30)
  static int get ramadanDay {
    if (!isRamadan) return 0;
    final now = DateTime.now().toUtc().add(const Duration(hours: 2));
    final today = DateTime.utc(now.year, now.month, now.day);
    for (final period in _ramadanPeriods) {
      if (!today.isBefore(period.start) && !today.isAfter(period.end)) {
        return today.difference(period.start).inDays + 1;
      }
    }
    return 0;
  }
}

class _RamadanPeriod {
  final DateTime start;
  final DateTime end;
  _RamadanPeriod({required this.start, required this.end});
}

// ═══════════════════════════════════════════════════════════════════════
// RAMADAN APP BAR
// ═══════════════════════════════════════════════════════════════════════

/// A PreferredSizeWidget that wraps a normal AppBar and adds a
/// Ramadan-themed decoration strip below it when Ramadan is active.
class RamadanAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Color? backgroundColor;
  final double elevation;

  const RamadanAppBar({
    super.key,
    this.title = '',
    this.titleWidget,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.backgroundColor,
    this.elevation = 0,
  });

  @override
  Size get preferredSize => Size.fromHeight(
        RamadanHelper.isRamadan ? kToolbarHeight + 36 : kToolbarHeight,
      );

  @override
  Widget build(BuildContext context) {
    final isRamadan = RamadanHelper.isRamadan;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppBar(
          backgroundColor: isRamadan
              ? const Color.fromARGB(
                  255, 114, 38, 38) // Match app's dark red theme
              : (backgroundColor ??
                  Theme.of(context).appBarTheme.backgroundColor),
          elevation: elevation,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: automaticallyImplyLeading,
          leading: leading != null
              ? IconTheme(
                  data: const IconThemeData(color: Colors.white),
                  child: leading!,
                )
              : null,
          iconTheme: isRamadan
              ? const IconThemeData(color: Colors.white)
              : Theme.of(context).appBarTheme.iconTheme,
          title: titleWidget ??
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isRamadan
                      ? Colors.white
                      : Theme.of(context).appBarTheme.titleTextStyle?.color,
                  letterSpacing: -0.3,
                ),
              ),
          actions: isRamadan
              ? [
                  // Ramadan day badge
                  if (RamadanHelper.ramadanDay > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 4,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD4AF37), Color(0xFFB8860B)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🌙', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(
                              'يوم ${RamadanHelper.ramadanDay}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (actions != null)
                    ...actions!.map(
                      (a) => IconTheme(
                        data: const IconThemeData(color: Colors.white),
                        child: a,
                      ),
                    ),
                ]
              : actions,
          flexibleSpace: isRamadan
              ? Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primaryDark,
                        AppColors.primary,
                        AppColors.primaryDark,
                      ],
                    ),
                  ),
                  child: const _StarField(),
                )
              : null,
        ),
        if (isRamadan) const _RamadanStrip(),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// RAMADAN DECORATION STRIP
// ═══════════════════════════════════════════════════════════════════════

class _RamadanStrip extends StatelessWidget {
  const _RamadanStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primaryDark,
            AppColors.primary,
          ],
        ),
        border: Border(
          bottom: BorderSide(color: Color(0xFFD4AF37), width: 1.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _CrescentMoon(size: 14),
          const SizedBox(width: 10),
          Text(
            'رمضان كريم',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFD4AF37),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 10),
          const _CrescentMoon(size: 14),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// CRESCENT MOON WIDGET
// ═══════════════════════════════════════════════════════════════════════

class _CrescentMoon extends StatelessWidget {
  final double size;
  const _CrescentMoon({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _CrescentPainter(),
    );
  }
}

class _CrescentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD4AF37)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Draw outer circle
    canvas.drawCircle(center, r, paint);

    // Clip inner circle to create crescent
    final erasePaint = Paint()
      ..color = Colors.transparent
      ..blendMode = BlendMode.clear;
    canvas.saveLayer(Rect.fromCircle(center: center, radius: r * 1.5), Paint());
    canvas.drawCircle(center, r, paint);
    final innerCenter = Offset(center.dx + r * 0.35, center.dy - r * 0.1);
    canvas.drawCircle(innerCenter, r * 0.8, erasePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════════
// TWINKLING STAR FIELD
// ═══════════════════════════════════════════════════════════════════════

class _StarField extends StatefulWidget {
  const _StarField();

  @override
  State<_StarField> createState() => _StarFieldState();
}

class _StarFieldState extends State<_StarField>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final _rng = Random(42);
  final _stars = <_Star>[];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    for (int i = 0; i < 18; i++) {
      _stars.add(_Star(
        x: _rng.nextDouble(),
        y: _rng.nextDouble(),
        size: _rng.nextDouble() * 2 + 1,
        phase: _rng.nextDouble(),
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _StarPainter(_stars, _controller.value),
          child: Container(),
        );
      },
    );
  }
}

class _Star {
  final double x, y, size, phase;
  const _Star({
    required this.x,
    required this.y,
    required this.size,
    required this.phase,
  });
}

class _StarPainter extends CustomPainter {
  final List<_Star> stars;
  final double t;
  const _StarPainter(this.stars, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final star in stars) {
      final alpha = (sin((t + star.phase) * pi) * 0.5 + 0.5);
      final paint = Paint()
        ..color = const Color(0xFFD4AF37).withOpacity(alpha * 0.8)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(star.x * size.width, star.y * size.height),
        star.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) => old.t != t;
}

// ═══════════════════════════════════════════════════════════════════════
// CONVENIENCE MIXIN for Ramadan greeting once per session
// ═══════════════════════════════════════════════════════════════════════

/// Shows a Ramadan greeting Snackbar — call once on app open if Ramadan
void showRamadanGreeting(BuildContext context) {
  if (!RamadanHelper.isRamadan) return;
  final day = RamadanHelper.ramadanDay;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Text('🌙', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              day > 0 ? 'رمضان كريم 🌟 اليوم $day من رمضان' : 'رمضان كريم 🌟',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: AppColors.primaryDark,
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFD4AF37), width: 1),
      ),
    ),
  );
}
