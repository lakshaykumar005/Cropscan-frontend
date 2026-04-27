import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entry;
  late final AnimationController _ring;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();

    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _ring = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _logoScale = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
    );
    _logoFade = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    _textFade = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.4, 0.9, curve: Curves.easeOut),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.4, 0.9, curve: Curves.easeOutCubic),
    ));

    _entry.forward();

    Future.delayed(const Duration(milliseconds: 2800), _goHome);
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (ctx, anim, secondary) => const MainShell(),
        transitionsBuilder: (ctx, anim, secondary, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _entry.dispose();
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Stack(
        children: [
          // Elegant mesh gradient background
          Positioned(
            top: -150,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF10B981).withValues(alpha: 0.15),
                    const Color(0xFF10B981).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -200,
            left: -150,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF3B82F6).withValues(alpha: 0.08),
                    const Color(0xFF3B82F6).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          
          // Glassmorphic overlay to smooth gradients
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: const SizedBox(),
            ),
          ),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: Listenable.merge([_entry, _ring]),
                  builder: (context, _) {
                    return SizedBox(
                      width: 280,
                      height: 280,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer high-tech rotating rings
                          Opacity(
                            opacity: _logoFade.value,
                            child: Transform.rotate(
                              angle: _ring.value * 2 * math.pi,
                              child: CustomPaint(
                                size: const Size(280, 280),
                                painter: _OuterRingPainter(),
                              ),
                            ),
                          ),
                          Opacity(
                            opacity: _logoFade.value,
                            child: Transform.rotate(
                              angle: -(_ring.value * 2 * math.pi * 1.5), // Reverse & faster
                              child: CustomPaint(
                                size: const Size(230, 230),
                                painter: _InnerRingPainter(),
                              ),
                            ),
                          ),

                          // Central Logo Card
                          Opacity(
                            opacity: _logoFade.value,
                            child: Transform.scale(
                              scale: 0.7 + 0.3 * _logoScale.value,
                              child: Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(40),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 4,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.25),
                                      blurRadius: 30,
                                      spreadRadius: 5,
                                      offset: const Offset(0, 10),
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(36),
                                  child: Image.asset(
                                    'assets/logo/image.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 52),
                
                // Typography
                FadeTransition(
                  opacity: _textFade,
                  child: SlideTransition(
                    position: _textSlide,
                    child: Column(
                      children: [
                        ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFF0F172A), Color(0xFF334155)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: Text(
                            'CropScan',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w800,
                              fontSize: 42,
                              letterSpacing: -1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            'AI Plant Disease Detection',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF059669),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Bottom Loader
          Positioned(
            left: 0,
            right: 0,
            bottom: 60,
            child: FadeTransition(
              opacity: _textFade,
              child: Column(
                children: [
                  const _SleekProgressBar(),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.flaskConical,
                          size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 8),
                      Text(
                        'Initializing deep learning models...',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SleekProgressBar extends StatefulWidget {
  const _SleekProgressBar();

  @override
  State<_SleekProgressBar> createState() => _SleekProgressBarState();
}

class _SleekProgressBarState extends State<_SleekProgressBar> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))..forward();
  }
  
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 160,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(2),
        ),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            return Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 160 * Curves.easeInOutCubic.transform(_ctrl.value),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.5),
                      blurRadius: 8,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            );
          }
        ),
      ),
    );
  }
}

class _OuterRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFFE2E8F0).withValues(alpha: 0.5);
    canvas.drawCircle(center, radius, base);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: const [
          Color(0x0010B981),
          Color(0xFF10B981),
          Color(0xFF3B82F6),
          Color(0x0010B981),
        ],
        stops: const [0.0, 0.4, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 1.5,
      false,
      arc,
    );
    
    // Add 4 tiny dots on the outer ring
    final dot = Paint()..color = const Color(0xFF0F172A).withValues(alpha: 0.3);
    for (int i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      canvas.drawCircle(
        Offset(center.dx + radius * math.cos(a), center.dy + radius * math.sin(a)),
        2.5,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InnerRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    final dashPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF10B981).withValues(alpha: 0.4);

    const int dashCount = 36;
    const double dashLength = (math.pi * 2) / (dashCount * 2);

    for (int i = 0; i < dashCount; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * dashLength * 2,
        dashLength,
        false,
        dashPaint,
      );
    }
    
    // Thicker marker on inner ring
    final markerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF059669);
      
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      0.4,
      false,
      markerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
