import 'package:flutter/material.dart';

class AccountIconOption {
  const AccountIconOption({required this.key, required this.icon});

  final String key;
  final IconData icon;
}

const List<AccountIconOption> accountIconOptions = <AccountIconOption>[
  AccountIconOption(key: 'card', icon: Icons.credit_card_outlined),
  AccountIconOption(key: 'wallet', icon: Icons.account_balance_wallet_outlined),
  AccountIconOption(key: 'tag', icon: Icons.sell_outlined),
  AccountIconOption(key: 'gift', icon: Icons.wallet_giftcard_outlined),
  AccountIconOption(key: 'bank', icon: Icons.account_balance_outlined),
  AccountIconOption(key: 'cash', icon: Icons.payments_outlined),
];

IconData resolveAccountIcon(String key) {
  return accountIconOptions
      .firstWhere(
        (option) => option.key == key,
        orElse: () => accountIconOptions.first,
      )
      .icon;
}
