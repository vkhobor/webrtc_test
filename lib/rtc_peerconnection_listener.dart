import 'package:flutter_webrtc/flutter_webrtc.dart';

class RTCPeerConnectionListener {
  final RTCPeerConnection _pc;

  final List<void Function(RTCSignalingState)> _onSignalingStateListeners = [];
  void addOnSignalingStateListener(void Function(RTCSignalingState) listener) =>
      _onSignalingStateListeners.add(listener);
  void removeOnSignalingStateListener(
    void Function(RTCSignalingState) listener,
  ) => _onSignalingStateListeners.remove(listener);

  final List<void Function(RTCPeerConnectionState)>
  _onConnectionStateListeners = [];
  void addOnConnectionStateListener(
    void Function(RTCPeerConnectionState) listener,
  ) => _onConnectionStateListeners.add(listener);
  void removeOnConnectionStateListener(
    void Function(RTCPeerConnectionState) listener,
  ) => _onConnectionStateListeners.remove(listener);

  final List<void Function(RTCIceGatheringState)>
  _onIceGatheringStateListeners = [];
  void addOnIceGatheringStateListener(
    void Function(RTCIceGatheringState) listener,
  ) => _onIceGatheringStateListeners.add(listener);
  void removeOnIceGatheringStateListener(
    void Function(RTCIceGatheringState) listener,
  ) => _onIceGatheringStateListeners.remove(listener);

  final List<void Function(RTCIceConnectionState)>
  _onIceConnectionStateListeners = [];
  void addOnIceConnectionStateListener(
    void Function(RTCIceConnectionState) listener,
  ) => _onIceConnectionStateListeners.add(listener);
  void removeOnIceConnectionStateListener(
    void Function(RTCIceConnectionState) listener,
  ) => _onIceConnectionStateListeners.remove(listener);

  final List<void Function(RTCIceCandidate)> _onIceCandidateListeners = [];
  void addOnIceCandidateListener(void Function(RTCIceCandidate) listener) =>
      _onIceCandidateListeners.add(listener);
  void removeOnIceCandidateListener(void Function(RTCIceCandidate) listener) =>
      _onIceCandidateListeners.remove(listener);

  final List<void Function(MediaStream)> _onAddStreamListeners = [];
  void addOnAddStreamListener(void Function(MediaStream) listener) =>
      _onAddStreamListeners.add(listener);
  void removeOnAddStreamListener(void Function(MediaStream) listener) =>
      _onAddStreamListeners.remove(listener);

  final List<void Function(MediaStream)> _onRemoveStreamListeners = [];
  void addOnRemoveStreamListener(void Function(MediaStream) listener) =>
      _onRemoveStreamListeners.add(listener);
  void removeOnRemoveStreamListener(void Function(MediaStream) listener) =>
      _onRemoveStreamListeners.remove(listener);

  final List<void Function(MediaStream, MediaStreamTrack)>
  _onAddTrackListeners = [];
  void addOnAddTrackListener(
    void Function(MediaStream, MediaStreamTrack) listener,
  ) => _onAddTrackListeners.add(listener);
  void removeOnAddTrackListener(
    void Function(MediaStream, MediaStreamTrack) listener,
  ) => _onAddTrackListeners.remove(listener);

  final List<void Function(MediaStream, MediaStreamTrack)>
  _onRemoveTrackListeners = [];
  void addOnRemoveTrackListener(
    void Function(MediaStream, MediaStreamTrack) listener,
  ) => _onRemoveTrackListeners.add(listener);
  void removeOnRemoveTrackListener(
    void Function(MediaStream, MediaStreamTrack) listener,
  ) => _onRemoveTrackListeners.remove(listener);

  final List<void Function(RTCDataChannel)> _onDataChannelListeners = [];
  void addOnDataChannelListener(void Function(RTCDataChannel) listener) =>
      _onDataChannelListeners.add(listener);
  void removeOnDataChannelListener(void Function(RTCDataChannel) listener) =>
      _onDataChannelListeners.remove(listener);

  final List<void Function()> _onRenegotiationNeededListeners = [];
  void addOnRenegotiationNeededListener(void Function() listener) =>
      _onRenegotiationNeededListeners.add(listener);
  void removeOnRenegotiationNeededListener(void Function() listener) =>
      _onRenegotiationNeededListeners.remove(listener);

  RTCPeerConnectionListener(this._pc) {
    _pc.onSignalingState = (state) {
      for (final listener in _onSignalingStateListeners) {
        listener(state);
      }
    };
    _pc.onConnectionState = (state) {
      for (final listener in _onConnectionStateListeners) {
        listener(state);
      }
    };
    _pc.onIceGatheringState = (state) {
      for (final listener in _onIceGatheringStateListeners) {
        listener(state);
      }
    };
    _pc.onIceConnectionState = (state) {
      for (final listener in _onIceConnectionStateListeners) {
        listener(state);
      }
    };
    _pc.onIceCandidate = (candidate) {
      for (final listener in _onIceCandidateListeners) {
        listener(candidate);
      }
    };
    _pc.onAddStream = (stream) {
      for (final listener in _onAddStreamListeners) {
        listener(stream);
      }
    };
    _pc.onRemoveStream = (stream) {
      for (final listener in _onRemoveStreamListeners) {
        listener(stream);
      }
    };
    _pc.onAddTrack = (stream, track) {
      for (final listener in _onAddTrackListeners) {
        listener(stream, track);
      }
    };
    _pc.onRemoveTrack = (stream, track) {
      for (final listener in _onRemoveTrackListeners) {
        listener(stream, track);
      }
    };
    _pc.onDataChannel = (channel) {
      for (final listener in _onDataChannelListeners) {
        listener(channel);
      }
    };
    _pc.onRenegotiationNeeded = () {
      for (final listener in _onRenegotiationNeededListeners) {
        listener();
      }
    };
  }
}
