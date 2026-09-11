import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gql_acsys/flutter_gql_acsys.dart';

class PlotStreamMetadata extends ChangeNotifier {
  ConnectionState? _lastConnectionState;

  ConnectionState? get lastConnectionState => _lastConnectionState;

  PlotReply? _plotReply;

  dynamic lastStreamError;

  Timer? _blinkTimer;

  double? _lastTriggered;

  late int _failedReconnectCount = 0;

  @override
  void dispose() {
    tearDownBlinkTimer();
    super.dispose();
  }

  void setupBlinkTimer(Duration duration) {
    tearDownBlinkTimer();
    _blinkTimer = Timer.periodic(duration, (_) {
      if (_lastTriggered != null) {
        final now = DateTime.now().millisecondsSinceEpoch.toDouble();
        if (now - _lastTriggered! < duration.inMilliseconds) {
          return;
        }
      }
      notifyListeners();
    });
  }

  void tearDownBlinkTimer() {
    if (_blinkTimer == null) {
      return;
    }
    _blinkTimer?.cancel();
    _blinkTimer = null;
  }

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

  void incrementFailedReconnectCount() {
    _failedReconnectCount++;
  }

  void resetFailedReconnectCount() {
    if (_failedReconnectCount != 0) {
      _failedReconnectCount = 0;
    }
  }

  int get failedReconnectCount => _failedReconnectCount;

  void resetVarsForNewAcquisition() {
    _lastConnectionState = null;
    _plotReply = null;
    lastStreamError = null;
    _failedReconnectCount = 0;
    _lastTriggered = null;
    tearDownBlinkTimer();
    notifyListeners();
  }

  @override
  void notifyListeners() {
    _lastTriggered = DateTime.now().millisecondsSinceEpoch.toDouble();
    super.notifyListeners();
  }
}
