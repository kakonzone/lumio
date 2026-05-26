import '../models/model.dart';

/// Stable id for channel-tap ads + pending highlight (id or name fallback).
String channelTapKey(ChannelModel channel) =>
    channel.id.isNotEmpty ? channel.id : channel.name;
