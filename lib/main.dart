import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:webrtc_test/room.dart';
import 'package:webrtc_test/signaling.dart';

final config = {
  'iceServers': [
    {
        'urls': "stun:stun.relay.metered.ca:80",
      },
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
const supabaseKey =
    'sb_publishable_1gunmARpd59T-WgUIHPHTA_Mz0LtcCN';
late final Supabase supa;
late final RealtimeChannel test;

Future<void> main() async {
  final uuid = Uuid();
  final String userId = uuid.v4();

   supa = await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
  );
 //test = supa.client.realtime.channel("test", RealtimeChannelConfig(private: false));

  //test.onBroadcast(event: "test", callback: (d)=> print(d)).subscribe((s,error) => print({s, error}));
  final signaling = SupabaseRoom(
    roomid: 'test',
    client: supa.client,
  );
  final webRTCSignaling = WebRTCRoom(room: signaling);

  final join = WebRTCRoomJoin(webRTCSignaling, userId, config);
  

  runApp(MyApp(join: join));
}

class MyApp extends StatelessWidget {
  final WebRTCRoomJoin join;

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

  final WebRTCRoomJoin join;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final List<String> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
 

    widget.join.onJoin = (peer) {
      peer.onMessage = (msg) {
        setState(() {
           _messages.add(msg.text);
        });
      };
    };
     widget.join.start();
  }

  void _sendMessage() async {
  //await test.sendBroadcastMessage(event: "test2", payload: {"jj":"jj"});
  //return;
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      for (var roomOccupant in widget.join.otherUsersInRoom.entries) {
        final peer = roomOccupant.value;
        await peer.dataChannelReady.future;
        await peer.sendData(RTCDataChannelMessage(text));
      }
      setState(() {
        _messages.add(text);
      });
      _controller.clear();
      // Scroll to bottom after a short delay to ensure the message is rendered
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
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
          Expanded(
            child: ListView.builder(
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
