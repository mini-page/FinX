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

IconData resolveSubscriptionIcon(String key) {
  return subscriptionIconOptions
      .firstWhere(
        (option) => option.key == key,
        orElse: () => subscriptionIconOptions.first,
      )
      .icon;
}
