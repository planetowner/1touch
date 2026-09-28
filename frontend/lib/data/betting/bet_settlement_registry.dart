import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class BetSettlementTracker {
  Future<void> initialize();
  Set<int> get pendingFixtureIds;
  Future<void> track(int fixtureId);
  Future<void> remove(int fixtureId);
}

/// Keeps the fixtures with an open bet available after a relaunch.
///
/// The betting API currently exposes a user's bet through each fixture market,
/// so the app remembers which markets need to be checked for settlement.
class BetSettlementRegistry extends ChangeNotifier
    implements BetSettlementTracker {
  BetSettlementRegistry({SharedPreferences? preferences})
      : _preferences = preferences;

  static const _storageKey = 'betting.pending_settlement_fixture_ids';

  SharedPreferences? _preferences;
  Future<void>? _initializing;
  final Set<int> _pendingFixtureIds = {};

  @override
  Set<int> get pendingFixtureIds => Set.unmodifiable(_pendingFixtureIds);

  @override
  Future<void> initialize() => _initializing ??= _load();

  Future<void> _load() async {
    final preferences = _preferences ??= await SharedPreferences.getInstance();
    _pendingFixtureIds
      ..clear()
      ..addAll(
        preferences
                .getStringList(_storageKey)
                ?.map(int.tryParse)
                .whereType<int>() ??
            const <int>[],
      );
    notifyListeners();
  }

  @override
  Future<void> track(int fixtureId) async {
    await initialize();
    if (!_pendingFixtureIds.add(fixtureId)) return;
    await _save();
    notifyListeners();
  }

  @override
  Future<void> remove(int fixtureId) async {
    await initialize();
    if (!_pendingFixtureIds.remove(fixtureId)) return;
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final values = _pendingFixtureIds.toList()..sort();
    await _preferences!.setStringList(
      _storageKey,
      values.map((fixtureId) => '$fixtureId').toList(growable: false),
    );
  }
}

final betSettlementRegistry = BetSettlementRegistry();
