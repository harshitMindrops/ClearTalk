import 'dart:async';
import 'package:clear_talk/core/theme.dart';
import 'package:clear_talk/data/auth/token_storage.dart';
import 'package:clear_talk/features/auth/screens/login_screen.dart';
import 'package:clear_talk/features/call/screens/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Logo animation ──────────────────────────
  late AnimationController _logoCtrl;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  // ── Text animation ──────────────────────────
  late AnimationController _textCtrl;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;

  // ── Tagline animation ───────────────────────
  late AnimationController _taglineCtrl;
  late Animation<double> _taglineOpacity;

  // ── Exit animation ──────────────────────────
  late AnimationController _exitCtrl;
  late Animation<double> _exitScale;
  late Animation<double> _exitOpacity;

  // ── Pulse (idle) ────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _runSequence();
  }

  void _setupAnimations() {
    // Logo bounce in
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _logoScale = CurvedAnimation(
      parent: _logoCtrl,
      curve: Curves.elasticOut,
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoCtrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // App name slide up
    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _textOpacity = CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut);
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));

    // Tagline fade
    _taglineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _taglineOpacity =
        CurvedAnimation(parent: _taglineCtrl, curve: Curves.easeOut);

    // Idle pulse on logo
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Exit shrink + fade
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _exitScale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn),
    );
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _exitCtrl,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
      ),
    );
  }

  Future<void> _runSequence() async {
    // 1. Logo bounce in
    await Future.delayed(const Duration(milliseconds: 100));
    _logoCtrl.forward();

    // 2. App name slides up
    await Future.delayed(const Duration(milliseconds: 400));
    _textCtrl.forward();

    // 3. Tagline fades in
    await Future.delayed(const Duration(milliseconds: 250));
    _taglineCtrl.forward();

    // 4. Start idle pulse while checking auth
    await Future.delayed(const Duration(milliseconds: 200));
    _pulseCtrl.repeat(reverse: true);

    // 5. Auth check (runs in parallel with animations above)
    final destination = await _checkAuth();

    // 6. Min display time for good UX (at least 1.8s total)
    await Future.delayed(const Duration(milliseconds: 400));

    // 7. Exit animation
    _pulseCtrl.stop();
    await _exitCtrl.forward();

    // 8. Navigate
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  Future<Widget> _checkAuth() async {
    final token = await TokenStorage.getToken();
    final userId = await TokenStorage.getUserId();
    final isLoggedIn = token != null && token.isNotEmpty && userId != null;
    return isLoggedIn ? const DashboardScreen() : const LoginScreen();
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _taglineCtrl.dispose();
    _pulseCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: AnimatedBuilder(
        animation: _exitCtrl,
        builder: (context, child) => FadeTransition(
          opacity: _exitOpacity,
          child: ScaleTransition(
            scale: _exitScale,
            child: child,
          ),
        ),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return Stack(
      children: [
        // ── Background gradient circles ──────────
        Positioned(
          top: -100,
          right: -80,
          child: _GlowCircle(
            size: 300,
            color: AppColors.primary.withValues(alpha: 0.06),
          ),
        ),
        Positioned(
          bottom: -60,
          left: -60,
          child: _GlowCircle(
            size: 220,
            color: AppColors.secondary.withValues(alpha: 0.05),
          ),
        ),

        // ── Main content ─────────────────────────
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              FadeTransition(
                opacity: _logoOpacity,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: ScaleTransition(
                    scale: _pulseScale,
                    child: _LogoWidget(),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // App name
              ClipRect(
                child: SlideTransition(
                  position: _textSlide,
                  child: FadeTransition(
                    opacity: _textOpacity,
                    child: Text(
                      'ClearTalk',
                      style: GoogleFonts.inter(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -1.0,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Tagline
              FadeTransition(
                opacity: _taglineOpacity,
                child: Text(
                  'Crystal clear audio calls',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: AppColors.textHint,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Bottom branding ──────────────────────
        Positioned(
          bottom: 48,
          left: 0,
          right: 0,
          child: FadeTransition(
            opacity: _taglineOpacity,
            child: Column(
              children: [
                // Loading dots
                _LoadingDots(),
                const SizedBox(height: 20),
                Text(
                  'Secure · Encrypted · Fast',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textHint.withValues(alpha: 0.7),
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Logo Widget
// ─────────────────────────────────────────────
class _LogoWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 32,
            spreadRadius: 4,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(
        Icons.phone_in_talk_rounded,
        color: Colors.white,
        size: 44,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Animated Loading Dots
// ─────────────────────────────────────────────
class _LoadingDots extends StatefulWidget {
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with TickerProviderStateMixin {
  final List<AnimationController> _controllers = [];
  final List<Animation<double>> _anims = [];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 3; i++) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
      final anim = Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: ctrl, curve: Curves.easeInOut),
      );
      _controllers.add(ctrl);
      _anims.add(anim);

      // Staggered repeat
      Future.delayed(Duration(milliseconds: i * 180), () {
        if (mounted) ctrl.repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: FadeTransition(
            opacity: _anims[i],
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────
// Background Glow Circle
// ─────────────────────────────────────────────
class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
