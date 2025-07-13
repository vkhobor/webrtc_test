
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:webrtc_test/channel.dart';
import 'package:webrtc_test/room.dart';
import 'package:webrtc_test/rtc_peerconnection_listener.dart';

class SelfInitializedPeerConnection extends PeerConnection {
  SelfInitializedPeerConnection({
    required String peerId,
    required Signaling signaling,
    required String selfId,
  }) : super.internal(peerId, signaling, selfId);

  @override
  Future<void> setupChannels() async {
    if (channelStrategies.isEmpty) {
      throw Exception("You need to set up a channel otherwise ICE wont start");
    }
    for (var element in channelStrategies) {
      element.addChannelToConnection(peerConnection);
    }
  }

  Future<void> initializeConnection() async {
    debugPrintWebRTC('Creating offer for $peerId');
    var offer = await peerConnection.createOffer({});
    await peerConnection.setLocalDescription(offer);
    await signaling.sendSDPOffer(selfId, peerId, data: offer);
  }

  Future<void> handleSDPAnswer(RTCSessionDescription sdp) async {
    await peerConnection.setRemoteDescription(sdp);
  }
}

class PeerInitializedPeerConnection extends PeerConnection {
  PeerInitializedPeerConnection({
    required String peerId,
    required Signaling signaling,
    required String selfId,
  }) : super.internal(peerId, signaling, selfId);

  @override
  Future<void> setupChannels() async {
    if (channelStrategies.isEmpty) {
      throw Exception("You need to set up a channel otherwise ICE wont start");
    }
    for (var strategy in channelStrategies) {
      strategy.subscribeToPeerConnection(peerConnectionListener);
    }
  }

  Future<void> handleSDPOffer(RTCSessionDescription sdp) async {
    await peerConnection.setRemoteDescription(sdp);
    var answer = await peerConnection.createAnswer();
    await peerConnection.setLocalDescription(answer);
    await signaling.sendSDPAnswer(selfId, peerId, data: answer);
  }
}

sealed class PeerConnection {
  factory PeerConnection({
    required String peerId,
    required Signaling signaling,
    required String selfId,
  }) {
    if (peerId.compareTo(selfId) > 0) {
      return SelfInitializedPeerConnection(
        peerId: peerId,
        signaling: signaling,
        selfId: selfId,
      );
    } else if (peerId.compareTo(selfId) < 0) {
      return PeerInitializedPeerConnection(
        peerId: peerId,
        signaling: signaling,
        selfId: selfId,
      );
    } else {
      throw Exception("PeerId is the same as self id");
    }
  }

  PeerConnection.internal(this.peerId, this.signaling, this.selfId);

  final channelStrategies = <ChannelStrategy>[];
  void addChannelStrategy(ChannelStrategy channelStrategy) {
    channelStrategies.add(channelStrategy);
  }

  void setIceConfiguration(Map<String, dynamic> iceConfiguration) {
    this.iceConfiguration = iceConfiguration;
  }

  final String peerId;
  final Signaling signaling;
  final String selfId;
  late Map<String, dynamic> iceConfiguration;

  late RTCPeerConnection peerConnection;
  late RTCPeerConnectionListener peerConnectionListener;

  Function? onConnectionClosedOrFailed;

  Future<void> setupChannels();

  Future<void> handleICECandidate(RTCIceCandidate candidate) async {
    await peerConnection.addCandidate(candidate);
  }

  Future<void> setupPeerConnectionAndChannels() async {
    peerConnection = await createPeerConnection(iceConfiguration);
    peerConnectionListener = RTCPeerConnectionListener(peerConnection!);

    peerConnectionListener.addOnIceCandidateListener((candidate) {
      signaling.sendICECandidate(selfId, peerId, data: candidate);
    });

    peerConnectionListener.addOnConnectionStateListener((state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateClosed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        onConnectionClosedOrFailed?.call();
      }
    });

    await setupChannels();
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