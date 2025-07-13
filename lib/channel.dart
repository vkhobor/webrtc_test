
import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:webrtc_test/room.dart';
import 'package:webrtc_test/rtc_peerconnection_listener.dart';

abstract class ChannelStrategy {
  Future<void> addChannelToConnection(RTCPeerConnection connection);
  subscribeToPeerConnection(RTCPeerConnectionListener listener);
}

class DataChannelStrategy implements ChannelStrategy {
  RTCDataChannel? dataChannel;
  Future<void> get dataChannelReady => dataChannelReadyCompleter.future;
  final dataChannelReadyCompleter = Completer<void>();
  Function(RTCDataChannelMessage)? onMessage;

  Future<void> sendData(RTCDataChannelMessage msg) async {
    await dataChannelReady;
    debugPrintWebRTC('Sending data $msg');
    await dataChannel!.send(msg);
  }

  @override
  Future<void> addChannelToConnection(RTCPeerConnection peerConnection) async {
    dataChannel = await peerConnection.createDataChannel(
      'peerConnection1-dc',
      RTCDataChannelInit()..id = 1,
    );
    dataChannel!.onMessage = (msg) {
      debugPrintWebRTC('Received message from $msg');
      onMessage?.call(msg);
    };
    dataChannel!.onDataChannelState = (state) {
      debugPrintWebRTC('Data channel state $state');
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        dataChannelReadyCompleter.complete();
      }
    };
  }

  @override
  subscribeToPeerConnection(RTCPeerConnectionListener listener) {
    listener.addOnDataChannelListener((chan) {
      dataChannel = chan;
      chan.onMessage = (msg) {
        onMessage?.call(msg);
      };
      chan.onDataChannelState = (state) {
        debugPrintWebRTC('Data channel state $state');
        if (state == RTCDataChannelState.RTCDataChannelOpen) {
          dataChannelReadyCompleter.complete();
        }
      };
    });
  }
}