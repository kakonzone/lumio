import '../models/model.dart';

/// Legacy hook — channels now come from GitHub playlist only.
class UserPasteChannels {
  UserPasteChannels._();

  static List<ChannelModel> get all => const [];
}
