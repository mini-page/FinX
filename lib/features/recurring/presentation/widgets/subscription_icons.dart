import 'package:flutter/material.dart';

class SubscriptionIconOption {
  const SubscriptionIconOption({required this.key, required this.icon});

  final String key;
  final IconData icon;
}

const List<SubscriptionIconOption> subscriptionIconOptions =
    <SubscriptionIconOption>[
  SubscriptionIconOption(key: 'tv', icon: Icons.tv_rounded),
  SubscriptionIconOption(key: 'music', icon: Icons.music_note_rounded),
  SubscriptionIconOption(key: 'video', icon: Icons.play_circle_outline_rounded),
  SubscriptionIconOption(key: 'cloud', icon: Icons.cloud_outlined),
  SubscriptionIconOption(key: 'fitness', icon: Icons.fitness_center_rounded),
  SubscriptionIconOption(key: 'news', icon: Icons.newspaper_rounded),
];

Widget resolveSubscriptionIcon(String key, {Color? color, double size = 16}) {
  // Check if key contains non-ASCII characters (indicating it is an emoji)
  final isEmoji = key.runes.any((r) => r > 127);
  if (isEmoji) {
    return Center(
      child: Text(
        key,
        style: TextStyle(fontSize: size),
      ),
    );
  }

  final iconData = subscriptionIconOptions
      .firstWhere(
        (option) => option.key == key,
        orElse: () => subscriptionIconOptions.first,
      )
      .icon;
  return Icon(iconData, color: color, size: size);
}
