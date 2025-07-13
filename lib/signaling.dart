import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:webrtc_test/room.dart';

abstract class AsyncDisposable {
  Future<void> disposeAsync();
}

class WebRTCRoomAdapter implements WebRTCRoom {
  Room room;
  WebRTCRoomAdapter({required this.room});

  @override
  Future sendSDPAnswer(
    String fromPeerId,
    String toPeerId, {
    required RTCSessionDescription data,
  }) {
    debugPrintWebRTC('sendSDPAnswer from $fromPeerId to $toPeerId');
    return room.sendToPeer(
      toPeerId,
      data: {
        'from': fromPeerId,
        'signal_type': 'answer',
        'sdp': data.sdp,
        'sdpType': data.type,
      },
    );
  }

  @override
  Future sendSDPOffer(
    String fromPeerId,
    String toPeerId, {
    required RTCSessionDescription data,
  }) {
    debugPrintWebRTC('sendSDPOffer from $fromPeerId to $toPeerId');
    return room.sendToPeer(
      toPeerId,
      data: {
        'from': fromPeerId,
        'signal_type': 'offer',
        'sdp': data.sdp,
        'sdpType': data.type,
      },
    );
  }

  @override
  Future sendICECandidate(
    String fromPeerId,
    String toPeerId, {
    required RTCIceCandidate data,
  }) {
    debugPrintWebRTC('sendICECandidate from $fromPeerId to $toPeerId');
    return room.sendToPeer(
      toPeerId,
      data: {
        'from': fromPeerId,
        'signal_type': 'candidate',
        'candidate': data.toMap(),
      },
    );
  }

  @override
  Future join({
    required String userId,
    required void Function(RTCSessionDescription, String fromPeerId)
    onSDPAnswer,
    required void Function(RTCSessionDescription, String fromPeerId) onSDPOffer,
    required void Function(RTCIceCandidate, String fromPeerId) onICECandidate,
    required void Function(String userId) onUserJoin,
    required void Function(String userId) onUserLeave,
  }) {
    debugPrintWebRTC('announcePresence for $userId');

    return room.join(
      userId: userId,
      onUserLeave: onUserLeave,
      onUserJoin: (uid) {
        debugPrintWebRTC('onUserJoin: $uid');
        onUserJoin(uid);
      },
      onReceiveData: (p0) {
        debugPrintWebRTC(
          'onReceiveData: ${p0["signal_type"]} from ${p0["from"]}',
        );
        switch (p0["signal_type"]) {
          case "answer":
            onSDPAnswer(
              RTCSessionDescription(
                p0["sdp"] as String,
                p0["sdpType"] as String,
              ),
              p0["from"] as String,
            );
            break;
          case "offer":
            onSDPOffer(
              RTCSessionDescription(
                p0["sdp"] as String,
                p0["sdpType"] as String,
              ),
              p0["from"] as String,
            );
            break;
          case "candidate":
            final candidateMap = p0["candidate"] as Map<String, dynamic>;
            onICECandidate(
              RTCIceCandidate(
                candidateMap["candidate"] as String,
                candidateMap["sdpMid"] as String?,
                candidateMap["sdpMLineIndex"] is int
                    ? candidateMap["sdpMLineIndex"] as int?
                    : candidateMap["sdpMLineIndex"] != null
                    ? int.tryParse(candidateMap["sdpMLineIndex"].toString())
                    : null,
              ),
              p0["from"] as String,
            );
            break;
          default:
            debugPrintWebRTC('Unknown signal_type: ${p0["signal_type"]}');
        }
      },
    );
  }

  @override
  Future leave() async {
    room.leave();
  }
}

class SupabaseRoom implements Room, AsyncDisposable {
  final String roomid;
  final SupabaseClient client;
  late final RealtimeChannel channel;

  SupabaseRoom({
    required this.roomid,
    required this.client,
    String? namespace,
  }) {
    channel = client.channel(
      '${namespace ?? 'signaling'}_$roomid',
      opts: RealtimeChannelConfig(private: false),
    );
  }

  @override
  Future sendToPeer(String peerid, {Map<String, dynamic>? data}) async {
    debugPrintWebRTC('SupabaseRoom sendToPeer: $peerid, data: $data');
    await channel.sendBroadcastMessage(
      event: 'to_$peerid',
      payload: {...?data},
    );
  }

  @override
  Future join({
    required String userId,
    void Function(Map<String, dynamic>)? onReceiveData,
    void Function(String userId)? onUserJoin,
    void Function(String userId)? onUserLeave,
  }) async {
    debugPrintWebRTC('SupabaseRoom announcePresence for $userId');
    channel
        .onBroadcast(
          event: 'presence_signal',
          callback: (payload) {
            debugPrintWebRTC('SupabaseRoom onUserJoin: ${payload["userId"]}');
            onUserJoin!.call(payload["userId"]);
          },
        )
        .onBroadcast(
          event: 'to_$userId',
          callback: (payload) {
            debugPrintWebRTC('SupabaseRoom onReceiveData: $payload');
            onReceiveData!.call(payload);
          },
        )
        .onPresenceJoin((payload) {
          final joinedId = payload.newPresences.first.payload['id'];
          if (joinedId == null) return;
          final joinedIdString = joinedId as String;
          if (joinedIdString != userId) {
            onUserJoin!.call(joinedId);
          }
        })
        .onPresenceLeave((payload) {
          final joinedId = payload.leftPresences.first.payload['id'];
          if (joinedId == null) return;
          final joinedIdString = joinedId as String;

          if (joinedIdString != userId) {
            onUserLeave!.call(joinedId);
          }
        });

    debugPrintWebRTC('SupabaseRoom subscribing channel');
    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        channel.track({'id': userId});
      }
    });
  }

  @override
  Future<void> disposeAsync() async {
    debugPrintWebRTC('SupabaseRoom disposeAsync');
    await leave();
    await client.removeChannel(channel);
  }

  @override
  Future leave() async {
    await channel.unsubscribe();
  }
}
