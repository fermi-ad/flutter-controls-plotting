import 'package:flutter/material.dart';
import 'package:flutter_controls_core/flutter_controls_core.dart';

class PlotStreamMetadata extends ChangeNotifier {
  ConnectionState? _lastConnectionState;

  ConnectionState? get lastConnectionState => _lastConnectionState;

  PlotReply? _plotReply;

  dynamic lastStreamError;

  set lastConnectionState(ConnectionState? state) {
    if (_lastConnectionState != state) {
      _lastConnectionState = state;
      notifyListeners();
    }
  }

  PlotReply? get plotReply => _plotReply;

  set plotReply(PlotReply? reply) {
    _plotReply = reply;
    notifyListeners();
  }
}
