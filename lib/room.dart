
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:webrtc_test/signaling.dart';

import 'dart:async';

class WebRTCRoomJoin implements AsyncDisposable {
  WebRTCRoom room;
  String selfUserId;
  Map<String, PeerConnection> otherUsersInRoom = {};
  Timer? presenceTimer;
  Map<String, dynamic> iceConfiguration;

  void Function(PeerConnection message)? onJoin;

  WebRTCRoomJoin(this.room, this.selfUserId, this.iceConfiguration);

  Future start() async {
    if (presenceTimer != null) {
      return;
    }

    await room.announcePresence(
      userId: selfUserId,
      onICECandidate: handleICECandidate,
      onSDPAnswer: handleSDPAnswer,
      onSDPOffer: handleSDPOffer,
      onUserJoin: handleUserJoin,
    );

    presenceTimer = Timer.periodic(Duration(seconds: 10), (_) {
      room.announcePresenceWithoutSubscribe(selfUserId);
    });
  }

  Future leave() async {
    presenceTimer?.cancel();
  }

  Future<void> handleSDPAnswer(
    RTCSessionDescription sdp,
    String fromUserId,
  ) async {
        final found = otherUsersInRoom.containsKey(fromUserId);

    final peer = otherUsersInRoom.putIfAbsent(
      fromUserId,
      () => PeerConnection(
        peerId: fromUserId,
        room: room,
        selfId: selfUserId,
        iceConfiguration: iceConfiguration,
      ),
    );
     if (!found) {
      onJoin?.call(peer);
    }
    await peer.openForIncoming();
    peer.handleSDPAnswer(sdp);
  }

  Future<void> handleSDPOffer(
    RTCSessionDescription sdp,
    String fromUserId,
  ) async {
    final found = otherUsersInRoom.containsKey(fromUserId);
    final peer = otherUsersInRoom.putIfAbsent(
      fromUserId,
      () => PeerConnection(
        peerId: fromUserId,
        room: room,
        selfId: selfUserId,
        iceConfiguration: iceConfiguration,
      ),
    );
    if (!found) {
      onJoin?.call(peer);
    }
    await peer.openForIncoming();
    peer.handleSDPOffer(sdp);

    
  }

  Future<void> handleICECandidate(
    RTCIceCandidate candidate,
    String fromUserId,
  ) async {
    final found = otherUsersInRoom.containsKey(fromUserId);
    
    final peer = otherUsersInRoom.putIfAbsent(
      fromUserId,
      () => PeerConnection(
        peerId: fromUserId,
        room: room,
        selfId: selfUserId,
        iceConfiguration: iceConfiguration,
      ),
    );
    if (!found) {
      onJoin?.call(peer);
    }
    await peer.openForIncoming();
    peer.handleICECandidate(candidate);
  }

  Future<void> handleUserJoin(String userId) async {
    final found = otherUsersInRoom.containsKey(userId);
    if (found) {
      return;
    }

    final peer = otherUsersInRoom.putIfAbsent(
      userId,
      () => PeerConnection(
        peerId: userId,
        room: room,
        selfId: selfUserId,
        iceConfiguration: iceConfiguration,
      ),
    );
    await peer.openForIncoming();
    await peer.connect();
    onJoin?.call(peer);
  }

  @override
  Future<void> disposeAsync() async {
    await leave();
  }
}

class PeerConnection {
  final String peerId;
  final WebRTCRoom room;
  final String selfId;
  late final bool initiator;
  final Map<String, dynamic> iceConfiguration;
  bool connectRun = false;

  RTCPeerConnection? peerConnection;
  final connected = Completer<void>();
  RTCDataChannel? dataChannel;
  RTCSignalingState? signalingState;

  PeerConnection({
    required this.peerId,
    required this.room,
    required this.selfId,
    required this.iceConfiguration,
  }) {
    if (peerId.compareTo(selfId) > 0) {
      initiator = true;
    } else if (peerId.compareTo(selfId) < 0) {
      initiator = false;
    } else {
      throw Exception("PeerId is the same as self id");
    }
  }

  Function(RTCDataChannelMessage)? onMessage;
  final dataChannelReady = Completer<void>();

  Future<void> openForIncoming() async {
    if (peerConnection != null) {
      return;
    }
    peerConnection = await createPeerConnection(iceConfiguration);

    peerConnection!.onIceCandidate = (candidate) => {
      room.sendICECandidate(selfId, peerId, data: candidate),
    };

    peerConnection!.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        connected.complete();
      }
    };

    if (initiator) {
      dataChannel = await peerConnection!.createDataChannel(
        'peerConnection1-dc',
        RTCDataChannelInit()..id = 1,
      );
      dataChannel!.onMessage = (msg){
        print(msg);
        onMessage?.call(msg);
      };
      dataChannel!.onDataChannelState = (state) {
        if (state == RTCDataChannelState.RTCDataChannelOpen) {
          dataChannelReady.complete();
        }
      };
    } else {
      peerConnection!.onDataChannel = (chan) {
        print("chan: $chan");
        dataChannel = chan;
        chan.onMessage = (msg){
        print(msg);
        onMessage?.call(msg);
      };
        chan.onDataChannelState = (state) {
          if (state == RTCDataChannelState.RTCDataChannelOpen) {
            dataChannelReady.complete();
          }
        };
      };
    }
  }

  Future<void> connect() async {
    if (initiator) {
      var offer = await peerConnection!.createOffer({});
      await peerConnection!.setLocalDescription(offer);
      await room.sendSDPOffer(selfId, peerId, data: offer);
    }

    return connected.future;
  }

  Future<void> sendData(RTCDataChannelMessage msg) async {
    await dataChannel!.send(msg);
  }

  Future<void> handleICECandidate(RTCIceCandidate candidate) async {
    final pc = peerConnection;
    if (pc == null) {
      throw Exception("Cannot handle ICE candidate: peerConnection is null.");
    }

    await pc.addCandidate(candidate);
  }

  Future<void> handleSDPAnswer(RTCSessionDescription sdp) async {
    final pc = peerConnection;

    if (!initiator || pc == null) {
      throw Exception(
        "Cannot handle SDP answer: initiator=$initiator, peerConnection is null=${peerConnection == null}.",
      );
    }

    await pc.setRemoteDescription(sdp);
  }

  Future<void> handleSDPOffer(RTCSessionDescription sdp) async {
    final pc = peerConnection;
    if (initiator || pc == null) {
      throw Exception(
        "Cannot handle SDP offer: initiator=$initiator, peerConnection is null=${peerConnection == null}.",
      );
    }
    await pc.setRemoteDescription(sdp);
    var answer = await peerConnection!.createAnswer();
    await peerConnection!.setLocalDescription(answer);
    await room.sendSDPAnswer(selfId, peerId, data: answer);
  }
}



// TODO: remove peer handling from rooom, is should be totally decoupled,
// user responsibility to manage the peers and route the signaling messages to them

// TODO: peer could be more separate, initiatorpeer and receiverpeer, and a factory fun to make them, simpler code

// TODO: transport strategies could be added in a list in ctor, only a ping is by default added