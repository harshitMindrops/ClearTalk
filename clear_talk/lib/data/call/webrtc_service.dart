import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// WebRTC peer connection aur local audio stream manage karta hai
class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  // ICE candidate queue — remote description set hone se pehle aye candidates store karna
  final List<RTCIceCandidate> _pendingCandidates = [];
  bool _remoteDescriptionSet = false;

  // ── Callbacks ────────────────────────────────
  Function(RTCIceCandidate candidate)? onIceCandidate;
  Function(RTCPeerConnectionState state)? onConnectionState;
  VoidCallback? onCallConnected;
  VoidCallback? onCallDisconnected;

  static const Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
  };

  // ─────────────────────────────────────────────
  // Init local audio stream
  // ─────────────────────────────────────────────
  Future<void> initLocalStream() async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });
    print('[WebRTC] Local audio stream initialized');
  }

  // ─────────────────────────────────────────────
  // Create peer connection
  // ─────────────────────────────────────────────
  Future<void> initPeerConnection() async {
    _peerConnection = await createPeerConnection(_iceServers);

    // Add local audio tracks to peer connection
    if (_localStream != null) {
      for (final track in _localStream!.getAudioTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }
    }

    // ICE candidate handler
    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        onIceCandidate?.call(candidate);
      }
    };

    // Connection state changes
    _peerConnection!.onConnectionState = (state) {
      print('[WebRTC] Connection state: $state');
      onConnectionState?.call(state);
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        onCallConnected?.call();
      } else if (state ==
              RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        onCallDisconnected?.call();
      }
    };

    print('[WebRTC] Peer connection created');
  }

  // ─────────────────────────────────────────────
  // Caller: Create Offer
  // ─────────────────────────────────────────────
  Future<RTCSessionDescription> createOffer() async {
    final offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
    });
    await _peerConnection!.setLocalDescription(offer);
    print('[WebRTC] Offer created');
    return offer;
  }

  // ─────────────────────────────────────────────
  // Callee: Create Answer
  // ─────────────────────────────────────────────
  Future<RTCSessionDescription> createAnswer() async {
    final answer = await _peerConnection!.createAnswer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
    });
    await _peerConnection!.setLocalDescription(answer);
    print('[WebRTC] Answer created');
    return answer;
  }

  // ─────────────────────────────────────────────
  // Set Remote SDP Description
  // ─────────────────────────────────────────────
  Future<void> setRemoteDescription(RTCSessionDescription sdp) async {
    await _peerConnection!.setRemoteDescription(sdp);
    _remoteDescriptionSet = true;
    print('[WebRTC] Remote description set (${sdp.type})');

    // Process pending ICE candidates
    for (final candidate in _pendingCandidates) {
      await _peerConnection!.addCandidate(candidate);
      print('[WebRTC] Queued ICE candidate added');
    }
    _pendingCandidates.clear();
  }

  // ─────────────────────────────────────────────
  // Add ICE Candidate
  // ─────────────────────────────────────────────
  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    if (!_remoteDescriptionSet) {
      // Queue candidate — remote description abhi set nahi hui
      _pendingCandidates.add(candidate);
      print('[WebRTC] ICE candidate queued (waiting for remote desc)');
      return;
    }
    await _peerConnection!.addCandidate(candidate);
    print('[WebRTC] ICE candidate added');
  }

  // ─────────────────────────────────────────────
  // Mute / Unmute local audio
  // ─────────────────────────────────────────────
  void setMicMuted(bool muted) {
    if (_localStream != null) {
      for (final track in _localStream!.getAudioTracks()) {
        track.enabled = !muted;
      }
      print('[WebRTC] Mic muted: $muted');
    }
  }

  // ─────────────────────────────────────────────
  // Toggle Speakerphone
  // ─────────────────────────────────────────────
  void setSpeakerphoneOn(bool enable) {
    Helper.setSpeakerphoneOn(enable);
    print('[WebRTC] Speakerphone on: $enable');
  }

  // ─────────────────────────────────────────────
  // Cleanup
  // ─────────────────────────────────────────────
  Future<void> dispose() async {
    await _localStream?.dispose();
    await _peerConnection?.close();
    _localStream = null;
    _peerConnection = null;
    _remoteDescriptionSet = false;
    _pendingCandidates.clear();
    print('[WebRTC] Disposed');
  }

  bool get isConnected =>
      _peerConnection?.connectionState ==
      RTCPeerConnectionState.RTCPeerConnectionStateConnected;
}
