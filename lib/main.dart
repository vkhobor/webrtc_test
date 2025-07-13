import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:webrtc_test/channel.dart';
import 'package:webrtc_test/room.dart';
import 'package:webrtc_test/signaling.dart';

final config = {
  'iceServers': [
    {'urls': "stun:stun.relay.metered.ca:80"},
    {
      'urls': "turn:standard.relay.metered.ca:80",
      'username': "cb7e381ba4ab8912e817f90f",
      'credential': "FFleBBN3YJHK+KPq",
    },
    {
      'urls': "turn:standard.relay.metered.ca:80?transport=tcp",
      'username': "cb7e381ba4ab8912e817f90f",
      'credential': "FFleBBN3YJHK+KPq",
    },
    {
      'urls': "turn:standard.relay.metered.ca:443",
      'username': "cb7e381ba4ab8912e817f90f",
      'credential': "FFleBBN3YJHK+KPq",
    },
    {
      'urls': "turns:standard.relay.metered.ca:443?transport=tcp",
      'username': "cb7e381ba4ab8912e817f90f",
      'credential': "FFleBBN3YJHK+KPq",
    },
  ],
};

const supabaseUrl = 'https://dmobvlyywtskcrkqqbqw.supabase.co';
const supabaseKey = 'sb_publishable_1gunmARpd59T-WgUIHPHTA_Mz0LtcCN';
late final Supabase supa;
late final RealtimeChannel test;
final uuid = Uuid();

Future<void> main() async {
  final uuid = Uuid();
  final String userId = uuid.v4();

  supa = await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  final supabaseRoom = SupabaseRoom(roomid: 'test', client: supa.client);
  final roomSignaling = WebRTCRoomAdapter(room: supabaseRoom);

  final joiner = WebRTCRoomJoiner(roomSignaling, userId);

  runApp(MyApp(join: joiner));
}

class MyApp extends StatelessWidget {
  final WebRTCRoomJoiner join;

  const MyApp({super.key, required this.join});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: MyHomePage(title: 'Simple Chat Demo', join: join),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, required this.join});
  final String title;

  final WebRTCRoomJoiner join;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final List<String> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _strats = <DataChannelStrategy>[];
  final id = uuid.v4().substring(0, 5);
  num peopleCount = 0;

  @override
  void initState() {
    super.initState();

    Timer.periodic(const Duration(seconds: 1), (timer) {
      final people = widget.join.otherUsersInRoom.values
          .toList()
          .where(
            (x) =>
                x.peerConnection.connectionState ==
                RTCPeerConnectionState.RTCPeerConnectionStateConnected,
          )
          .length;
          setState(() {
            peopleCount = people +1;
          });
    });

    widget.join.onPeerCreated = (peer) {
      final strat = DataChannelStrategy();
      strat.onMessage = (msg) {
        setState(() {
          _messages.insert(0,msg.text);
          
        });
      };
      peer.addChannelStrategy(strat);
      _strats.add(strat);
      peer.setIceConfiguration(config);
    };
    widget.join.start();
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    final textEnrichedWithID = "[$id] $text";
    if (text.isNotEmpty) {
      for (var dataChannel in _strats) {
        await dataChannel.sendData(RTCDataChannelMessage(textEnrichedWithID));
      }
      setState(() {
        _messages.insert(0,textEnrichedWithID);
        
      });
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(
              'Users in room: $peopleCount',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.builder(
              reverse: true,

              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) =>
                  ListTile(title: Text(_messages[index])),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: const InputDecoration(
                      hintText: 'Type a message',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
