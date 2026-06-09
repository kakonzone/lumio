import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/model.dart';
import '../provider/app_provider.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/colors.dart' as tokens;

/// Long-press confirmation to add a channel to favourites.
Future<bool> showAddFavoriteDialog(
  BuildContext context,
  ChannelModel channel,
) async {
  final prov = context.read<AppProvider>();
  if (prov.isFavorite(channel.id)) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${channel.name} already in favourites'),
        duration: const Duration(seconds: 2),
      ),
    );
    return false;
  }

  final add = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: ctx.bg2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: ctx.brd),
      ),
      title: Text(
        'Add Favourites',
        style: TextStyle(
          color: ctx.txt,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
      content: Text(
        'Are you sure, Add ${channel.name} to favourite?',
        style: TextStyle(color: ctx.txt2, fontSize: 14, height: 1.4),
      ),
      actionsAlignment: MainAxisAlignment.end,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Cancel', style: TextStyle(color: ctx.txt3)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(
            'Add',
            style: TextStyle(
              color: tokens.AppTokens.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  if (add != true || !context.mounted) return false;
  await prov.addFavorite(channel);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${channel.name} added to favourites'),
        backgroundColor: tokens.AppTokens.accent,
        duration: const Duration(seconds: 2),
      ),
    );
  }
  return true;
}
