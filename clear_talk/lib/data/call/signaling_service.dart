import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// WebRTC signaling via Socket.IO
class SignalingService {
  // ── Change to your server IP/URL ─────────────
  // Emulator ke liye: http://10.0.2.2:3002
  // Physical device ke liye: http://<PC-LAN-IP>:3002
  static const String _serverUrl = 'https://cleartalk-production.up.railway.app';

  // Nullable — connect() ke baad hi initialize hota hai
  io.Socket? _socket;
  bool _isConnected = false;

  String? _myUserId;
  String? _myName;

  // ── Callbacks ────────────────────────────────
  Function(List<Map<String, dynamic>>)? onUsersList;
  Function(String callerId, String callerName)? onIncomingCall;
  Function(String calleeId, String calleeName)? onCallAccepted;
  Function(String calleeId)? onCallRejected;
  Function(RTCSessionDescription sdp, String fromUserId)? onOfferReceived;
  Function(RTCSessionDescription sdp, String fromUserId)? onAnswerReceived;
  Function(RTCIceCandidate candidate)? onIceCandidateReceived;
  void Function()? onCallEnded;
  Function(String message)? onCallError;

  // ─────────────────────────────────────────────
  // Connect & Register
  // ─────────────────────────────────────────────
  void connect({required String userId, required String name}) {
    _myUserId = userId;
    _myName = name;

    _socket = io.io(
      _serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      print('[Signaling] Connected to server');
      _register();
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      print('[Signaling] Disconnected from server');
    });

    _socket!.onConnectError((err) {
      print('[Signaling] Connection error: $err');
    });

    _setupListeners();
    _socket!.connect();
  }

  void _register() {
    _socket?.emit('register', {'userId': _myUserId, 'name': _myName});
    print('[Signaling] Registered as $_myName ($_myUserId)');
  }

  // ─────────────────────────────────────────────
  // Socket Event Listeners
  // ─────────────────────────────────────────────
  void _setupListeners() {
    final s = _socket;
    if (s == null) return;

    // Online users list
    s.on('users_list', (data) {
      final raw = data as List<dynamic>;
      final users = raw
          .map((u) => Map<String, dynamic>.from(u as Map))
          .toList();
      onUsersList?.call(users);
    });

    // Incoming call from another user
    s.on('incoming_call', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      final callerId = map['callerId'] as String;
      final callerName = map['callerName'] as String;
      print('[Signaling] Incoming call from $callerName ($callerId)');
      onIncomingCall?.call(callerId, callerName);
    });

    // Callee accepted our call
    s.on('call_accepted', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      final calleeId = map['calleeId'] as String;
      final calleeName = map['calleeName'] as String;
      print('[Signaling] Call accepted by $calleeName');
      onCallAccepted?.call(calleeId, calleeName);
    });

    // Callee rejected our call
    s.on('call_rejected', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      final calleeId = map['calleeId'] as String;
      print('[Signaling] Call rejected by $calleeId');
      onCallRejected?.call(calleeId);
    });

    // WebRTC offer received (callee side)
    s.on('receive_offer', (data) async {
      final map = Map<String, dynamic>.from(data as Map);
      final sdpMap = Map<String, dynamic>.from(map['sdp'] as Map);
      final sdp = RTCSessionDescription(
        sdpMap['sdp'] as String,
        sdpMap['type'] as String,
      );
      final fromUserId = map['callerId'] as String;
      print('[Signaling] Offer received from $fromUserId');
      onOfferReceived?.call(sdp, fromUserId);
    });

    // WebRTC answer received (caller side)
    s.on('receive_answer', (data) async {
      final map = Map<String, dynamic>.from(data as Map);
      final sdpMap = Map<String, dynamic>.from(map['sdp'] as Map);
      final sdp = RTCSessionDescription(
        sdpMap['sdp'] as String,
        sdpMap['type'] as String,
      );
      final fromUserId = map['calleeId'] as String;
      print('[Signaling] Answer received from $fromUserId');
      onAnswerReceived?.call(sdp, fromUserId);
    });

    // ICE candidate received
    s.on('ice_candidate', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      final candidateMap = Map<String, dynamic>.from(map['candidate'] as Map);
      final candidate = RTCIceCandidate(
        candidateMap['candidate'] as String,
        candidateMap['sdpMid'] as String?,
        candidateMap['sdpMLineIndex'] as int?,
      );
      onIceCandidateReceived?.call(candidate);
    });

    // Remote party ended the call
    s.on('call_ended', (_) {
      print('[Signaling] Call ended by remote');
      onCallEnded?.call();
    });

    // Error
    s.on('call_error', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      final message = map['message'] as String? ?? 'Unknown error';
      print('[Signaling] Call error: $message');
      onCallError?.call(message);
    });
  }

  // ─────────────────────────────────────────────
  // Emit Methods — sabme null-guard hai
  // ─────────────────────────────────────────────

  void callUser({required String targetUserId}) {
    _socket?.emit('call_user', {
      'targetUserId': targetUserId,
      'callerId': _myUserId,
      'callerName': _myName,
    });
    print('[Signaling] Calling user $targetUserId');
  }

  void acceptCall({required String callerId}) {
    _socket?.emit('call_accepted', {'callerId': callerId});
    print('[Signaling] Accepted call from $callerId');
  }

  void rejectCall({required String callerId}) {
    _socket?.emit('call_rejected', {'callerId': callerId});
    print('[Signaling] Rejected call from $callerId');
  }

  void sendOffer({
    required String targetUserId,
    required RTCSessionDescription sdp,
  }) {
    _socket?.emit('send_offer', {
      'targetUserId': targetUserId,
      'sdp': {'sdp': sdp.sdp, 'type': sdp.type},
    });
    print('[Signaling] Offer sent to $targetUserId');
  }

  void sendAnswer({
    required String targetUserId,
    required RTCSessionDescription sdp,
  }) {
    _socket?.emit('send_answer', {
      'targetUserId': targetUserId,
      'sdp': {'sdp': sdp.sdp, 'type': sdp.type},
    });
    print('[Signaling] Answer sent to $targetUserId');
  }

  void sendIceCandidate({
    required String targetUserId,
    required RTCIceCandidate candidate,
  }) {
    _socket?.emit('ice_candidate', {
      'targetUserId': targetUserId,
      'candidate': {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      },
    });
  }

  void endCall({required String targetUserId}) {
    _socket?.emit('end_call', {'targetUserId': targetUserId});
    print('[Signaling] Ended call with $targetUserId');
  }

  // ─────────────────────────────────────────────
  // Cleanup — safe even if connect() was never called
  // ─────────────────────────────────────────────
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    print('[Signaling] Disposed');
  }

  bool get isConnected => _isConnected;
  String? get myUserId => _myUserId;
  String? get myName => _myName;
}
