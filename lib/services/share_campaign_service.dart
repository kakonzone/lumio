import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'attribution_service.dart';

/// Viral share link for sideload distribution (Facebook / WhatsApp / Telegram).
class ShareCampaignService {
  ShareCampaignService._();

  static String buildCampaignLink({
    String source = 'app_share',
    String campaign = 'wc2026',
    String tab = 'sports',
  }) {
    final q = <String, String>{
      'source': source,
      'campaign': campaign,
      if (tab.isNotEmpty) 'tab': tab,
    };
    final query = q.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    return 'lumio://open?$query';
  }

  static Future<void> copyCampaignLink(BuildContext context) async {
    final link = buildCampaignLink();
    await Clipboard.setData(ClipboardData(text: link));
    await AttributionService.instance.handleUri(Uri.parse(link));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite link copied — share on Facebook, WhatsApp, or Telegram'),
        duration: Duration(seconds: 3),
      ),
    );
  }
}
