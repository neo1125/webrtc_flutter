import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart';

class ChatScreen extends StatefulWidget {
  final String peerId;
  const ChatScreen({super.key, required this.peerId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  final _config = {
    'iceServers': [
      {
        'urls': [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302',
        ],
      },
    ],
  };
  final _sdpConstraints = {
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': true,
    },
    'optional': []
  };

  late Socket _socket;

  bool _inCalling = false;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  RTCPeerConnection? _peerConnection;

  String _logMessage = '';

  void _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  void _makeCall() async {
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
      _log('connection add track');
      _peerConnection?.addTrack(track, _localStream!);
    });
    _localRenderer.srcObject = _localStream;

    _peerConnection = await createPeerConnection(_config, _sdpConstraints);

    _peerConnection?.onIceCandidate = (candidate) {
      _sendIce(candidate);
    };

    _peerConnection?.onIceConnectionState = (state) {
      _log('ICE connection state changed : ${state.name}');
    };

    _peerConnection?.onConnectionState = (state) {
      _log('connection state changed : ${state.name}');
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          print('>>>>>> onConnectionState : failed : ');
          // _hangUp();
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          print('>>>>>> onConnectionState : close : ');
          // _hangUp();
          break;
        default:
          break;
      }
    };

    _peerConnection?.onTrack = (event) {
      _log('connection remote on track');
      if (event.track.kind == 'video') {
        _remoteStream = event.streams.first;
        _remoteRenderer.srcObject = _remoteStream;
        setState(() {});
      }
    };

    _peerConnection?.onAddStream = (stream) {
      _log('connection remote add stream');
      _remoteStream = stream;
      _remoteRenderer.srcObject = _remoteStream;
      setState(() {});
    };

    _socket.emit('join', widget.peerId);

    setState(() {
      _inCalling = true;
    });
  }

  void _hangUp() async {
    _disconnect();

    setState(() {
      _inCalling = false;
    });
  }

  void _sendOffer() async {
    _log('Send Offer');
    final offer = await _peerConnection?.createOffer();
    _peerConnection?.setLocalDescription(offer!);

    _socket.emit('offer', jsonEncode(offer?.toMap()));
  }

  void _sendAnswer(RTCSessionDescription answer) async {
    _log('Send Answer');
    _socket.emit('answer', jsonEncode(answer.toMap()));
  }

  void _sendIce(RTCIceCandidate ice) async {
    _log('Send Ice');
    _socket.emit('ice', jsonEncode(ice.toMap()));
  }

  void _log(String message) {
    final now = DateTime.now().toIso8601String().substring(0, 22);
    setState(() {
      _logMessage += '[$now] $message\n';
    });
  }

  void _onReceivedJoined() {
    _log('Join Received');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Received'),
        actions: [
          TextButton(
            onPressed: () {
              _sendOffer();
              Navigator.pop(context);
            },
            child: const Text('Ok'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _onReceivedOffer(Map<String, dynamic> data) async {
    _log('Offer Received');
    print('>>>>>> onReceivedOffer : $data');
    if (_peerConnection == null) return;

    final sdp = data['sdp'];
    final type = data['type'];
    final offer = RTCSessionDescription(sdp, type);
    _peerConnection?.setRemoteDescription(offer);

    final answer = await _peerConnection?.createAnswer();
    if (answer == null) return;

    _peerConnection?.setLocalDescription(answer);

    _sendAnswer(answer);
  }

  void _onReceivedAnswer(Map<String, dynamic> data) {
    _log('Answer Received');
    print('>>>>>> onReceivedAnswer : $data');
    if (_peerConnection == null) return;

    final answer = RTCSessionDescription(data['sdp'], data['type']);

    _peerConnection?.setRemoteDescription(answer);
  }

  void _onReceivedIce(Map<String, dynamic> data) {
    _log('Ice Received');
    print('>>>>>> onReceivedIce : $data');
    if (_peerConnection == null) return;

    final ice = RTCIceCandidate(
        data['candidate'], data['sdpMid'], data['sdpMLineIndex']);
    _peerConnection?.addCandidate(ice);
  }

  void _connectSignaling() {
    _log('signaling connecting...');
    try {
      _socket = io(
        'http://172.16.11.231:3030',
        //'http://192.168.0.42:3030',
        OptionBuilder()
            .setTimeout(1000)
            .setTransports(['websocket']) // for Flutter or Dart VM
            .disableAutoConnect()
            .disableReconnection()
            .build(),
      );
      _socket.onConnect((_) {
        _log('signaling connected');
        _makeCall();
      });

      _socket.onConnectError((error) {
        _log('signaling connect error');
        print('>>>>>> onConnectError : ${error}');
      });

      _socket.onError((error) {
        _log('signaling error');
        print('>>>>>> onError : ${error}');
      });

      _socket.on('message', (data) {
        print('>>>>> on message : $data');
      });

      _socket.on('joined', (data) {
        _onReceivedJoined();
      });

      _socket.on('offer', (data) {
        final offer = jsonDecode(data);
        _onReceivedOffer(offer);
      });

      _socket.on('answer', (data) {
        final answer = jsonDecode(data);
        _onReceivedAnswer(answer);
      });

      _socket.on('ice', (data) {
        final ice = jsonDecode(data);
        _onReceivedIce(ice);
      });

      _socket.connect();
    } catch (e) {
      print('>>>>>> error : ${e}');
    }
  }

  _disconnect() {
    _socket.emit('disconnect', {});

    _localStream?.dispose();
    _localRenderer.dispose();

    _remoteStream?.dispose();
    _remoteRenderer.dispose();

    _socket.disconnect();
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initRenderers();
      _connectSignaling();
    });
  }

  @override
  void dispose() {
    _hangUp();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WebRTC Flutter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('WebRTC Flutter'),
          centerTitle: true,
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
            // Row(
            //   children: [
            //     TextButton(
            //       onPressed: _inCalling ? _hangUp : _makeCall,
            //       child: Text(_inCalling ? 'Hangup' : 'Call'),
            //     ),
            //   ],
            // ),
            const Text(
              '------ Log ------',
              style: TextStyle(fontSize: 20),
            ),
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: SingleChildScrollView(
                  child: Text(
                    _logMessage,
                    textAlign: TextAlign.start,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
