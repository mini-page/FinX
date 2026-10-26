import 'dart:math';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasource/settlement_local_datasource.dart';
import '../../data/models/settlement_model.dart';
import '../../data/models/participant_model.dart';
import 'participant_providers.dart';

// ── datasource ────────────────────────────────────────────────────────────────

final settlementDatasourceProvider = Provider<SettlementLocalDatasource>((ref) {
  return SettlementLocalDatasource();
});

// ── notifier ──────────────────────────────────────────────────────────────────

final settlementListProvider =
    AsyncNotifierProvider<SettlementListNotifier, List<SettlementModel>>(
  SettlementListNotifier.new,
);

class SettlementListNotifier extends AsyncNotifier<List<SettlementModel>> {
  SettlementLocalDatasource get _ds => ref.read(settlementDatasourceProvider);

  @override
  Future<List<SettlementModel>> build() async {
    try {
      return _ds.getAllSettlements();
    } catch (e, st) {
      if (kDebugMode) {
        dev.log('SettlementListNotifier.build failed',
            error: e, stackTrace: st, name: 'SettlementListNotifier');
      }
      return [];
    }
  }

  Future<void> addSettlement(SettlementModel settlement) async {
    final current = [...state.value ?? []];
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _ds.saveSettlement(settlement);
      return [settlement, ...current];
    });
  }

  Future<void> markSettled(String id) async {
    final current = state.value ?? [];
    final idx = current.indexWhere((s) => s.id == id);
    if (idx == -1) return;
    final updated = current[idx].markSettled();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _ds.saveSettlement(updated);
      final list = [...current];
      list[idx] = updated;
      return list;
    });
  }

  Future<void> deleteSettlement(String id) async {
    final current = state.value ?? [];
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _ds.deleteSettlement(id);
      return current.where((s) => s.id != id).toList(growable: false);
    });
  }
}

// ── derived providers ─────────────────────────────────────────────────────────

/// All pending (unsettled) debts.
final pendingSettlementsProvider = Provider<List<SettlementModel>>((ref) {
  return ref.watch(settlementListProvider).value?.where((s) => !s.isSettled).toList() ?? [];
});

/// Per-participant net balances.
final participantBalancesProvider = Provider<Map<String, double>>((ref) {
  final settlements = ref.watch(settlementListProvider).value ?? [];
  final balances = <String, double>{};
  for (final s in settlements) {
    if (s.isSettled) continue;
    balances[s.fromParticipantId] =
        (balances[s.fromParticipantId] ?? 0) - s.amount;
    balances[s.toParticipantId] =
        (balances[s.toParticipantId] ?? 0) + s.amount;
  }
  return balances;
});

/// Suggested settlements to zero out all debts.
/// Returns list of (fromName, toName, amount) strings.
final settlementSuggestionsProvider = Provider<List<SettlementSuggestion>>((ref) {
  final balances = ref.watch(participantBalancesProvider);
  final participants = ref.watch(participantListProvider).value ?? [];
  final nameMap = {for (final p in participants) p.id: p.name};

  // Build debtors (negative) and creditors (positive) lists
  final debtors = <_BalanceEntry>[];
  final creditors = <_BalanceEntry>[];
  for (final entry in balances.entries) {
    if (entry.value < -0.01) {
      debtors.add(_BalanceEntry(entry.key, -entry.value));
    } else if (entry.value > 0.01) {
      creditors.add(_BalanceEntry(entry.key, entry.value));
    }
  }

  debtors.sort((a, b) => b.amount.compareTo(a.amount));
  creditors.sort((a, b) => b.amount.compareTo(a.amount));

  final suggestions = <SettlementSuggestion>[];
  int di = 0, ci = 0;
  while (di < debtors.length && ci < creditors.length) {
    final amount = min(debtors[di].amount, creditors[ci].amount);
    if (amount > 0) {
      suggestions.add(SettlementSuggestion(
        fromParticipantId: debtors[di].participantId,
        fromName: nameMap[debtors[di].participantId] ?? debtors[di].participantId,
        toParticipantId: creditors[ci].participantId,
        toName: nameMap[creditors[ci].participantId] ?? creditors[ci].participantId,
        amount: amount,
      ));
    }
    debtors[di] = _BalanceEntry(debtors[di].participantId, debtors[di].amount - amount);
    creditors[ci] = _BalanceEntry(creditors[ci].participantId, creditors[ci].amount - amount);
    if (debtors[di].amount < 0.01) di++;
    if (creditors[ci].amount < 0.01) ci++;
  }

  return suggestions;
});

class _BalanceEntry {
  const _BalanceEntry(this.participantId, this.amount);
  final String participantId;
  final double amount;
}

class SettlementSuggestion {
  const SettlementSuggestion({
    required this.fromParticipantId,
    required this.fromName,
    required this.toParticipantId,
    required this.toName,
    required this.amount,
  });

  final String fromParticipantId;
  final String fromName;
  final String toParticipantId;
  final String toName;
  final double amount;
}

// ── controller ────────────────────────────────────────────────────────────────

final settlementControllerProvider = Provider<SettlementController>((ref) {
  return SettlementController(ref);
});

class SettlementController {
  SettlementController(this._ref);
  final Ref _ref;

  Future<void> createSettlement({
    required String fromParticipantId,
    required String fromParticipantName,
    required String toParticipantId,
    required String toParticipantName,
    required double amount,
    String? expenseId,
    String? expenseDescription,
    String? note,
  }) async {
    final settlement = SettlementModel.create(
      fromParticipantId: fromParticipantId,
      fromParticipantName: fromParticipantName,
      toParticipantId: toParticipantId,
      toParticipantName: toParticipantName,
      amount: amount,
      expenseId: expenseId,
      expenseDescription: expenseDescription,
      note: note,
    );
    await _ref
        .read(settlementListProvider.notifier)
        .addSettlement(settlement);
  }

  Future<void> createSettlementFromSuggestion(SettlementSuggestion suggestion, {String? expenseDescription}) async {
    await createSettlement(
      fromParticipantId: suggestion.fromParticipantId,
      fromParticipantName: suggestion.fromName,
      toParticipantId: suggestion.toParticipantId,
      toParticipantName: suggestion.toName,
      amount: suggestion.amount,
      expenseDescription: expenseDescription,
    );
  }

  Future<void> markSettled(String id) async {
    await _ref.read(settlementListProvider.notifier).markSettled(id);
  }
}
