import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class LocalScreen extends StatefulWidget {
  const LocalScreen({super.key});

  @override
  State<LocalScreen> createState() => _LocalScreenState();
}

class _LocalScreenState extends State<LocalScreen> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  RTCPeerConnection? _localPeerConnection;
  RTCPeerConnection? _remotePeerConnection;

  MediaStream? _localStream;
  MediaStream? _remoteStream;

  String _logMessage = '';

  void _log(String message) {
    final now = DateTime.now().toIso8601String().substring(0, 20);
    setState(() {
      _logMessage += '[$now] $message\n';
    });
  }

  void _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  void _setupConnection() async {
    final config = {
      'iceServers': [
        {'url': 'stun:stun.l.google.com:19302'},
      ],
    };
    final sdpConstraints = {
      'mandatory': {
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': true,
      },
      'optional': []
    };

    _localPeerConnection = await createPeerConnection(config, sdpConstraints);
    _remotePeerConnection = await createPeerConnection(config, sdpConstraints);

    final mediaConstraints = {
      'audio': false,
      'video': {
        'mandatory': {
          'minWidth': '640',
          'minHeight': '480',
          'minFrameRate': '30',
        },
        'facingMode': 'user',
        'optional': [],
      },
    };
    final stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    _localStream = stream;
    _localStream?.getTracks().forEach((track) {
      _localPeerConnection?.addTrack(track, _localStream!);
    });
    _localRenderer.srcObject = _localStream;

    _localPeerConnection?.onIceCandidate = (candidate) {
      _log('local onIceCandidate');
      _remotePeerConnection?.addCandidate(candidate);
    };

    _localPeerConnection?.onConnectionState = (state) {
      _log('local onConnectionState: $state');
    };

    _remotePeerConnection?.onIceCandidate = (candidate) {
      _log('remote onIceCandidate');
      _localPeerConnection?.addCandidate(candidate);
    };

    _remotePeerConnection?.onConnectionState = (state) {
      _log('remote onConnectionState: $state');
    };

    _remotePeerConnection?.onTrack = (event) {
      _remoteStream = event.streams[0];
      _remoteRenderer.srcObject = _remoteStream;
      setState(() {});
    };

    setState(() {});
  }

  void _sendOfferAnswer() async {
    _log('sendOfferAnswer');
    final offer = await _localPeerConnection?.createOffer();
    await _localPeerConnection?.setLocalDescription(offer!);
    await _remotePeerConnection?.setRemoteDescription(offer!);

    final answer = await _remotePeerConnection?.createAnswer();
    await _remotePeerConnection?.setLocalDescription(answer!);
    await _localPeerConnection?.setRemoteDescription(answer!);
  }

  void _onStart() {
    _log('start');
    _setupConnection();
  }

  void _onCall() {
    _log('call');
    _sendOfferAnswer();
  }

  void _onHangup() {
    _localPeerConnection?.close();
    _remotePeerConnection?.close();

    _localPeerConnection?.dispose();
    _remotePeerConnection?.dispose();
  }

  @override
  void initState() {
    super.initState();

    _initRenderers();
  }

  @override
  void dispose() {
    _localPeerConnection?.close();
    _remotePeerConnection?.close();

    _localPeerConnection?.dispose();
    _remotePeerConnection?.dispose();

    _localStream?.dispose();
    _remoteStream?.dispose();

    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Screen'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            height: 200,
            color: Colors.grey.shade400,
            child: RTCVideoView(
              _localRenderer,
              mirror: true,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          ),
          Container(height: 8),
          Container(
            width: double.infinity,
            height: 200,
            color: Colors.grey.shade400,
            child: RTCVideoView(
              _remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          ),
          Row(
            children: [
              TextButton(
                onPressed: _onStart,
                child: const Text('start'),
              ),
              TextButton(
                onPressed: _onCall,
                child: const Text('call'),
              ),
              TextButton(
                onPressed: _onHangup,
                child: const Text('hangup'),
              ),
            ],
          ),
          const Text(
            '------ Log ------',
            style: TextStyle(fontSize: 22),
          ),
          Expanded(
            child: SizedBox(
              width: double.infinity,
              child: SingleChildScrollView(
                child: Text(
                  _logMessage,
                  textAlign: TextAlign.start,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
