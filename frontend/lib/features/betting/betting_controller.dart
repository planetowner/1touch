import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:onetouch/data/betting/betting_repository.dart';
import 'package:onetouch/data/betting/betting_repository_provider.dart'
    as providers;
import 'package:onetouch/models/betting.dart';
import 'package:uuid/uuid.dart';

class BettingController extends ChangeNotifier {
  BettingController({required this.fixtureId, BettingRepository? repository})
      : _repository = repository;

  final int fixtureId;
  final BettingRepository? _repository;
  BettingRepository get repository =>
      _repository ?? providers.bettingRepository;
  BettingMarket? market;
  bool loading = false;
  bool saving = false;
  String? error;
  bool _disposed = false;
  int _loadVersion = 0;
  Timer? _closeTimer;
  String? _pendingSignature;
  String? _pendingRequestId;

  bool get beforeKickoff =>
      market?.closesAt != null && DateTime.now().isBefore(market!.closesAt!);
  bool get canBet => market?.canBet == true && beforeKickoff && !saving;
  bool get canCancel => market?.canCancel == true && beforeKickoff && !saving;
  int get spendingLimit =>
      (market?.wallet.balance ?? 0) +
      (market?.bet?.isOpen == true ? market!.bet!.stake : 0);

  Future<void> load() async {
    final version = ++_loadVersion;
    loading = true;
    error = null;
    _notify();
    try {
      await repository.initializeWallet();
      final loaded = await repository.loadMarket(fixtureId);
      if (_disposed || version != _loadVersion) return;
      market = loaded;
      _closeTimer?.cancel();
      if (loaded.closesAt != null &&
          DateTime.now().isBefore(loaded.closesAt!)) {
        _closeTimer = Timer(
          loaded.closesAt!.difference(DateTime.now()),
          _notify,
        );
      }
    } on Object catch (exception) {
      if (!_disposed && version == _loadVersion) {
        error = _errorMessage(exception);
      }
    } finally {
      if (!_disposed && version == _loadVersion) {
        loading = false;
        _notify();
      }
    }
  }

  Future<bool> save(BetOutcome outcome, int stake) =>
      _mutate(cancel: false, outcome: outcome, stake: stake);

  Future<bool> cancel() => _mutate(cancel: true);

  Future<bool> _mutate({
    required bool cancel,
    BetOutcome? outcome,
    int? stake,
  }) async {
    final current = market;
    if (current == null || saving || !(cancel ? canCancel : canBet)) {
      return false;
    }
    final revision = current.bet?.revision ?? 0;
    final signature =
        '$cancel/$outcome/$stake/${current.predictionRunId}/$revision';
    if (_pendingSignature != signature) {
      _pendingSignature = signature;
      _pendingRequestId = const Uuid().v4();
    }
    saving = true;
    error = null;
    _notify();
    try {
      final result = cancel
          ? await repository.cancelBet(
              fixtureId: fixtureId,
              requestId: _pendingRequestId!,
              expectedRevision: revision,
            )
          : await repository.saveBet(
              fixtureId: fixtureId,
              requestId: _pendingRequestId!,
              expectedRevision: revision,
              predictionRunId: current.predictionRunId!,
              outcome: outcome!,
              stake: stake!,
            );
      if (_disposed) return true;
      market = current.withMutation(result);
      _pendingSignature = null;
      _pendingRequestId = null;
      await load();
      return true;
    } on Object catch (exception) {
      if (_disposed) return false;
      final message = _errorMessage(exception);
      if (exception is BettingRequestException &&
          [
            'prediction_changed',
            'bet_changed',
            'betting_closed',
          ].contains(exception.code)) {
        await load();
      }
      error = message;
      return false;
    } finally {
      saving = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _closeTimer?.cancel();
    super.dispose();
  }
}

String _errorMessage(Object error) => switch (error) {
      BettingRequestException(code: 'sign_in_required') =>
        'Sign in to use points.',
      BettingRequestException(code: 'insufficient_points') =>
        'Not enough points.',
      BettingRequestException(code: 'prediction_changed') =>
        'Odds have changed. Review them and submit again.',
      BettingRequestException(code: 'bet_changed') =>
        'Your bet has changed. Review it and try again.',
      BettingRequestException(code: 'betting_closed') =>
        'Betting is closed for this match.',
      _ => 'Unable to load or save your bet. Please try again.',
    };
