import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'package:xpens/core/theme/app_colors.dart';
import 'package:xpens/features/expense/data/models/expense_model.dart';
import 'package:xpens/features/expense/presentation/provider/expense_providers.dart';
import 'package:xpens/features/settings/presentation/provider/preferences_providers.dart';
import 'package:xpens/routes/app_routes.dart';
import 'package:xpens/shared/widgets/app_page_header.dart';
import 'package:xpens/shared/widgets/app_search_bar.dart';

class _DistanceExpensePair {
  final ExpenseModel expense;
  final double distance;

  _DistanceExpensePair(this.expense, this.distance);
}

class LocationMapScreen extends ConsumerStatefulWidget {
  const LocationMapScreen({super.key});

  @override
  ConsumerState<LocationMapScreen> createState() => _LocationMapScreenState();
}

class _LocationMapScreenState extends ConsumerState<LocationMapScreen> {
  Position? _currentPosition;
  bool _isFetchingLocation = true;
  bool _hasPermission = false;
  double _radarRadiusKm = 5.0;
  ExpenseModel? _selectedTransaction;
  bool _visualMode = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    setState(() {
      _isFetchingLocation = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isFetchingLocation = false;
          _hasPermission = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isFetchingLocation = false;
            _hasPermission = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isFetchingLocation = false;
          _hasPermission = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _hasPermission = true;
        _isFetchingLocation = false;
      });
    } catch (_) {
      setState(() {
        _isFetchingLocation = false;
        _hasPermission = false;
      });
    }
  }

  IconData _getCategoryIcon(String category, TransactionType type) {
    if (type == TransactionType.transfer) return Icons.swap_horiz_rounded;
    final catLower = category.toLowerCase();
    if (catLower.contains('food') || catLower.contains('restaurant') || catLower.contains('cafe')) {
      return Icons.restaurant_rounded;
    }
    if (catLower.contains('travel') || catLower.contains('car') || catLower.contains('uber') || catLower.contains('transport')) {
      return Icons.directions_car_rounded;
    }
    if (catLower.contains('shopping') || catLower.contains('shop') || catLower.contains('clothing')) {
      return Icons.shopping_bag_rounded;
    }
    if (catLower.contains('bill') || catLower.contains('rent') || catLower.contains('utility') || catLower.contains('electricity')) {
      return Icons.receipt_long_rounded;
    }
    if (catLower.contains('salary') || catLower.contains('income') || catLower.contains('paycheck')) {
      return Icons.account_balance_rounded;
    }
    if (catLower.contains('entertainment') || catLower.contains('movie') || catLower.contains('game')) {
      return Icons.videogame_asset_rounded;
    }
    if (catLower.contains('health') || catLower.contains('medical') || catLower.contains('doctor')) {
      return Icons.medical_services_rounded;
    }
    if (catLower.contains('education') || catLower.contains('book') || catLower.contains('school')) {
      return Icons.school_rounded;
    }
    return type == TransactionType.income ? Icons.add_circle_outline_rounded : Icons.payments_rounded;
  }

  Color _getCategoryColor(String category, TransactionType type) {
    if (type == TransactionType.transfer) return const Color(0xFFF59E0B); // Amber
    if (type == TransactionType.income) return const Color(0xFF10B981); // Green
    final catLower = category.toLowerCase();
    if (catLower.contains('food') || catLower.contains('restaurant') || catLower.contains('cafe')) {
      return const Color(0xFFF97316); // Orange
    }
    if (catLower.contains('travel') || catLower.contains('car') || catLower.contains('uber') || catLower.contains('transport')) {
      return const Color(0xFF06B6D4); // Cyan
    }
    if (catLower.contains('shopping') || catLower.contains('shop') || catLower.contains('clothing')) {
      return const Color(0xFFEC4899); // Pink
    }
    if (catLower.contains('bill') || catLower.contains('rent') || catLower.contains('utility')) {
      return const Color(0xFF8B5CF6); // Purple
    }
    return AppColors.primaryBlue;
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expenseListProvider);
    final currencySymbol = ref.watch(currencySymbolProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: GradientAppBar(
        title: 'Location Mapping',
        actions: [
          IconButton(
            icon: Icon(
              _visualMode ? Icons.list_alt_rounded : Icons.radar_rounded,
              color: AppColors.primaryBlue,
            ),
            onPressed: () {
              setState(() {
                _visualMode = !_visualMode;
              });
            },
            tooltip: _visualMode ? 'Switch to List' : 'Switch to Radar Map',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _initLocation,
            tooltip: 'Refresh Location',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Panel
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: AppSearchBar(
                    controller: _searchController,
                    hintText: 'Search location notes or categories...',
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim().toLowerCase();
                      });
                    },
                    onClear: () {
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          // Main View Body
          Expanded(
            child: _buildMainContent(expensesAsync, currencySymbol),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(AsyncValue<List<ExpenseModel>> expensesAsync, String currencySymbol) {
    if (_isFetchingLocation) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Acquiring GPS position...',
              style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    if (!_hasPermission || _currentPosition == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_off_rounded,
                  size: 48,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Location Access Required',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enable GPS and grant location permissions to map your logged transactions relative to where you are standing.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _initLocation,
                icon: const Icon(Icons.gps_fixed_rounded),
                label: const Text('Enable Location Tracking'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Filter location-tagged expenses
    final allExpenses = expensesAsync.value ?? [];
    final locationExpenses = allExpenses.where((e) {
      if (e.latitude == null || e.longitude == null) return false;
      if (_searchQuery.isEmpty) return true;
      final categoryMatch = e.category.toLowerCase().contains(_searchQuery);
      final noteMatch = e.note.toLowerCase().contains(_searchQuery);
      final subcategoryMatch = e.subcategory?.toLowerCase().contains(_searchQuery) ?? false;
      return categoryMatch || noteMatch || subcategoryMatch;
    }).toList();

    if (locationExpenses.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on_outlined, size: 40, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text(
              'No location-tagged transactions found.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // Process distances
    final currentPos = _currentPosition!;
    final pairs = locationExpenses.map((txn) {
      final distance = Geolocator.distanceBetween(
        currentPos.latitude,
        currentPos.longitude,
        txn.latitude!,
        txn.longitude!,
      );
      return _DistanceExpensePair(txn, distance);
    }).toList();

    // Sort by proximity
    pairs.sort((a, b) => a.distance.compareTo(b.distance));

    if (!_visualMode) {
      return _buildListView(pairs, currencySymbol);
    }

    return _buildRadarView(pairs, currencySymbol);
  }

  Widget _buildRadarView(List<_DistanceExpensePair> pairs, String currencySymbol) {
    // Collect transactions inside selected radius limits
    final maxDistMeters = _radarRadiusKm * 1000.0;
    final inRangePairs = pairs.where((p) => p.distance <= maxDistMeters).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Radius selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Sonar Radar Range',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              DropdownButton<double>(
                value: _radarRadiusKm,
                elevation: 4,
                underline: const SizedBox(),
                dropdownColor: Colors.white,
                style: const TextStyle(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _radarRadiusKm = val;
                      _selectedTransaction = null;
                    });
                  }
                },
                items: const [
                  DropdownMenuItem(value: 0.5, child: Text('500 m')),
                  DropdownMenuItem(value: 1.0, child: Text('1 km')),
                  DropdownMenuItem(value: 5.0, child: Text('5 km')),
                  DropdownMenuItem(value: 10.0, child: Text('10 km')),
                  DropdownMenuItem(value: 50.0, child: Text('50 km')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Radar view container
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.cardShadow,
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  LocationRadarWidget(
                    currentPosition: _currentPosition!,
                    transactions: inRangePairs.map((p) => p.expense).toList(),
                    radarRadiusKm: _radarRadiusKm,
                    selectedTransaction: _selectedTransaction,
                    onSelect: (txn) {
                      setState(() {
                        _selectedTransaction = txn;
                      });
                    },
                  ),
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xCC0F172A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Pockets in range: ${inRangePairs.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Tapped pin preview card
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _selectedTransaction != null
                ? _buildSelectedPreviewCard(_selectedTransaction!, currencySymbol)
                : Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.radar_rounded, size: 28, color: AppColors.textMuted),
                        SizedBox(height: 8),
                        Text(
                          'Tap any pin on the radar map above to inspect transaction records logged at that spot.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedPreviewCard(ExpenseModel txn, String currencySymbol) {
    final isIncome = txn.type == TransactionType.income;
    final isTransfer = txn.type == TransactionType.transfer;
    final catColor = _getCategoryColor(txn.category, txn.type);
    final distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      txn.latitude!,
      txn.longitude!,
    );
    final distanceText = distance < 1000
        ? '${distance.toStringAsFixed(0)} m away'
        : '${(distance / 1000.0).toStringAsFixed(1)} km away';

    return Container(
      key: ValueKey(txn.id),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: catColor.withOpacity(0.3), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: catColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getCategoryIcon(txn.category, txn.type),
                  color: catColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isTransfer ? 'Transfer' : txn.category,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('dd MMM yyyy, hh:mm a').format(txn.date.toLocal()),
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Text(
                '${isIncome ? "+" : "-"}$currencySymbol${txn.amount.toStringAsFixed(0)}',
                style: TextStyle(
                  color: isTransfer
                      ? AppColors.textDark
                      : isIncome
                          ? AppColors.success
                          : AppColors.danger,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (txn.note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                txn.note,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    distanceText,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () async {
                  await AppRoutes.pushEditExpense(
                    context,
                    expenseId: txn.id,
                    initialAmount: txn.amount,
                    initialCategory: txn.category,
                    initialDate: txn.date.toLocal(),
                    initialNote: txn.note,
                    initialAccountId: txn.accountId,
                    initialToAccountId: txn.toAccountId,
                    initialType: txn.type,
                    initialSubcategory: txn.subcategory,
                    initialLatitude: txn.latitude,
                    initialLongitude: txn.longitude,
                  );
                  // Refresh state on return
                  setState(() {});
                },
                icon: const Icon(Icons.edit_rounded, size: 14),
                label: const Text('Edit Transaction', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListView(List<_DistanceExpensePair> pairs, String currencySymbol) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: pairs.length,
      itemBuilder: (context, index) {
        final pair = pairs[index];
        final txn = pair.expense;
        final isIncome = txn.type == TransactionType.income;
        final isTransfer = txn.type == TransactionType.transfer;
        final catColor = _getCategoryColor(txn.category, txn.type);
        final distanceText = pair.distance < 1000
            ? '${pair.distance.toStringAsFixed(0)} m away'
            : '${(pair.distance / 1000.0).toStringAsFixed(1)} km away';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                await AppRoutes.pushEditExpense(
                  context,
                  expenseId: txn.id,
                  initialAmount: txn.amount,
                  initialCategory: txn.category,
                  initialDate: txn.date.toLocal(),
                  initialNote: txn.note,
                  initialAccountId: txn.accountId,
                  initialToAccountId: txn.toAccountId,
                  initialType: txn.type,
                  initialSubcategory: txn.subcategory,
                  initialLatitude: txn.latitude,
                  initialLongitude: txn.longitude,
                );
                setState(() {});
              },
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: catColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getCategoryIcon(txn.category, txn.type),
                        color: catColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                isTransfer ? 'Transfer' : txn.category,
                                style: const TextStyle(
                                  color: AppColors.textDark,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.backgroundLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.location_on, size: 10, color: AppColors.textMuted),
                                    const SizedBox(width: 2),
                                    Text(
                                      distanceText,
                                      style: const TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            txn.note.isNotEmpty ? txn.note : 'No description',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: txn.note.isNotEmpty ? AppColors.textSecondary : AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${isIncome ? "+" : "-"}$currencySymbol${txn.amount.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: isTransfer
                                ? AppColors.textDark
                                : isIncome
                                    ? AppColors.success
                                    : AppColors.danger,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('dd MMM').format(txn.date.toLocal()),
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class LocationRadarWidget extends StatefulWidget {
  final Position currentPosition;
  final List<ExpenseModel> transactions;
  final double radarRadiusKm;
  final ExpenseModel? selectedTransaction;
  final Function(ExpenseModel) onSelect;

  const LocationRadarWidget({
    super.key,
    required this.currentPosition,
    required this.transactions,
    required this.radarRadiusKm,
    required this.selectedTransaction,
    required this.onSelect,
  });

  @override
  State<LocationRadarWidget> createState() => _LocationRadarWidgetState();
}

class _LocationRadarWidgetState extends State<LocationRadarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return GestureDetector(
          onTapUp: (details) {
            final size = context.size;
            if (size == null) return;
            final center = Offset(size.width / 2, size.height / 2);
            final radius = size.width / 2;
            final localOffset = details.localPosition;

            final maxDistance = widget.radarRadiusKm * 1000.0;
            final scale = radius / maxDistance;

            ExpenseModel? tappedTxn;
            double minDistance = 24.0; // Click hitbox in pixels

            for (final txn in widget.transactions) {
              if (txn.latitude == null || txn.longitude == null) continue;

              final dy = (txn.latitude! - widget.currentPosition.latitude) * 111320.0;
              final dx = (txn.longitude! - widget.currentPosition.longitude) *
                  111320.0 *
                  cos(widget.currentPosition.latitude * pi / 180.0);

              final distance = sqrt(dx * dx + dy * dy);
              if (distance > maxDistance) continue;

              final plotX = center.dx + dx * scale;
              final plotY = center.dy - dy * scale;

              final clickDist = sqrt(
                pow(localOffset.dx - plotX, 2) + pow(localOffset.dy - plotY, 2),
              );

              if (clickDist < minDistance) {
                tappedTxn = txn;
                minDistance = clickDist;
              }
            }

            if (tappedTxn != null) {
              widget.onSelect(tappedTxn);
            }
          },
          child: CustomPaint(
            size: const Size(double.infinity, double.infinity),
            painter: RadarPainter(
              currentPosition: widget.currentPosition,
              transactions: widget.transactions,
              radarRadiusKm: widget.radarRadiusKm,
              selectedTransaction: widget.selectedTransaction,
              sweepAngle: _animationController.value * 2 * pi,
            ),
          ),
        );
      },
    );
  }
}

class RadarPainter extends CustomPainter {
  final Position currentPosition;
  final List<ExpenseModel> transactions;
  final double radarRadiusKm;
  final ExpenseModel? selectedTransaction;
  final double sweepAngle;

  RadarPainter({
    required this.currentPosition,
    required this.transactions,
    required this.radarRadiusKm,
    required this.selectedTransaction,
    required this.sweepAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw dark radar background
    final bgPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // Draw concentric ring grids
    final ringPaint = Paint()
      ..color = const Color(0x223B82F6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, radius, ringPaint);
    canvas.drawCircle(center, radius * 0.75, ringPaint);
    canvas.drawCircle(center, radius * 0.50, ringPaint);
    canvas.drawCircle(center, radius * 0.25, ringPaint);

    // Draw vertical & horizontal crosshairs
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), ringPaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), ringPaint);

    // Draw sweep overlay
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          const Color(0x003B82F6),
          const Color(0x333B82F6),
          const Color(0x883B82F6),
        ],
        stops: const [0.0, 0.5, 0.9, 1.0],
        transform: GradientRotation(sweepAngle),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, sweepPaint);

    final maxDistance = radarRadiusKm * 1000.0;
    final scale = radius / maxDistance;

    // Draw pins
    for (final txn in transactions) {
      if (txn.latitude == null || txn.longitude == null) continue;

      final dy = (txn.latitude! - currentPosition.latitude) * 111320.0;
      final dx = (txn.longitude! - currentPosition.longitude) *
          111320.0 *
          cos(currentPosition.latitude * pi / 180.0);

      final distance = sqrt(dx * dx + dy * dy);
      if (distance > maxDistance) continue;

      final plotX = center.dx + dx * scale;
      final plotY = center.dy - dy * scale;

      final isSelected = selectedTransaction?.id == txn.id;

      Color nodeColor;
      if (txn.type == TransactionType.income) {
        nodeColor = const Color(0xFF10B981);
      } else if (txn.type == TransactionType.transfer) {
        nodeColor = const Color(0xFFF59E0B);
      } else {
        nodeColor = const Color(0xFF3B82F6);
      }

      if (isSelected) {
        final haloPaint = Paint()
          ..color = nodeColor.withOpacity(0.3)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(plotX, plotY), 16.0, haloPaint);

        final pulsePaint = Paint()
          ..color = nodeColor.withOpacity(0.15)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(plotX, plotY), 24.0, pulsePaint);
      } else {
        final auraPaint = Paint()
          ..color = nodeColor.withOpacity(0.12)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(plotX, plotY), 8.0, auraPaint);
      }

      final nodePaint = Paint()
        ..color = isSelected ? Colors.white : nodeColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(plotX, plotY), 5.0, nodePaint);

      final borderPaint = Paint()
        ..color = isSelected ? nodeColor : Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(Offset(plotX, plotY), 5.0, borderPaint);
    }

    // Draw center user marker (pulsing neon pink dot)
    final userHaloPaint = Paint()
      ..color = const Color(0xFFEC4899).withOpacity(0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 12.0, userHaloPaint);

    final userPaint = Paint()
      ..color = const Color(0xFFEC4899)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4.0, userPaint);

    final userBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, 4.0, userBorderPaint);

    // Draw ring range indicators (Text)
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    final textStyle = TextStyle(
      color: Colors.white.withOpacity(0.35),
      fontSize: 9,
      fontWeight: FontWeight.bold,
    );

    // Helper to draw text
    void drawText(String text, double offsetFromCenter) {
      textPainter.text = TextSpan(text: text, style: textStyle);
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(center.dx + 4, center.dy - offsetFromCenter - 12),
      );
    }

    final val25 = radarRadiusKm * 0.25;
    final val50 = radarRadiusKm * 0.50;
    final val75 = radarRadiusKm * 0.75;
    final val100 = radarRadiusKm;

    String formatVal(double val) {
      if (val < 1.0) {
        return '${(val * 1000).toStringAsFixed(0)}m';
      }
      return '${val.toStringAsFixed(1)}km';
    }

    drawText(formatVal(val25), radius * 0.25);
    drawText(formatVal(val50), radius * 0.50);
    drawText(formatVal(val75), radius * 0.75);
    drawText(formatVal(val100), radius);
  }

  @override
  bool shouldRepaint(covariant RadarPainter oldDelegate) {
    return oldDelegate.currentPosition != currentPosition ||
        oldDelegate.transactions != transactions ||
        oldDelegate.radarRadiusKm != radarRadiusKm ||
        oldDelegate.selectedTransaction != selectedTransaction ||
        oldDelegate.sweepAngle != sweepAngle;
  }
}
