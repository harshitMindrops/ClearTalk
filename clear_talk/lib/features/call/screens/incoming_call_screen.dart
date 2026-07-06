import 'package:clear_talk/core/theme.dart';
import 'package:clear_talk/data/call/signaling_service.dart';
import 'package:clear_talk/data/call/webrtc_service.dart';
import 'package:clear_talk/features/call/screens/call_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callerId;
  final String callerName;
  final SignalingService signalingService;
  final WebRTCService webRTCService;

  const IncomingCallScreen({
    super.key,
    required this.callerId,
    required this.callerName,
    required this.signalingService,
    required this.webRTCService,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with TickerProviderStateMixin {
  // Ripple ring animation
  late AnimationController _ring1Ctrl;
  late AnimationController _ring2Ctrl;
  late Animation<double> _ring1;
  late Animation<double> _ring2;

  // Slide-in animation
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    // Ring 1 (fast)
    _ring1Ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat();
    _ring1 = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _ring1Ctrl, curve: Curves.easeOut),
    );

    // Ring 2 (offset)
    _ring2Ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _ring2Ctrl.repeat();
    });
    _ring2 = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _ring2Ctrl, curve: Curves.easeOut),
    );

    // Entrance animation
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _fadeAnim =
        CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut);

    widget.signalingService.onCallEnded = () {
      if (mounted) _dismiss();
    };
  }

  @override
  void dispose() {
    _ring1Ctrl.dispose();
    _ring2Ctrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  Future<void> _acceptCall() async {
    _ring1Ctrl.stop();
    _ring2Ctrl.stop();

    await widget.webRTCService.initLocalStream();
    widget.signalingService.acceptCall(callerId: widget.callerId);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => CallScreen(
          remoteUserId: widget.callerId,
          remoteUserName: widget.callerName,
          isOutgoing: false,
          signalingService: widget.signalingService,
          webRTCService: widget.webRTCService,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _rejectCall() {
    widget.signalingService.rejectCall(callerId: widget.callerId);
    _dismiss();
  }

  void _dismiss() {
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.callerName;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final hue = name.isNotEmpty ? (name.codeUnitAt(0) * 137) % 360 : 200;
    final avatarColor =
        HSLColor.fromAHSL(1, hue.toDouble(), 0.55, 0.55).toColor();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Column(
              children: [
                const SizedBox(height: 60),

                // ── Label ───────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.call_received_rounded,
                          size: 13, color: AppColors.primary),
                      const SizedBox(width: 5),
                      Text(
                        'Incoming Audio Call',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 60),

                // ── Ripple Avatar ────────────────
                SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Ring 1
                      AnimatedBuilder(
                        animation: _ring1,
                        builder: (_, __) => Transform.scale(
                          scale: _ring1.value,
                          child: Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: avatarColor.withOpacity(
                                    (1.5 - _ring1.value) * 0.3),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Ring 2
                      AnimatedBuilder(
                        animation: _ring2,
                        builder: (_, __) => Transform.scale(
                          scale: _ring2.value * 0.9,
                          child: Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: avatarColor.withOpacity(
                                    (1.5 - _ring2.value) * 0.2),
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Avatar
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: avatarColor.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: avatarColor.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            initial,
                            style: GoogleFonts.inter(
                              fontSize: 48,
                              fontWeight: FontWeight.w700,
                              color: avatarColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Caller Name ──────────────────
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'wants to talk with you',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textHint,
                  ),
                ),

                const Spacer(),

                // ── Action Buttons ───────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: AppShadows.card,
                    ),
                    child: Row(
                      children: [
                        // Decline
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.call_end_rounded,
                            label: 'Decline',
                            color: AppColors.error,
                            onTap: _rejectCall,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Accept
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.call_rounded,
                            label: 'Accept',
                            color: AppColors.success,
                            onTap: _acceptCall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Action Button
// ─────────────────────────────────────────────
class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.94).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: widget.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.color.withOpacity(0.2),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: widget.color, size: 22),
              const SizedBox(height: 3),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
