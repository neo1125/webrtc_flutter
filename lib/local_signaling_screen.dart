import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart';

class LocalSignalingScreen extends StatefulWidget {
  const LocalSignalingScreen({super.key});

  @override
  State<LocalSignalingScreen> createState() => _LocalSignalingScreenState();
}

class _LocalSignalingScreenState extends State<LocalSignalingScreen> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  RTCPeerConnection? _localPeerConnection;
  RTCPeerConnection? _remotePeerConnection;

  MediaStream? _localStream;
  MediaStream? _remoteStream;

  Socket? _localSocket;
  Socket? _remoteSocket;

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
      _remotePeerConnection?.addCandidate(candidate);
    };

    _remotePeerConnection?.onIceCandidate = (candidate) {
      _localPeerConnection?.addCandidate(candidate);
    };

    _remotePeerConnection?.onTrack = (event) {
      _remoteStream = event.streams[0];
      _remoteRenderer.srcObject = _remoteStream;
      setState(() {});
    };

    setState(() {});
  }

  void _setupSocket() {
    print('>>> setup socket');
    _localSocket = io(
      'http://172.16.11.231:3030',
      OptionBuilder()
          .setTimeout(1000)
          .setTransports(['websocket']) // for Flutter or Dart VM
          .disableAutoConnect()
          .disableReconnection()
          .build(),
    );

    _remoteSocket = io(
      'http://172.16.11.231:3030',
      OptionBuilder()
          .setTimeout(1000)
          .setTransports(['websocket']) // for Flutter or Dart VM
          .disableAutoConnect()
          .disableReconnection()
          .build(),
    );

    _localSocket?.onConnect((_) {
      print('>>>>> local socket connected');
      _localSocket?.emit('join', ['local']);
    });
    _localSocket?.onConnectError((error) {
      print('>>>>> local socket connect error : $error');
    });
    _localSocket?.on('joined', (data) {
      print('>>>>> on local joined : $data');
    });

    _remoteSocket?.onConnect((_) {
      print('>>>>> remote socket connected');
      _remoteSocket?.emit('join', ['remote']);
    });
    _remoteSocket?.onConnectError((error) {
      print('>>>>> remote socket connect error : $error');
    });
    _remoteSocket?.on('joined', (data) {
      print('>>>>> on remote joined : $data');
    });

    _localSocket?.connect();
    _remoteSocket?.connect();
  }

  void _sendOfferAnswer() async {
    final offer = await _localPeerConnection?.createOffer();
    await _localPeerConnection?.setLocalDescription(offer!);
    await _remotePeerConnection?.setRemoteDescription(offer!);

    final answer = await _remotePeerConnection?.createAnswer();
    await _remotePeerConnection?.setLocalDescription(answer!);
    await _localPeerConnection?.setRemoteDescription(answer!);
  }

  void _onStart() {
    _setupConnection();
    _setupSocket();
  }

  void _onCall() {
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

    _localSocket?.disconnect();
    _remoteSocket?.disconnect();

    _localSocket?.dispose();
    _remoteSocket?.dispose();

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
            height: 300,
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
            height: 300,
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
          )
        ],
      ),
    );
  }
}
