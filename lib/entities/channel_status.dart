import 'package:flutter/material.dart';

class ChannelStatus extends ChangeNotifier {
  // Status code of null means the channel hasn't been addressed yet.
  int? statusCode;
  String? statusMessage;

  ChannelStatus();

  void clearError() {
    if (statusCode != 0 || statusMessage != null) {
      statusCode = 0;
      statusMessage = null;
      notifyListeners();
    }
  }

  void setError(int code, [String? message]) {
    statusCode = code;
    statusMessage = message;
    notifyListeners();
  }

  @override
  String toString() {
    if (statusCode == 0) {
      return 'ChannelStatus(statusCode: $statusCode)';
    }
    final message = statusMessage ?? 'Unknown error';
    return 'ChannelError(statusCode: $statusCode, statusMessage: $message)';
  }
}
