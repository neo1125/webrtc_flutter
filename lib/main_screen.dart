import 'package:flutter/material.dart';
import 'package:webrtc_flutter/chat_screen.dart';
import 'package:webrtc_flutter/local_screen.dart';
import 'package:webrtc_flutter/local_signaling_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _controller = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Center(
      child: Column(
        children: [
          const Spacer(),
          Row(
            children: [
              ElevatedButton(
                onPressed: () {
                  Route<void> route =
                      MaterialPageRoute<void>(builder: (BuildContext context) {
                    return const LocalScreen();
                  });
                  Navigator.push(context, route);
                },
                child: const Text('Local'),
              ),
              ElevatedButton(
                onPressed: () {
                  Route<void> route =
                      MaterialPageRoute<void>(builder: (BuildContext context) {
                    return const LocalSignalingScreen();
                  });
                  Navigator.push(context, route);
                },
                child: const Text('Local Signaling'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextFormField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Enter Chat Room ID',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (_controller.text.isEmpty) {
                return;
              }

              Route<void> route =
                  MaterialPageRoute<void>(builder: (BuildContext context) {
                return ChatScreen(
                  peerId: _controller.text,
                );
              });
              Navigator.push(context, route);
            },
            child: const Text('Enter Chat Room'),
          ),
          const Spacer(),
        ],
      ),
    ));
  }
}
