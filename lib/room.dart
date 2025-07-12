import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:webrtc_test/signaling.dart';

import 'dart:async';

bool webrtcDebug = false;

void debugPrintWebRTC(Object? message) {
  if (webrtcDebug) {
    // ignore: avoid_print
    print('[WebRTC DEBUG] $message');
  }
}

class WebRTCRoomJoin implements AsyncDisposable {
  WebRTCRoom room;
  String selfUserId;
  Map<String, PeerConnection> otherUsersInRoom = {};
  Timer? presenceTimer;
  Map<String, dynamic> iceConfiguration;

  void Function(PeerConnection message)? onPeerAdded;

  WebRTCRoomJoin(this.room, this.selfUserId, this.iceConfiguration);

  Future start() async {
    if (presenceTimer != null) {
      debugPrintWebRTC('Presence timer already running.');
      return;
    }

    debugPrintWebRTC('Announcing presence for $selfUserId');
    await room.announcePresence(
      userId: selfUserId,
      onICECandidate: handleICECandidate,
      onSDPAnswer: handleSDPAnswer,
      onSDPOffer: handleSDPOffer,
      onUserJoin: handleUserJoin,
    );

    presenceTimer = Timer.periodic(Duration(seconds: 10), (_) {
      debugPrintWebRTC('Announcing presence (keepalive) for $selfUserId');
      room.announcePresenceWithoutSubscribe(selfUserId);
    });
  }

  Future leave() async {
    debugPrintWebRTC('Leaving room for $selfUserId');
    presenceTimer?.cancel();
  }

  Future<({PeerConnection peer, bool created})> tryAddPeer(
    String peerId,
  ) async {
    final found = otherUsersInRoom.containsKey(peerId);

    final peer = otherUsersInRoom.putIfAbsent(
      peerId,
      () => PeerConnection(
        peerId: peerId,
        signaling: room,
        selfId: selfUserId,
        iceConfiguration: iceConfiguration,
      ),
    );

    if (!found) {
      onPeerAdded?.call(peer);
      await peer.init();
    }

    return (peer: peer, created: !found);
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
    await leave();
  }
}

class SelfInitializedPeerConnection extends PeerConnection {
  final String peerId;
  final Signaling signaling;
  final String selfId;
  final Map<String, dynamic> iceConfiguration;
  bool connectRun = false;

  RTCPeerConnection? peerConnection;
  final connected = Completer<void>();
  RTCDataChannel? dataChannel;
  RTCSignalingState? signalingState;
      final dataChannelReadyCompleter = Completer<void>();


  SelfInitializedPeerConnection({
    required this.peerId,
    required this.signaling,
    required this.selfId,
    required this.iceConfiguration,
  }) : super.internal();

  @override
  Future<void> init() async {
    if (peerConnection != null) {
      debugPrintWebRTC(
        'SelfInitializedPeerConnection already open for $peerId',
      );
      return;
    }
    debugPrintWebRTC('Creating SelfInitializedPeerConnection for $peerId');
    peerConnection = await createPeerConnection(iceConfiguration);

    peerConnection!.onIceCandidate = (candidate) => {
      debugPrintWebRTC('Sending ICE candidate to $peerId'),
      signaling.sendICECandidate(selfId, peerId, data: candidate),
    };

    peerConnection!.onConnectionState = (state) {
      debugPrintWebRTC('Connection state for $peerId: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        connected.complete();
      }
    };

    dataChannel = await peerConnection!.createDataChannel(
      'peerConnection1-dc',
      RTCDataChannelInit()..id = 1,
    );
    dataChannel!.onMessage = (msg) {
      debugPrintWebRTC('Received message from $peerId: $msg');
      onMessage?.call(msg);
    };
    dataChannel!.onDataChannelState = (state) {
      debugPrintWebRTC('Data channel state for $peerId: $state');
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        dataChannelReadyCompleter.complete();
      }
    };
  }

  Future<void> initializeConnection() async {
    debugPrintWebRTC('Creating offer for $peerId');
    var offer = await peerConnection!.createOffer({});
    await peerConnection!.setLocalDescription(offer);
    await signaling.sendSDPOffer(selfId, peerId, data: offer);

    return connected.future;
  }

  @override
  Future<void> sendData(RTCDataChannelMessage msg) async {
    await dataChannel!.send(msg);
  }

  @override
  Future<void> handleICECandidate(RTCIceCandidate candidate) async {
    final pc = peerConnection;
    if (pc == null) {
      throw Exception("Cannot handle ICE candidate: peerConnection is null.");
    }

    await pc.addCandidate(candidate);
  }

  Future<void> handleSDPAnswer(RTCSessionDescription sdp) async {
    final pc = peerConnection;

    if (pc == null) {
      throw Exception(
        "Cannot handle SDP answer: peerConnection is null=${peerConnection == null}.",
      );
    }

    await pc.setRemoteDescription(sdp);
  }
  
  @override
  Future<void> get dataChannelReady => dataChannelReadyCompleter.future;
}

class PeerInitializedPeerConnection extends PeerConnection {
  final String peerId;
  final Signaling signaling;
  final String selfId;
  final Map<String, dynamic> iceConfiguration;
  bool connectRun = false;

  RTCPeerConnection? peerConnection;
  final connected = Completer<void>();
    final dataChannelReadyCompleter = Completer<void>();

  RTCDataChannel? dataChannel;
  RTCSignalingState? signalingState;

  PeerInitializedPeerConnection({
    required this.peerId,
    required this.signaling,
    required this.selfId,
    required this.iceConfiguration,
  }) : super.internal();


  @override
  Future<void> init() async {
    if (peerConnection != null) {
      debugPrintWebRTC(
        'PeerInitializedPeerConnection already open for $peerId',
      );
      return;
    }
    debugPrintWebRTC('Creating PeerInitializedPeerConnection for $peerId');
    peerConnection = await createPeerConnection(iceConfiguration);

    peerConnection!.onIceCandidate = (candidate) => {
      debugPrintWebRTC('Sending ICE candidate to $peerId'),
      signaling.sendICECandidate(selfId, peerId, data: candidate),
    };

    peerConnection!.onConnectionState = (state) {
      debugPrintWebRTC('Connection state for $peerId: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        connected.complete();
      }
    };

    peerConnection!.onDataChannel = (chan) {
      debugPrintWebRTC("Received data channel from $peerId: $chan");
      dataChannel = chan;
      chan.onMessage = (msg) {
        debugPrintWebRTC('Received message from $peerId: $msg');
        onMessage?.call(msg);
      };
      chan.onDataChannelState = (state) {
        debugPrintWebRTC('Data channel state for $peerId: $state');
        if (state == RTCDataChannelState.RTCDataChannelOpen) {
          dataChannelReadyCompleter.complete();
        }
      };
    };
  }

  @override
  Future<void> sendData(RTCDataChannelMessage msg) async {
    debugPrintWebRTC('Sending data to $peerId: $msg');
    await dataChannel!.send(msg);
  }

  @override
  Future<void> handleICECandidate(RTCIceCandidate candidate) async {
    final pc = peerConnection;
    if (pc == null) {
      debugPrintWebRTC(
        'Cannot handle ICE candidate: peerConnection is null for $peerId',
      );
      throw Exception("Cannot handle ICE candidate: peerConnection is null.");
    }
    debugPrintWebRTC('Adding ICE candidate for $peerId');
    await pc.addCandidate(candidate);
  }

  Future<void> handleSDPOffer(RTCSessionDescription sdp) async {
    final pc = peerConnection;
    if (pc == null) {
      throw Exception(
        "Cannot handle SDP offer peerConnection is null=${peerConnection == null}.",
      );
    }
    await pc.setRemoteDescription(sdp);
    var answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    await signaling.sendSDPAnswer(selfId, peerId, data: answer);
  }
  
  @override
  Future<void> get dataChannelReady => dataChannelReadyCompleter.future;
}

sealed class PeerConnection {
  PeerConnection.internal();

  Function(RTCDataChannelMessage)? onMessage;
  Future<void> sendData(RTCDataChannelMessage msg);

  Future<void> get dataChannelReady;
  Future<void> init();
  Future<void> handleICECandidate(RTCIceCandidate candidate);

  factory PeerConnection({
    required String peerId,
    required Signaling signaling,
    required String selfId,
    required Map<String, dynamic> iceConfiguration,
  }) {
    if (peerId.compareTo(selfId) > 0) {
      return SelfInitializedPeerConnection(
        peerId: peerId,
        signaling: signaling,
        selfId: selfId,
        iceConfiguration: iceConfiguration,
      );
    } else if (peerId.compareTo(selfId) < 0) {
      return PeerInitializedPeerConnection(
        peerId: peerId,
        signaling: signaling,
        selfId: selfId,
        iceConfiguration: iceConfiguration,
      );
    } else {
      throw Exception("PeerId is the same as self id");
    }
  }
}

abstract class Signaling {
  Future sendSDPAnswer(
    String fromPeerId,
    String toPeerId, {
    required RTCSessionDescription data,
  });

  Future sendSDPOffer(
    String fromPeerId,
    String toPeerId, {
    required RTCSessionDescription data,
  });

  Future sendICECandidate(
    String fromPeerId,
    String toPeerId, {
    required RTCIceCandidate data,
  });
}


// TODO: remove peer handling from rooom, is should be totally decoupled,
// user responsibility to manage the peers and route the signaling messages to them

// TODO: transport strategies could be added in a list in ctor, only a ping is by default added