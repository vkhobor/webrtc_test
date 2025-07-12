import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AsyncDisposable {
  Future<void> disposeAsync();
}

abstract class Room {
  Room({required String roomid});

  Future sendToPeer(String peerid, {Map<String, dynamic> data});

  Future announcePresence({
    required String userId,
    void Function(Map<String, dynamic>)? onReceiveData,
    void Function(String userId)? onUserJoin,
  });
}

class WebRTCRoom {
  Room room;
  bool isSubscribed = false;

  WebRTCRoom({required this.room});

  Future sendSDPAnswer(
    String fromPeerId,
    String toPeerId, {
    required RTCSessionDescription data,
  }) => room.sendToPeer(
      toPeerId,
      data: {
        'from': fromPeerId,
        'signal_type': 'answer',
        'sdp': data.sdp,
        'sdpType': data.type,
      },
    );

   Future sendSDPOffer(
    String fromPeerId,
    String toPeerId, {
    required RTCSessionDescription data,
  }) => room.sendToPeer(
      toPeerId,
      data: {
        'from': fromPeerId,
        'signal_type': 'offer',
        'sdp': data.sdp,
        'sdpType': data.type,
      },
    );

  Future sendICECandidate(
    String fromPeerId,
    String toPeerId, {
    required RTCIceCandidate data,
  }) => room.sendToPeer(
      toPeerId,
      data: {
        'from': fromPeerId,
        'signal_type': 'candidate',
        'candidate': data.toMap(),
      },
    );

  Future announcePresenceWithoutSubscribe(String userId) {
    if (isSubscribed == false) {
      throw Exception("Not yet subscribed, use announce presence first");
    }
    return room.announcePresence(userId: userId);
  }

  Future announcePresence({
    required String userId,
    required void Function(RTCSessionDescription, String fromPeerId)
    onSDPAnswer,
    required void Function(RTCSessionDescription, String fromPeerId) onSDPOffer,
    required void Function(RTCIceCandidate, String fromPeerId) onICECandidate,
    required void Function(String userId) onUserJoin,
  }) {
    isSubscribed = true;

    return room.announcePresence(
      userId: userId,
      onUserJoin: onUserJoin,
      onReceiveData: (p0) {
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
        }
      },
    );
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
    channel = client.channel('${namespace ?? 'signaling'}_$roomid',opts: RealtimeChannelConfig(private: false));
  }

  @override
  Future sendToPeer(String peerid, {Map<String, dynamic>? data}) async {
    await channel.sendBroadcastMessage(
      event: 'to_$peerid',
      payload: {...?data},
    );
  }

  @override
  Future announcePresence({
    required String userId,
    void Function(Map<String, dynamic>)? onReceiveData,
    void Function(String userId)? onUserJoin,
  }) async {
    if (onUserJoin != null) {
      channel
          .onBroadcast(
            event: 'presence_signal',
            callback: (payload) {
              onUserJoin.call(payload["userId"]);
            },
          );
    }
    if (onReceiveData != null) {
      channel
          .onBroadcast(
            event: 'to_$userId',
            callback: (payload) {
              onReceiveData.call(payload);
            },
          );
    }

    if(onReceiveData != null || onUserJoin != null) {
      channel.subscribe();
    }

    await channel.sendBroadcastMessage(
      event: 'presence_signal',
      payload: {'userId': userId},
    );
  }

  @override
  Future<void> disposeAsync() async {
    await client.removeChannel(channel);
  }
}
