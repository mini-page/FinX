import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_page_header.dart';
import '../../../../shared/widgets/app_tab_switcher.dart';
import 'accounts/tools_tab_widgets.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _selectedTab = 0;

  static const List<AppTabItem> _toolsTabs = <AppTabItem>[
    AppTabItem(label: 'Budget', icon: Icons.account_balance_outlined),
    AppTabItem(label: 'Goals', icon: Icons.flag_outlined),
    AppTabItem(label: 'Split', icon: Icons.call_split_rounded),
    AppTabItem(label: 'Recurring', icon: Icons.repeat_rounded),
    AppTabItem(label: 'Future', icon: Icons.schedule_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _toolsTabs.length, vsync: this);
    _tabController.addListener(() {
      final newIndex = _tabController.index;
      if (_selectedTab != newIndex) {
        setState(() => _selectedTab = newIndex);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppPageHeader(
          eyebrow: 'Tools',
          title: 'Financial Utilities',
          bottom: AppTabSwitcher(
            tabs: _toolsTabs,
            selected: _selectedTab,
            scrollable: true,
            onChanged: (index) {
              setState(() => _selectedTab = index);
              _tabController.animateTo(index);
            },
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            child: ToolsTabView(controller: _tabController),
          ),
        ),
      ],
    );
  }
}
