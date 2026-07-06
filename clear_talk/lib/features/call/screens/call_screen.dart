import 'dart:async';
import 'package:clear_talk/core/theme.dart';
import 'package:clear_talk/data/call/signaling_service.dart';
import 'package:clear_talk/data/call/webrtc_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class CallScreen extends StatefulWidget {
  final String remoteUserId;
  final String remoteUserName;
  final bool isOutgoing;
  final SignalingService signalingService;
  final WebRTCService webRTCService;

  const CallScreen({
    super.key,
    required this.remoteUserId,
    required this.remoteUserName,
    required this.isOutgoing,
    required this.signalingService,
    required this.webRTCService,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen>
    with TickerProviderStateMixin {
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isConnected = false;
  bool _isEnding = false;

  Timer? _timer;
  int _secondsElapsed = 0;

  // Pulse for connecting state
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // Ripple rings
  late AnimationController _rippleCtrl;
  late Animation<double> _rippleAnim;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _rippleCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    _rippleAnim = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeOut),
    );

    _setupCallbacks();
    _initCall();
  }

  void _setupCallbacks() {
    widget.signalingService.onAnswerReceived = (sdp, _) async {
      await widget.webRTCService.setRemoteDescription(sdp);
    };

    widget.signalingService.onOfferReceived = (sdp, fromUserId) async {
      await widget.webRTCService.setRemoteDescription(sdp);
      final answer = await widget.webRTCService.createAnswer();
      widget.signalingService.sendAnswer(
          targetUserId: fromUserId, sdp: answer);
    };

    widget.signalingService.onIceCandidateReceived = (candidate) async {
      await widget.webRTCService.addIceCandidate(candidate);
    };

    widget.signalingService.onCallEnded = () {
      if (mounted && !_isEnding) _handleCallEnded();
    };

    widget.webRTCService.onCallConnected = () {
      if (mounted) {
        setState(() => _isConnected = true);
        _pulseCtrl.stop();
        _rippleCtrl.stop();
        _startTimer();
      }
    };

    widget.webRTCService.onCallDisconnected = () {
      if (mounted && !_isEnding) _handleCallEnded();
    };

    widget.webRTCService.onIceCandidate = (candidate) {
      widget.signalingService.sendIceCandidate(
        targetUserId: widget.remoteUserId,
        candidate: candidate,
      );
    };
  }

  Future<void> _initCall() async {
    if (widget.isOutgoing) {
      await widget.webRTCService.initPeerConnection();
      final offer = await widget.webRTCService.createOffer();
      widget.signalingService.sendOffer(
          targetUserId: widget.remoteUserId, sdp: offer);
    } else {
      await widget.webRTCService.initPeerConnection();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _secondsElapsed++);
    });
  }

  String _formatDuration(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    widget.webRTCService.setMicMuted(_isMuted);
  }

  void _toggleSpeaker() {
    setState(() => _isSpeakerOn = !_isSpeakerOn);
    widget.webRTCService.setSpeakerphoneOn(_isSpeakerOn);
  }

  Future<void> _endCall() async {
    if (_isEnding) return;
    setState(() => _isEnding = true);
    widget.signalingService.endCall(targetUserId: widget.remoteUserId);
    await _cleanup();
  }

  void _handleCallEnded() async {
    setState(() => _isEnding = true);
    await _cleanup();
  }

  Future<void> _cleanup() async {
    _timer?.cancel();
    _pulseCtrl.stop();
    _rippleCtrl.stop();
    await widget.webRTCService.dispose();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    _rippleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.remoteUserName;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final hue = name.isNotEmpty ? (name.codeUnitAt(0) * 137) % 360 : 200;
    final avatarColor =
        HSLColor.fromAHSL(1, hue.toDouble(), 0.55, 0.55).toColor();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ─────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  // Back / End early
                  GestureDetector(
                    onTap: _endCall,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 16, color: AppColors.textSecondary),
                    ),
                  ),
                  const Spacer(),
                  // Secure badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline_rounded,
                            size: 11, color: AppColors.success),
                        const SizedBox(width: 4),
                        Text(
                          'Encrypted',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // ── Avatar ──────────────────────────
            Stack(
              alignment: Alignment.center,
              children: [
                // Ripple ring (only when not connected)
                if (!_isConnected && !_isEnding)
                  AnimatedBuilder(
                    animation: _rippleAnim,
                    builder: (_, __) => Transform.scale(
                      scale: _rippleAnim.value,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: avatarColor.withOpacity(
                                1.4 - _rippleAnim.value),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                // Avatar
                ScaleTransition(
                  scale: _isConnected
                      ? const AlwaysStoppedAnimation(1.0)
                      : _pulseAnim,
                  child: Container(
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
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ── Name + Status ────────────────────
            Text(
              name,
              style: GoogleFonts.inter(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _isEnding
                  ? _statusChip('Call Ended', AppColors.error)
                  : _isConnected
                      ? _statusChip(
                          _formatDuration(_secondsElapsed), AppColors.success)
                      : _statusChip(
                          widget.isOutgoing
                              ? 'Calling...'
                              : 'Connecting...',
                          AppColors.warning),
            ),

            const Spacer(),

            // ── Controls ────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppShadows.card,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mute
                    _CallControlBtn(
                      icon: _isMuted
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                      label: _isMuted ? 'Unmute' : 'Mute',
                      bgColor: _isMuted
                          ? AppColors.warning.withOpacity(0.12)
                          : AppColors.surfaceVariant,
                      iconColor: _isMuted
                          ? AppColors.warning
                          : AppColors.textSecondary,
                      onTap: _toggleMute,
                    ),

                    // End Call
                    _CallControlBtn(
                      icon: Icons.call_end_rounded,
                      label: 'End Call',
                      bgColor: AppColors.error,
                      iconColor: Colors.white,
                      onTap: _endCall,
                      large: true,
                    ),

                    // Speaker
                    _CallControlBtn(
                      icon: _isSpeakerOn
                          ? Icons.volume_up_rounded
                          : Icons.volume_down_rounded,
                      label: 'Speaker',
                      bgColor: _isSpeakerOn
                          ? AppColors.primary.withOpacity(0.12)
                          : AppColors.surfaceVariant,
                      iconColor: _isSpeakerOn
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      onTap: _toggleSpeaker,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String label, Color color) => Container(
        key: ValueKey(label),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────
// Control Button
// ─────────────────────────────────────────────
class _CallControlBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color bgColor;
  final Color iconColor;
  final VoidCallback onTap;
  final bool large;

  const _CallControlBtn({
    required this.icon,
    required this.label,
    required this.bgColor,
    required this.iconColor,
    required this.onTap,
    this.large = false,
  });

  @override
  State<_CallControlBtn> createState() => _CallControlBtnState();
}

class _CallControlBtnState extends State<_CallControlBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.9).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.large ? 64.0 : 52.0;
    final iconSize = widget.large ? 26.0 : 22.0;

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: widget.bgColor,
                shape: BoxShape.circle,
                boxShadow: widget.large
                    ? [
                        BoxShadow(
                          color: AppColors.error.withOpacity(0.3),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [],
              ),
              child: Icon(widget.icon,
                  color: widget.iconColor, size: iconSize),
            ),
            const SizedBox(height: 8),
            Text(
              widget.label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textHint,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
