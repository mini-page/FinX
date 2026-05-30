import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:xpens/core/theme/app_colors.dart';
import 'package:xpens/core/theme/app_tokens.dart';
import 'package:xpens/features/settings/presentation/provider/preferences_providers.dart';
import 'package:xpens/shared/widgets/app_search_bar.dart';

class SplitBillToolView extends ConsumerStatefulWidget {
  const SplitBillToolView({super.key});

  @override
  ConsumerState<SplitBillToolView> createState() => _SplitBillToolViewState();
}

class _SplitBillToolViewState extends ConsumerState<SplitBillToolView> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  
  Box? _splitBox;
  bool _isLoading = true;
  bool _hasPermission = false;
  
  List<String> _contactsGallery = [];
  List<String> _customContacts = [];
  List<String> _selectedGalleryPeople = [];
  List<String> _activeSplitMembers = [];
  
  String _searchQuery = '';
  String _whoPaid = 'You';
  String _splitMethod = 'Equal'; // 'Equal' or 'Exact'
  bool _showEditGallery = false;
  
  final Map<String, double> _exactAmounts = {};
  
  final List<String> _mockPhoneContacts = [
    'Aleem',
    'Rahul',
    'Priya',
    'Ajay',
    'Umang',
    'Sneha',
    'Karan',
    'Aditya',
    'Vikram',
    'Neha',
    'Rohan',
    'Simran',
  ];

  @override
  void initState() {
    super.initState();
    _initHiveAndPermission();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initHiveAndPermission() async {
    _splitBox = await Hive.openBox('split_bill_box');
    
    // Load contacts gallery
    final savedGallery = _splitBox?.get('gallery_contacts');
    if (savedGallery != null) {
      _contactsGallery = List<String>.from(savedGallery as List);
    } else {
      _contactsGallery = ['Aleem', 'Rahul', 'Priya']; // default mockups
    }
    
    // Load custom contacts
    final savedCustom = _splitBox?.get('custom_contacts');
    if (savedCustom != null) {
      _customContacts = List<String>.from(savedCustom as List);
    }
    
    // Check permission status
    final status = await Permission.contacts.status;
    setState(() {
      _hasPermission = status.isGranted || _splitBox?.get('manual_bypass', defaultValue: false) == true;
      _activeSplitMembers = ['You', ..._contactsGallery];
      _isLoading = false;
    });
  }

  Future<void> _requestContactPermission() async {
    final status = await Permission.contacts.request();
    if (status.isGranted) {
      setState(() {
        _hasPermission = true;
      });
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            title: const Text('Permission Required', style: TextStyle(fontWeight: FontWeight.bold)),
            content: const Text('Please enable contacts permission in settings to access your phone contacts, or continue manually.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await openAppSettings();
                },
                child: const Text('Open Settings', style: TextStyle(color: AppColors.primaryBlue)),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _splitBox?.put('manual_bypass', true);
                  setState(() {
                    _hasPermission = true;
                  });
                },
                style: FilledButton.styleFrom(backgroundColor: AppColors.primaryBlue),
                child: const Text('Bypass Manually'),
              ),
            ],
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contacts permission denied. You can add friends manually.')),
      );
    }
  }

  List<String> _filterContacts(String query) {
    final allList = <String>{..._mockPhoneContacts, ..._customContacts};
    if (query.isEmpty) {
      return allList.toList()..sort();
    }
    final lowercaseQuery = query.toLowerCase();
    return allList
        .where((name) => name.toLowerCase().contains(lowercaseQuery))
        .toList()
      ..sort();
  }

  void _addNewCustomContact(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      if (!_customContacts.contains(trimmed)) {
        _customContacts.add(trimmed);
        _splitBox?.put('custom_contacts', _customContacts);
      }
      if (!_selectedGalleryPeople.contains(trimmed)) {
        _selectedGalleryPeople.add(trimmed);
      }
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _saveGallerySelection() {
    setState(() {
      _contactsGallery = List<String>.from(_selectedGalleryPeople);
      _splitBox?.put('gallery_contacts', _contactsGallery);
      _showEditGallery = false;
      _activeSplitMembers = ['You', ..._contactsGallery];
      
      // Keep _whoPaid valid
      if (!_activeSplitMembers.contains(_whoPaid)) {
        _whoPaid = 'You';
      }
      
      // Clear inputs
      _exactAmounts.clear();
    });
  }

  void _applySplit() {
    // Show success dialog and reset
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Split Applied', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Expense of ${ref.read(currencyFormatProvider).format(double.tryParse(_amountController.text) ?? 0)} has been split among ${_activeSplitMembers.length} people.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _amountController.clear();
                _exactAmounts.clear();
              });
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionScreen() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFEDF2F7), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_alt_rounded,
              size: 36,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Access Contacts',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select friends from your phone contacts to quickly split expenses. Setup is done only once.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _requestContactPermission,
              icon: const Icon(Icons.contact_phone_rounded, size: 18),
              label: const Text('Grant Contact Access', style: TextStyle(fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () async {
              await _splitBox?.put('manual_bypass', true);
              setState(() {
                _hasPermission = true;
              });
            },
            child: const Text(
              'Add People Manually',
              style: TextStyle(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditGalleryView() {
    final searchResults = _filterContacts(_searchQuery);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFEDF2F7), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textDark),
                onPressed: () {
                  setState(() {
                    _showEditGallery = false;
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
              ),
              const Text(
                'Select Friends',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppSearchBar(
            controller: _searchController,
            hintText: 'Search contacts or type name...',
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
            onClear: () {
              setState(() {
                _searchQuery = '';
              });
            },
          ),
          const SizedBox(height: 16),
          
          if (_searchQuery.trim().isNotEmpty && 
              !searchResults.any((s) => s.toLowerCase() == _searchQuery.trim().toLowerCase()))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => _addNewCustomContact(_searchQuery),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryBlue, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Add "${_searchQuery.trim()}" manually',
                          style: const TextStyle(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          const Text(
            'ALL CONTACTS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: searchResults.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEDF2F7)),
              itemBuilder: (context, index) {
                final name = searchResults[index];
                final isSelected = _selectedGalleryPeople.contains(name);
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 15,
                    backgroundColor: const Color(0xFFF1F5F9),
                    child: Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                      fontSize: 13,
                    ),
                  ),
                  trailing: Checkbox(
                    value: isSelected,
                    activeColor: AppColors.primaryBlue,
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _selectedGalleryPeople.add(name);
                        } else {
                          _selectedGalleryPeople.remove(name);
                        }
                      });
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _saveGallerySelection,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Save & Continue',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainSplitView() {
    final currency = ref.watch(currencyFormatProvider);
    final symbol = ref.watch(currencySymbolProvider);
    final totalAmount = double.tryParse(_amountController.text) ?? 0.0;
    
    // Calculations
    final perPersonEqual = _activeSplitMembers.isEmpty ? 0.0 : totalAmount / _activeSplitMembers.length;
    
    double sumAssigned = 0.0;
    if (_splitMethod == 'Equal') {
      sumAssigned = totalAmount;
    } else {
      sumAssigned = _activeSplitMembers.fold(0.0, (sum, name) => sum + (_exactAmounts[name] ?? 0.0));
    }
    
    final diff = totalAmount - sumAssigned;
    final isMatched = totalAmount > 0 && diff.abs() < 0.01;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFEDF2F7), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total Amount Field
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textDark),
            decoration: InputDecoration(
              labelText: 'Total amount to split',
              labelStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w600),
              hintText: '0',
              prefixText: '$symbol ',
              prefixStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textDark),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),

          // People Context Gallery Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Split Partners',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedGalleryPeople = List<String>.from(_contactsGallery);
                    _showEditGallery = true;
                  });
                },
                icon: const Icon(Icons.edit_rounded, size: 14),
                label: const Text('Manage', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryBlue,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Horizontal contacts row
          SizedBox(
            height: 52,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _activeSplitMembers.length,
              itemBuilder: (context, idx) {
                final name = _activeSplitMembers[idx];
                final isYou = name == 'You';
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Tooltip(
                    message: name,
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: isYou ? AppColors.primaryBlue : const Color(0xFFF1F5F9),
                      child: Text(
                        isYou ? 'Y' : name[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isYou ? Colors.white : AppColors.textDark,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          // Subtext showing list of names
          Text(
            'Recent: ${_activeSplitMembers.join(", ")}',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),

          // Who Paid Dropdown
          DropdownButtonFormField<String>(
            value: _whoPaid,
            dropdownColor: Colors.white,
            items: _activeSplitMembers.map((name) {
              return DropdownMenuItem<String>(
                value: name,
                child: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textDark),
                ),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                _whoPaid = val ?? 'You';
              });
            },
            decoration: InputDecoration(
              labelText: 'Who paid?',
              labelStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
          const SizedBox(height: 20),

          // Split Method Switch
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _splitMethod = 'Equal'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _splitMethod == 'Equal' ? AppColors.lightBlueBg : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _splitMethod == 'Equal' ? AppColors.primaryBlue : const Color(0xFFE2E8F0),
                        width: _splitMethod == 'Equal' ? 2 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Equal',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _splitMethod == 'Equal' ? AppColors.primaryBlue : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _splitMethod = 'Exact'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _splitMethod == 'Exact' ? AppColors.lightBlueBg : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _splitMethod == 'Exact' ? AppColors.primaryBlue : const Color(0xFFE2E8F0),
                        width: _splitMethod == 'Exact' ? 2 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Exact',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _splitMethod == 'Exact' ? AppColors.primaryBlue : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Share List Container
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: _activeSplitMembers.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, idx) {
                final name = _activeSplitMembers[idx];
                final isYou = name == 'You';
                final double shareVal = _splitMethod == 'Equal' 
                    ? perPersonEqual 
                    : (_exactAmounts[name] ?? 0.0);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: isYou ? AppColors.primaryBlue.withOpacity(0.1) : const Color(0xFFE2E8F0),
                        child: Text(
                          isYou ? 'Y' : name[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isYou ? AppColors.primaryBlue : AppColors.textDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark),
                        ),
                      ),
                      
                      // Share inputs or values
                      if (_splitMethod == 'Equal')
                        Text(
                          currency.format(shareVal),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.textDark),
                        )
                      else
                        SizedBox(
                          width: 80,
                          height: 36,
                          child: TextField(
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.end,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.textDark),
                            decoration: InputDecoration(
                              prefixText: symbol,
                              prefixStyle: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: AppColors.primaryBlue),
                              ),
                            ),
                            controller: TextEditingController(
                              text: _exactAmounts[name] == null ? '' : _exactAmounts[name]!.toStringAsFixed(0),
                            )..selection = TextSelection.fromPosition(
                                TextPosition(offset: _exactAmounts[name] == null ? 0 : _exactAmounts[name]!.toStringAsFixed(0).length),
                              ),
                            onChanged: (val) {
                              final dVal = double.tryParse(val) ?? 0.0;
                              _exactAmounts[name] = dVal;
                              setState(() {});
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // Assigned Banner
          if (totalAmount > 0)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMatched ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isMatched 
                      ? const Color(0xFF10B981).withOpacity(0.2) 
                      : const Color(0xFFEF4444).withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isMatched ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
                    color: isMatched ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assigned: ${currency.format(sumAssigned)} / ${currency.format(totalAmount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isMatched ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                          ),
                        ),
                        Text(
                          isMatched 
                              ? 'No remaining'
                              : diff > 0 
                                  ? '${currency.format(diff)} remaining to assign'
                                  : '${currency.format(-diff)} over assigned',
                          style: TextStyle(
                            fontSize: 11,
                            color: isMatched ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),

          // Apply Split Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: (totalAmount > 0 && (_splitMethod == 'Equal' || isMatched)) 
                  ? _applySplit 
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Apply Split',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Split Bill',
          style: AppTextStyles.sectionHeading,
        ),
        const Text(
          'Calculate fair shares instantly',
          style: AppTextStyles.sectionSubtitle,
        ),
        const SizedBox(height: AppSpacing.md),
        
        if (!_hasPermission)
          _buildPermissionScreen()
        else if (_showEditGallery)
          _buildEditGalleryView()
        else
          _buildMainSplitView(),
      ],
    );
  }
}
