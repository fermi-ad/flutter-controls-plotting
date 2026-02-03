import 'package:flutter/material.dart';

enum ChannelStatusType {
  OK,
  WARN,
  ERROR,
}

class ChannelStatus extends ChangeNotifier {
  // Status code of null means the channel hasn't been addressed yet.
  int? statusCode;
  String? statusMessage;
  ChannelStatusType statusType = ChannelStatusType.OK;

  ChannelStatus();

  void clearError() {
    if (statusCode != 0 || statusMessage != null || statusType != ChannelStatusType.OK) {
      statusCode = 0;
      statusMessage = null;
      statusType = ChannelStatusType.OK;
      Future.delayed(Duration.zero, () => {notifyListeners()});
    }
  }

  void setError(int code, [String? message]) {
    statusCode = code;
    statusMessage = message;
    statusType = ChannelStatusType.ERROR;
    Future.delayed(Duration.zero, () => {notifyListeners()});
  }

  void setWarning(int code, [String? message]) {
    statusCode = code;
    statusMessage = message;
    statusType = ChannelStatusType.WARN;
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
