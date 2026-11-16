import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

import 'package:expensio/core/theme/app_colors.dart';
import 'package:expensio/core/theme/app_tokens.dart';
import 'package:expensio/features/settings/presentation/provider/preferences_providers.dart';
import 'package:expensio/shared/widgets/app_search_bar.dart';
import 'package:expensio/features/expense/presentation/provider/expense_providers.dart';
import 'package:expensio/features/accounts/presentation/provider/participant_providers.dart';
import 'package:expensio/features/accounts/presentation/provider/settlement_providers.dart';
import 'package:expensio/features/accounts/data/models/participant_model.dart';
import 'package:expensio/features/accounts/data/models/settlement_model.dart';
import '../screens/tools_pages/splitter_profile_screen.dart';

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
  
  List<String> _contactsGallery = [];
  List<String> _customContacts = [];
  List<String> _selectedGalleryPeople = [];
  List<String> _activeSplitMembers = [];
  
  String _searchQuery = '';
  String _whoPaid = 'You';
  String _splitMethod = 'Equal'; // 'Equal' or 'Exact'
  bool _showEditGallery = false;
  int _selectedSection = 0; // 0: Manage, 1: Payments
  
  final Map<String, double> _exactAmounts = {};

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
    
    setState(() {
      _activeSplitMembers = ['You', ..._contactsGallery];
      _isLoading = false;
    });
  }

  List<String> _filterContacts(String query) {
    final participants = ref.read(participantListProvider).value ?? [];
    final participantNames = participants.map((p) => p.name).toList();
    final allList = <String>{...participantNames, ..._customContacts};
    if (allList.isEmpty) {
      allList.addAll(['Aleem', 'Rahul', 'Priya']);
    }
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

    // Persist as a participant
    final existing = ref.read(participantListProvider).value ?? [];
    if (!existing.any((p) => p.name.toLowerCase() == trimmed.toLowerCase())) {
      final p = ParticipantModel.create(name: trimmed);
      ref.read(participantListProvider.notifier).saveParticipant(p);
    }

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

  Future<void> _applySplit() async {
    final totalAmount = double.tryParse(_amountController.text) ?? 0;
    if (totalAmount <= 0) return;

    final perPersonEqual = totalAmount / _activeSplitMembers.length;
    final currency = ref.read(currencyFormatProvider);
    final symbol = ref.read(currencySymbolProvider);
    final now = DateTime.now();

    // Get or create participants
    final existingParticipants = ref.read(participantListProvider).value ?? [];
    final nameToId = <String, String>{
      for (final p in existingParticipants) p.name.toLowerCase(): p.id,
    };

    String getOrCreateId(String name) {
      if (name == 'You') return 'you';
      final key = name.trim().toLowerCase();
      if (nameToId.containsKey(key)) return nameToId[key]!;
      // Create on the fly
      final newParticipant = ParticipantModel.create(name: name.trim());
      ref.read(participantListProvider.notifier).saveParticipant(newParticipant);
      nameToId[key] = newParticipant.id;
      return newParticipant.id;
    }

    // Calculate user's personal share
    final myShare = _splitMethod == 'Equal'
        ? perPersonEqual
        : (_exactAmounts['You'] ?? perPersonEqual);

    // Create personal expense record reflecting user's actual share
    final paidById = getOrCreateId(_whoPaid);
    final note = 'Split: ${_activeSplitMembers.join(", ")}';

    if (myShare > 0) {
      await ref.read(expenseControllerProvider).addExpense(
            amount: myShare,
            category: 'Social',
            date: now,
            note: _whoPaid == 'You'
                ? '$note (My share of ${symbol}${currency.format(totalAmount)})'
                : '$note (Paid by $_whoPaid)',
          );
    }

    // Create settlement records for each non-payer
    for (final member in _activeSplitMembers) {
      if (member == _whoPaid) continue;
      final share = _splitMethod == 'Equal'
          ? perPersonEqual
          : (_exactAmounts[member] ?? 0);
      if (share <= 0) continue;

      final fromId = getOrCreateId(member);
      final toId = paidById;

      await ref.read(settlementControllerProvider).createSettlement(
            fromParticipantId: fromId,
            fromParticipantName: member,
            toParticipantId: toId,
            toParticipantName: _whoPaid,
            amount: share,
            expenseDescription: 'Split expense of ${symbol}${currency.format(totalAmount)}',
          );
    }

    if (!context.mounted) return;

    // Show success dialog
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
          'Expense of ${currency.format(totalAmount)} split among ${_activeSplitMembers.length} people.\nSettlement records created for ${_activeSplitMembers.length - 1} participant(s).',
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
                'Select Split Partners',
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
            hintText: 'Search or type friend\'s name to add...',
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
              itemCount: _activeSplitMembers.length + 1,
              itemBuilder: (context, idx) {
                if (idx == _activeSplitMembers.length) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedGalleryPeople = List<String>.from(_contactsGallery);
                          _showEditGallery = true;
                        });
                      },
                      child: const Tooltip(
                        message: 'Add Splitter',
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: Color(0xFFEFF6FF),
                          child: Icon(Icons.add_rounded, color: AppColors.primaryBlue, size: 22),
                        ),
                      ),
                    ),
                  );
                }

                final name = _activeSplitMembers[idx];
                final isYou = name == 'You';
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: isYou
                        ? null
                        : () {
                            final participants = ref.read(participantListProvider).value ?? [];
                            final p = participants.where((item) => item.name.toLowerCase() == name.toLowerCase()).firstOrNull;
                            if (p != null) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => SplitterProfileScreen(
                                    participantId: p.id,
                                    participantName: p.name,
                                  ),
                                ),
                              );
                            } else {
                              final newP = ParticipantModel.create(name: name);
                              ref.read(participantListProvider.notifier).saveParticipant(newP);
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => SplitterProfileScreen(
                                    participantId: newP.id,
                                    participantName: newP.name,
                                  ),
                                ),
                              );
                            }
                          },
                    child: Tooltip(
                      message: isYou ? 'You' : '$name (Tap to view details)',
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
        // Tab switcher: Manage | Payments
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _selectedSection = 0;
                    _showEditGallery = false;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _selectedSection == 0 ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: _selectedSection == 0
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Manage',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: _selectedSection == 0 ? AppColors.textDark : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _selectedSection = 1;
                    _showEditGallery = false;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _selectedSection == 1 ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: _selectedSection == 1
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Payments',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: _selectedSection == 1 ? AppColors.textDark : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_selectedSection == 0) ...[
          if (_showEditGallery)
            _buildEditGalleryView()
          else
            _buildMainSplitView(),
        ] else ...[
          Container(
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
            child: _PendingDebtsSection(),
          ),
        ],
      ],
    );
  }
}

// ── Pending Debts Section ─────────────────────────────────────────────────────

class _PendingDebtsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingSettlementsProvider);
    final suggestions = ref.watch(settlementSuggestionsProvider);
    final balances = ref.watch(participantBalancesProvider);
    final currency = ref.watch(currencyFormatProvider);

    if (pending.isEmpty && suggestions.isEmpty && balances.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_long_rounded, color: AppColors.primaryBlue, size: 28),
              ),
              const SizedBox(height: 14),
              const Text(
                'No Payments Pending',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'When you split an expense, balances and settlements will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.account_balance_rounded, size: 18, color: AppColors.textDark),
            const SizedBox(width: 8),
            Text(
              'Pending Debts',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${pending.length}',
                style: TextStyle(
                  color: AppColors.danger,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Per-person balances
        ...balances.entries.map((entry) {
          final isPositive = entry.value > 0;
          final name = _participantName(ref, entry.key);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.md),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: isPositive
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.danger.withValues(alpha: 0.1),
                  child: Text(
                    name[0].toUpperCase(),
                    style: TextStyle(
                      color: isPositive ? AppColors.success : AppColors.danger,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _openPersonDetail(context, ref, entry.key, name),
                  child: Text(
                    '${isPositive ? '+' : ''}${currency.format(entry.value)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: isPositive ? AppColors.success : AppColors.danger,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
              ],
            ),
          );
        }),

        // Settlement suggestions
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(
                color: AppColors.primaryBlue.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline_rounded,
                        size: 16, color: AppColors.primaryBlue),
                    const SizedBox(width: 6),
                    Text(
                      'Settlement Suggestions',
                      style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...suggestions.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${s.fromName} → ${s.toName}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      Text(
                        currency.format(s.amount),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () async {
                          await ref.read(settlementControllerProvider)
                              .settleSuggestion(s);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Settled: ${s.fromName} paid ${currency.format(s.amount)} to ${s.toName}'),
                                backgroundColor: AppColors.textDark,
                              ),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                          child: const Text(
                            'Settle',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _participantName(WidgetRef ref, String id) {
    if (id == 'you') return 'You';
    final participants = ref.read(participantListProvider).value ?? [];
    final p = participants.where((p) => p.id == id).firstOrNull;
    return p?.name ?? id;
  }

  void _openPersonDetail(BuildContext context, WidgetRef ref, String participantId, String name) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SplitterProfileScreen(
          participantId: participantId,
          participantName: name,
        ),
      ),
    );
  }
}

// ── Settlement Tile ───────────────────────────────────────────────────────────

class _SettlementTile extends StatelessWidget {
  const _SettlementTile({
    required this.settlement,
    required this.isIncoming,
    required this.currency,
    this.onSettle,
    this.showSettleButton = true,
  });

  final SettlementModel settlement;
  final bool isIncoming;
  final NumberFormat currency;
  final VoidCallback? onSettle;
  final bool showSettleButton;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: isIncoming
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.danger.withValues(alpha: 0.1),
            child: Icon(
              isIncoming
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              size: 16,
              color: isIncoming ? AppColors.success : AppColors.danger,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${settlement.fromParticipantName} → ${settlement.toParticipantName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.textDark,
                  ),
                ),
                if (settlement.expenseDescription != null)
                  Text(
                    settlement.expenseDescription!,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                Text(
                  DateFormat('d MMM yyyy').format(settlement.createdAt),
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isIncoming ? '+' : '-'}${currency.format(settlement.amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: isIncoming ? AppColors.success : AppColors.danger,
                ),
              ),
              if (settlement.isSettled)
                Text(
                  'Settled ${DateFormat('d MMM').format(settlement.settledAt!)}',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (!settlement.isSettled && showSettleButton && onSettle != null)
                GestureDetector(
                  onTap: onSettle,
                  child: Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: const Text(
                      'Settle Up',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
