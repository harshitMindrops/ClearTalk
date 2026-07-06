import 'package:clear_talk/core/theme.dart';
import 'package:clear_talk/data/auth/token_storage.dart';
import 'package:clear_talk/data/call/signaling_service.dart';
import 'package:clear_talk/data/call/webrtc_service.dart';
import 'package:clear_talk/features/auth/screens/login_screen.dart';
import 'package:clear_talk/features/call/screens/call_screen.dart';
import 'package:clear_talk/features/call/screens/incoming_call_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final SignalingService _signalingService = SignalingService();
  final WebRTCService _webRTCService = WebRTCService();

  String? _myUserId;
  String? _myName;

  List<Map<String, dynamic>> _onlineUsers = [];
  bool _isConnecting = true;
  bool _isCallInProgress = false;
  String? _callingUserId;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initSignaling();
  }

  Future<void> _initSignaling() async {
    _myUserId = await TokenStorage.getUserId();
    _myName = await TokenStorage.getUserName();

    if (_myUserId == null || _myName == null) {
      _logout();
      return;
    }

    _signalingService.onUsersList = (users) {
      if (mounted) {
        setState(() {
          _onlineUsers = users.where((u) => u['userId'] != _myUserId).toList();
          _isConnecting = false;
        });
      }
    };

    _signalingService.onIncomingCall = (callerId, callerName) {
      if (!mounted) return;
      if (_isCallInProgress) {
        _signalingService.rejectCall(callerId: callerId);
        return;
      }
      Navigator.of(context).push(
        _slideUpRoute(IncomingCallScreen(
          callerId: callerId,
          callerName: callerName,
          signalingService: _signalingService,
          webRTCService: _webRTCService,
        )),
      );
    };

    _signalingService.onCallAccepted = (calleeId, calleeName) async {
      if (!mounted) return;
      setState(() => _isCallInProgress = true);
      await _webRTCService.initLocalStream();
      if (!mounted) return;
      Navigator.of(context)
          .push(_slideUpRoute(CallScreen(
        remoteUserId: calleeId,
        remoteUserName: calleeName,
        isOutgoing: true,
        signalingService: _signalingService,
        webRTCService: _webRTCService,
      )))
          .then((_) {
        if (mounted) {
          setState(() {
            _isCallInProgress = false;
            _callingUserId = null;
          });
        }
      });
    };

    _signalingService.onCallRejected = (calleeId) {
      if (!mounted) return;
      // Dismiss calling dialog if showing
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      setState(() {
        _isCallInProgress = false;
        _callingUserId = null;
      });
      _showSnack('Call was declined', AppColors.error);
    };

    _signalingService.onCallError = (message) {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      setState(() {
        _isCallInProgress = false;
        _callingUserId = null;
      });
      _showSnack(message, AppColors.error);
    };

    _signalingService.connect(userId: _myUserId!, name: _myName!);
  }

  void _callUser(Map<String, dynamic> user) {
    if (_isCallInProgress) return;
    final targetId = user['userId'] as String;
    final targetName = user['name'] as String;

    setState(() {
      _isCallInProgress = true;
      _callingUserId = targetId;
    });

    _signalingService.callUser(targetUserId: targetId);

    // Intercept callbacks to dismiss dialog first
    final prevAccepted = _signalingService.onCallAccepted;
    final prevRejected = _signalingService.onCallRejected;

    _signalingService.onCallAccepted = (id, name) async {
      if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
      await prevAccepted?.call(id, name);
    };
    _signalingService.onCallRejected = (id) {
      if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
      prevRejected?.call(id);
    };

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CallingDialog(
        name: targetName,
        onCancel: () {
          _signalingService.endCall(targetUserId: targetId);
          setState(() {
            _isCallInProgress = false;
            _callingUserId = null;
          });
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _logout() async {
    await TokenStorage.clear();
    _signalingService.dispose();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
      (_) => false,
    );
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
    ));
  }

  PageRoute _slideUpRoute(Widget page) => PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      );

  @override
  void dispose() {
    _pulseController.dispose();
    _signalingService.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.phone_in_talk_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ClearTalk',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (_myName != null)
                  Text(
                    _myName!,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          // Online indicator
          if (!_isConnecting)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _StatusDot(pulseAnimation: _pulseAnimation),
            ),
          IconButton(
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.logout_rounded,
                  size: 18, color: AppColors.textSecondary),
            ),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Banner ────────────────────
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isConnecting ? 'Connecting...' : 'Who\'s Online',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isConnecting
                      ? 'Establishing secure connection'
                      : _onlineUsers.isEmpty
                          ? 'No other users online right now'
                          : '${_onlineUsers.length} user${_onlineUsers.length == 1 ? '' : 's'} available to call',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),

          const _Divider(),

          // ── Users List ───────────────────────
          Expanded(
            child: _isConnecting
                ? _buildConnecting()
                : _onlineUsers.isEmpty
                    ? _buildEmpty()
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _onlineUsers.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final user = _onlineUsers[i];
                          final isCalling = _callingUserId == user['userId'];
                          return _UserTile(
                            user: user,
                            isCalling: isCalling,
                            isDisabled: _isCallInProgress && !isCalling,
                            onCall: () => _callUser(user),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnecting() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2.5,
            ),
            const SizedBox(height: 16),
            Text(
              'Connecting to server...',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                size: 36,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No one else online',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ask friends to join ClearTalk',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────
// Online Status Dot
// ─────────────────────────────────────────────
class _StatusDot extends StatelessWidget {
  final Animation<double> pulseAnimation;
  const _StatusDot({required this.pulseAnimation});

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: pulseAnimation,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppColors.success,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Divider
// ─────────────────────────────────────────────
class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, color: AppColors.border);
}

// ─────────────────────────────────────────────
// User Tile
// ─────────────────────────────────────────────
class _UserTile extends StatefulWidget {
  final Map<String, dynamic> user;
  final bool isCalling;
  final bool isDisabled;
  final VoidCallback onCall;

  const _UserTile({
    required this.user,
    required this.isCalling,
    required this.isDisabled,
    required this.onCall,
  });

  @override
  State<_UserTile> createState() => _UserTileState();
}

class _UserTileState extends State<_UserTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverCtrl;
  late Animation<double> _elevation;

  @override
  void initState() {
    super.initState();
    _hoverCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    _elevation = Tween<double>(begin: 0, end: 1).animate(_hoverCtrl);
  }

  @override
  void dispose() {
    _hoverCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user['name'] as String? ?? '?';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    // Color seed from name
    final hue = (name.codeUnitAt(0) * 137) % 360;
    final avatarColor = HSLColor.fromAHSL(1, hue.toDouble(), 0.55, 0.55).toColor();

    return AnimatedBuilder(
      animation: _elevation,
      builder: (context, child) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isCalling
                ? AppColors.primary.withOpacity(0.4)
                : AppColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A)
                  .withOpacity(0.04 + _elevation.value * 0.04),
              blurRadius: 8 + _elevation.value * 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.isDisabled ? null : widget.onCall,
          onHighlightChanged: (v) =>
              v ? _hoverCtrl.forward() : _hoverCtrl.reverse(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: avatarColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: avatarColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Available',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Call button
                if (widget.isCalling)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.primary,
                    ),
                  )
                else
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: widget.isDisabled
                          ? AppColors.surfaceVariant
                          : AppColors.success.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.call_rounded,
                      size: 20,
                      color: widget.isDisabled
                          ? AppColors.textHint
                          : AppColors.success,
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
// Calling Dialog
// ─────────────────────────────────────────────
class _CallingDialog extends StatefulWidget {
  final String name;
  final VoidCallback onCancel;

  const _CallingDialog({required this.name, required this.onCancel});

  @override
  State<_CallingDialog> createState() => _CallingDialogState();
}

class _CallingDialogState extends State<_CallingDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.92, end: 1.08)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?';

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar with pulse
            ScaleTransition(
              scale: _pulse,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.avatar,
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Calling ${widget.name}',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ringing...',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textHint,
              ),
            ),
            const SizedBox(height: 28),

            // Cancel button
            GestureDetector(
              onTap: widget.onCancel,
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 32),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.error.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.call_end_rounded,
                        color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Cancel Call',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error,
                      ),
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
}