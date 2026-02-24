import 'package:flutter_controls_plotting/entities/channel_status.dart';
import 'package:flutter_controls_plotting/entities/channel_setting.dart';

/// Metadata container for a channel that includes settings and optional error state
class ChannelMetadata {
  final ChannelSetting channelSetting;
  ChannelStatus channelStatus;

  ChannelMetadata({required this.channelSetting})
    : channelStatus = ChannelStatus();
}
