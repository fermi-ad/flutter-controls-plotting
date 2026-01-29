class ChannelStatus {
  final int statusCode;
  final String? statusMessage;

  const ChannelStatus({required this.statusCode, this.statusMessage});

  @override
  String toString() {
    final message = statusMessage ?? 'Unknown error';
    return 'ChannelError(statusCode: $statusCode, statusMessage: $message)';
  }
}
