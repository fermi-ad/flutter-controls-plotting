import 'package:flutter/material.dart';

enum ChannelStatusType { ok, warn, error }

class ChannelStatus extends ChangeNotifier {
  // Status code of null means the channel hasn't been addressed yet.
  int? statusCode;
  String? statusMessage;
  ChannelStatusType statusType = ChannelStatusType.ok;

  ChannelStatus();

  void clearError() {
    if (statusCode != 0 ||
        statusMessage != null ||
        statusType != ChannelStatusType.ok) {
      statusCode = 0;
      statusMessage = null;
      statusType = ChannelStatusType.ok;
      Future.delayed(Duration.zero, () => {notifyListeners()});
    }
  }

  void setError(int code, [String? message]) {
    statusCode = code;
    statusMessage = message;
    statusType = ChannelStatusType.error;
    Future.delayed(Duration.zero, () => {notifyListeners()});
  }

  void setWarning(int code, [String? message]) {
    statusCode = code;
    statusMessage = message;
    statusType = ChannelStatusType.warn;
    Future.delayed(Duration.zero, () => {notifyListeners()});
  }

  @override
  String toString() {
    if (statusCode == 0) {
      return 'ChannelStatus(statusCode: $statusCode, statusType: $statusType)';
    }
    final message = statusMessage ?? 'Unknown error';
    return 'ChannelError(statusCode: $statusCode, statusMessage: $message, statusType: $statusType)';
  }
}
