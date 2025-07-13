import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:mutex/mutex.dart';
import 'package:webrtc_test/peer.dart';
import 'package:webrtc_test/signaling.dart';

import 'dart:async';

bool webrtcDebug = false;

void debugPrintWebRTC(Object? message) {
  if (webrtcDebug) {
    // ignore: avoid_print
    print('[WebRTC DEBUG] $message');
  }
}

abstract class Room {
  Room({required String roomid});

  Future sendToPeer(String peerid, {Map<String, dynamic> data});
  Future join({required String userId,
    void Function(Map<String, dynamic>)? onReceiveData,
    void Function(String userId)? onUserJoin,
    void Function(String userId)? onUserLeave
    });

  Future leave();
}

abstract class WebRTCRoom implements Signaling {
  @override
  Future sendSDPAnswer(
    String fromPeerId,
    String toPeerId, {
    required RTCSessionDescription data,
  });

  @override
  Future sendSDPOffer(
    String fromPeerId,
    String toPeerId, {
    required RTCSessionDescription data,
  });

  @override
  Future sendICECandidate(
    String fromPeerId,
    String toPeerId, {
    required RTCIceCandidate data,
  });

  Future join({
    required String userId,
    required void Function(RTCSessionDescription, String fromPeerId)
    onSDPAnswer,
    required void Function(RTCSessionDescription, String fromPeerId) onSDPOffer,
    required void Function(RTCIceCandidate, String fromPeerId) onICECandidate,
    required void Function(String userId) onUserJoin,
    required void Function(String userId) onUserLeave,
  });

  Future leave();
}

class WebRTCRoomJoiner implements AsyncDisposable {
  WebRTCRoom room;
  String selfUserId;
  final m = Mutex();
  Map<String, PeerConnection> otherUsersInRoom = {};
  Timer? presenceTimer;

  void Function(PeerConnection message)? onPeerCreated;
  void Function()? onOtherUsersInRoomChanged;

  WebRTCRoomJoiner(this.room, this.selfUserId);

  Future start() async {
    if (presenceTimer != null) {
      debugPrintWebRTC('Presence timer already running.');
      return;
    }

    debugPrintWebRTC('Announcing presence for $selfUserId');
    await room.join(
      userId: selfUserId,
      onICECandidate: handleICECandidate,
      onSDPAnswer: handleSDPAnswer,
      onSDPOffer: handleSDPOffer,
      onUserJoin: handleUserJoin,
      onUserLeave: (userId) {
        // TODO remove
      },
    );
  }

  Future leave() async {
    debugPrintWebRTC('Leaving room for $selfUserId');
    presenceTimer?.cancel();
  }

  Future<({PeerConnection peer, bool created})> tryAddPeer(
    String peerId,
  ) async {
    await m.acquire();
    final peer = otherUsersInRoom[peerId];

    if (peer == null) {
      final newPeer = PeerConnection(
        peerId: peerId,
        signaling: room,
        selfId: selfUserId,
      );
      newPeer.onConnectionClosedOrFailed = () {
        otherUsersInRoom.remove(peerId);
        onOtherUsersInRoomChanged?.call();
      };
      otherUsersInRoom[peerId] = newPeer;
      onPeerCreated?.call(newPeer);
      await newPeer.setupPeerConnectionAndChannels();

      onOtherUsersInRoomChanged?.call();
      m.release();
      return (peer: newPeer, created: true);
    } else {
      m.release();
      return (peer: peer, created: false);
    }
  }

  Future<void> handleSDPAnswer(
    RTCSessionDescription sdp,
    String fromUserId,
  ) async {
    var (peer: peer, created: created) = await tryAddPeer(fromUserId);

    switch (peer) {
      case SelfInitializedPeerConnection():
        peer.handleSDPAnswer(sdp);
        break;
      case PeerInitializedPeerConnection():
        debugPrintWebRTC(
          'SDP answer sent to peer initialized connection, wrong',
        );
        break;
    }
  }

  Future<void> handleSDPOffer(
    RTCSessionDescription sdp,
    String fromUserId,
  ) async {
    debugPrintWebRTC('Handling SDP Offer from $fromUserId');
    var (peer: peer, created: created) = await tryAddPeer(fromUserId);
    switch (peer) {
      case SelfInitializedPeerConnection():
        debugPrintWebRTC(
          'SDP offer sent to self initialized peer connection, wrong',
        );
        break;
      case PeerInitializedPeerConnection():
        peer.handleSDPOffer(sdp);
        break;
    }
  }

  Future<void> handleICECandidate(
    RTCIceCandidate candidate,
    String fromUserId,
  ) async {
    var (peer: peer, created: created) = await tryAddPeer(fromUserId);
    peer.handleICECandidate(candidate);
  }

  Future<void> handleUserJoin(String userId) async {
    debugPrintWebRTC('User joined: $userId');
    var (peer: peer, created: created) = await tryAddPeer(userId);

    switch (peer) {
      case SelfInitializedPeerConnection():
        peer.initializeConnection();
        break;
      case PeerInitializedPeerConnection():
        break;
    }
  }

  @override
  Future<void> disposeAsync() async {
    await room.leave();
    await leave();
  }
}


// TODO: remove peer handling from rooom, is should be totally decoupled,
// user responsibility to manage the peers and route the signaling messages to them
