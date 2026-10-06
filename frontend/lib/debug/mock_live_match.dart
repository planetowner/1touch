import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:onetouch/data/betting/betting_repository.dart';
import 'package:onetouch/data/chat/chat_repository.dart';
import 'package:onetouch/data/chat/chat_socket.dart';
import 'package:onetouch/data/fixtures/mock/mock_fixture_repository.dart';
import 'package:onetouch/models/betting.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/fixture_chat_message.dart';
import 'package:onetouch/models/fixture_clock.dart';
import 'package:onetouch/models/fixture_detail.dart';

/// Opt-in, debug-only manual test. It never replaces the app's API providers.
const bool mockLiveMatchEnabled =
    kDebugMode && bool.fromEnvironment('ENABLE_TEST_LIVE_MATCH');

const int mockLiveMatchId = 999999001;

class MockLiveMatch {
  MockLiveMatch()
      : fixtures = MockLiveFixtureRepository(),
        chat = MockLiveChatRepository(),
        socket = MockLiveChatSocket(),
        betting = MockLiveBettingRepository();

  final MockLiveFixtureRepository fixtures;
  final MockLiveChatRepository chat;
  final MockLiveChatSocket socket;
  final MockLiveBettingRepository betting;
}

class MockLiveFixtureRepository extends MockFixtureRepository {
  MockLiveFixtureRepository()
      : super(
          fixtures: [_fixture(0)],
          fixtureDetails: [_detail(0)],
        ) {
    _current = super.cachedDetail(mockLiveMatchId)!;
  }

  late FixtureDetail _current;
  int _refreshCount = 0;

  @override
  FixtureDetail? cachedDetail(int fixtureId) =>
      fixtureId == mockLiveMatchId ? _current : null;

  @override
  Future<FixtureDetail> loadDetail(int fixtureId) async {
    if (fixtureId != mockLiveMatchId) {
      throw StateError('Unknown test fixture: $fixtureId');
    }
    return _current;
  }

  @override
  Future<FixtureDetail> refreshDetail(int fixtureId) async {
    if (fixtureId != mockLiveMatchId) {
      throw StateError('Unknown test fixture: $fixtureId');
    }
    _current = _detail(++_refreshCount);
    return _current;
  }

  static Fixture _fixture(int refreshCount) => Fixture(
        fixtureId: mockLiveMatchId,
        seasonId: 25659,
        competitionId: 564,
        homeTeamId: 83,
        awayTeamId: 676,
        homeTeamName: 'FC Barcelona',
        awayTeamName: 'Girona',
        homeTeamShortName: 'FCB',
        awayTeamShortName: 'GIR',
        competitionType: CompetitionType.league,
        roundName: '7',
        status: FixtureStatus.live,
        stateId: 2,
        startingAt: DateTime.now()
            .subtract(const Duration(minutes: 32))
            .toIso8601String(),
        homeScore: refreshCount >= 4 ? 2 : 1,
        awayScore: refreshCount >= 2 ? 1 : 0,
      );

  static FixtureDetail _detail(int refreshCount) {
    final minute = (32 + refreshCount).clamp(32, 89);
    return FixtureDetail(
      fixture: _fixture(refreshCount),
      clock: FixtureClock(
        periodTypeId: 1,
        countsFrom: 0,
        minutes: minute,
        seconds: 0,
        ticking: true,
        isStale: false,
        sampleAgeSeconds: 0,
        receivedAt: DateTime.now(),
      ),
      venueName: 'Estadi Olimpic Lluis Companys',
      expectedGoals: null,
      playerExpectedGoals: const [],
      shots: const [],
      events: [
        _goal(1, 83, 'Barcelona Player', 20),
        if (refreshCount >= 2) _goal(2, 676, 'Girona Player', 34),
        if (refreshCount >= 4) _goal(3, 83, 'Barcelona Player', 36),
      ],
      statistics: [
        _stat(83, 'ball-possession', 57),
        _stat(676, 'ball-possession', 43),
        _stat(83, 'shots-total', 5 + refreshCount.toDouble()),
        _stat(676, 'shots-total', 3 + refreshCount.toDouble()),
      ],
      lineups: const [],
      formations: const [],
      coaches: const [],
      pressure: const [],
    );
  }

  static FixtureEvent _goal(int id, int teamId, String player, int minute) =>
      FixtureEvent(
        eventId: id,
        teamId: teamId,
        eventTypeId: 14,
        eventTypeCode: 'goal',
        eventTypeName: 'Goal',
        playerId: null,
        playerName: player,
        playerImage: null,
        relatedPlayerId: null,
        relatedPlayerName: null,
        relatedPlayerImage: null,
        minute: minute,
        extraMinute: null,
        onBench: false,
      );

  static FixtureStatistic _stat(int teamId, String code, double value) =>
      FixtureStatistic(
        teamId: teamId,
        statTypeId: 0,
        statCode: code,
        statName: code,
        value: value,
      );
}

class MockLiveChatRepository implements ChatRepository {
  @override
  final ValueNotifier<Map<int, List<FixtureChatMessage>>> cachedHistories =
      ValueNotifier(const {});

  @override
  List<FixtureChatMessage> cachedHistoryForFixture(int fixtureId) => const [];

  @override
  Future<List<FixtureChatMessage>> loadHistory({
    required int fixtureId,
    int? beforeId,
    int? afterId,
    int limit = 50,
  }) async =>
      const [];

  @override
  Future<void> reportMessage({
    required int messageId,
    required String reason,
  }) async {}
}

class MockLiveChatSocket implements ChatSocket {
  MockLiveChatSession? lastSession;

  @override
  Future<ChatSocketSession> connect(int fixtureId) async {
    if (fixtureId != mockLiveMatchId) {
      throw StateError('Unknown test fixture: $fixtureId');
    }
    return lastSession = MockLiveChatSession(fixtureId);
  }
}

class MockLiveChatSession implements ChatSocketSession {
  MockLiveChatSession(this.fixtureId) {
    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
      _messages.add(_message('What a match!', isMine: false));
    });
  }

  final int fixtureId;
  final StreamController<FixtureChatMessage> _messages =
      StreamController.broadcast();
  late final Timer _timer;
  int _nextId = 1;
  bool _closed = false;
  bool get isClosed => _closed;

  @override
  Stream<FixtureChatMessage> get messages => _messages.stream;

  @override
  Future<void> send(String text) async {
    if (_closed) throw StateError('Test chat is closed.');
    _messages.add(_message(text, isMine: true));
  }

  FixtureChatMessage _message(String text, {required bool isMine}) =>
      FixtureChatMessage(
        messageId: _nextId++,
        fixtureId: fixtureId,
        nicknameEn: isMine ? 'Tester_A8Q4' : 'Supporter_X7K2',
        nicknameKo: isMine ? '테스터_A8Q4' : '서포터_X7K2',
        isMine: isMine,
        text: text,
        createdAt: DateTime.now(),
        authorDeleted: false,
      );

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _timer.cancel();
    await _messages.close();
  }
}

class MockLiveBettingRepository implements BettingRepository {
  @override
  Future<PointWallet> initializeWallet() async =>
      PointWallet(balance: 0, initialized: true);

  @override
  Future<BettingMarket> loadMarket(int fixtureId) async => BettingMarket(
        fixtureId: fixtureId,
        stakeUnit: 1,
        opensAt: null,
        available: false,
        canBet: false,
        canCancel: false,
        unavailableReason: 'test_match',
        closesAt: null,
        predictionRunId: null,
        predictionAsOf: null,
        options: const [],
        wallet: PointWallet(balance: 0, initialized: true),
        bet: null,
        participantCount: 0,
        userProbabilities: null,
      );

  @override
  Future<BetMutation> saveBet({
    required int fixtureId,
    required String requestId,
    required int expectedRevision,
    required String predictionRunId,
    required BetOutcome outcome,
    required int stake,
  }) =>
      throw UnsupportedError('Betting is disabled for the test match.');

  @override
  Future<BetMutation> cancelBet({
    required int fixtureId,
    required String requestId,
    required int expectedRevision,
  }) =>
      throw UnsupportedError('Betting is disabled for the test match.');
}
