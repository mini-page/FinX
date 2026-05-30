import 'package:flutter/material.dart';
import 'package:xpens/core/theme/app_colors.dart';
import 'app_search_bar.dart';

class AppCurrencyDetails {
  const AppCurrencyDetails({
    required this.symbol,
    required this.name,
    required this.code,
    required this.country,
    required this.flag,
  });

  final String symbol;
  final String name;
  final String code;
  final String country;
  final String flag;
}

const List<AppCurrencyDetails> richCurrencies = [
  AppCurrencyDetails(symbol: '₹', name: 'Indian Rupee', code: 'INR', country: 'India', flag: '🇮🇳'),
  AppCurrencyDetails(symbol: r'$', name: 'US Dollar', code: 'USD', country: 'United States', flag: '🇺🇸'),
  AppCurrencyDetails(symbol: '€', name: 'Euro', code: 'EUR', country: 'Eurozone', flag: '🇪🇺'),
  AppCurrencyDetails(symbol: '£', name: 'British Pound', code: 'GBP', country: 'United Kingdom', flag: '🇬🇧'),
  AppCurrencyDetails(symbol: 'د.إ', name: 'UAE Dirham', code: 'AED', country: 'United Arab Emirates', flag: '🇦🇪'),
  AppCurrencyDetails(symbol: '¥', name: 'Japanese Yen', code: 'JPY', country: 'Japan', flag: '🇯🇵'),
  AppCurrencyDetails(symbol: '৳', name: 'Bangladeshi Taka', code: 'BDT', country: 'Bangladesh', flag: '🇧🇩'),
  AppCurrencyDetails(symbol: 'S\$', name: 'Singapore Dollar', code: 'SGD', country: 'Singapore', flag: '🇸🇬'),
  AppCurrencyDetails(symbol: 'A\$', name: 'Australian Dollar', code: 'AUD', country: 'Australia', flag: '🇦🇺'),
  AppCurrencyDetails(symbol: 'C\$', name: 'Canadian Dollar', code: 'CAD', country: 'Canada', flag: '🇨🇦'),
  AppCurrencyDetails(symbol: 'CHF', name: 'Swiss Franc', code: 'CHF', country: 'Switzerland', flag: '🇨🇭'),
  AppCurrencyDetails(symbol: '元', name: 'Chinese Yuan', code: 'CNY', country: 'China', flag: '🇨🇳'),
  AppCurrencyDetails(symbol: 'HK\$', name: 'Hong Kong Dollar', code: 'HKD', country: 'Hong Kong', flag: '🇭🇰'),
  AppCurrencyDetails(symbol: 'NZ\$', name: 'New Zealand Dollar', code: 'NZD', country: 'New Zealand', flag: '🇳🇿'),
  AppCurrencyDetails(symbol: 'kr', name: 'Swedish Krona', code: 'SEK', country: 'Sweden', flag: '🇸🇪'),
  AppCurrencyDetails(symbol: '₩', name: 'South Korean Won', code: 'KRW', country: 'South Korea', flag: '🇰🇷'),
  AppCurrencyDetails(symbol: '₿', name: 'Bitcoin', code: 'BTC', country: 'Crypto', flag: '🪙'),
];

Future<String?> showCurrencySelectorSheet(BuildContext context, String currentCurrencySymbol) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) {
      return _CurrencySelectorSheet(currentCurrencySymbol: currentCurrencySymbol);
    },
  );
}

class _CurrencySelectorSheet extends StatefulWidget {
  const _CurrencySelectorSheet({required this.currentCurrencySymbol});

  final String currentCurrencySymbol;

  @override
  State<_CurrencySelectorSheet> createState() => _CurrencySelectorSheetState();
}

class _CurrencySelectorSheetState extends State<_CurrencySelectorSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    
    final filtered = richCurrencies.where((c) {
      if (_searchQuery.isEmpty) return true;
      return c.name.toLowerCase().contains(_searchQuery) ||
             c.code.toLowerCase().contains(_searchQuery) ||
             c.country.toLowerCase().contains(_searchQuery) ||
             c.symbol.toLowerCase().contains(_searchQuery);
    }).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Header
          const Text(
            'Transaction currency',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Set your preferred display currency.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),

          // Search Bar
          AppSearchBar(
            controller: _searchController,
            hintText: 'Search USD, EUR, GBP, BTC...',
            hasBorder: true,
          ),
          const SizedBox(height: 16),

          // Currencies List
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: filtered.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Text(
                        'No currencies match your search.',
                        style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final c = filtered[index];
                      final isSelected = c.symbol == widget.currentCurrencySymbol;

                      return GestureDetector(
                        onTap: () => Navigator.pop(context, c.symbol),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primaryBlue.withOpacity(0.04) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? AppColors.primaryBlue : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Left symbol circle
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primaryBlue.withOpacity(0.1) : const Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  c.symbol,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: isSelected ? AppColors.primaryBlue : AppColors.textDark,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Middle name/country
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      c.country,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Right code, flag, checkmark
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    c.code,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        c.flag,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      if (isSelected) ...[
                                        const SizedBox(width: 6),
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color: AppColors.primaryBlue,
                                          size: 16,
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
