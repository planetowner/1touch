import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/transfers/transfer_repository.dart';
import 'package:onetouch/models/team_transfer_window.dart';

void transferRepositoryContract({
  required TransferRepository Function() createRepository,
}) {
  late TransferRepository repository;

  setUp(() => repository = createRepository());

  test('starts without inventing a cached team window', () {
    expect(repository.cachedWindows.value, isEmpty);
    expect(repository.cachedForTeam(9), isNull);
  });

  test('loads incoming transfers newest first with the source team', () async {
    final window = await repository.loadForTeam(9);

    expect(window.teamId, 9);
    expect(window.windowKey, '2026 winter');
    expect(
      window.incoming.map((entry) => entry.transferId),
      [4, 3, 1],
    );
    expect(window.incoming.first.direction, TransferDirection.incoming);
    expect(window.incoming.first.otherTeamId, 9);
    expect(window.incoming.first.otherTeamName, 'Same Team');
  });

  test('loads outgoing transfers newest first with the destination team',
      () async {
    final window = await repository.loadForTeam(9);

    expect(window.outgoing.map((entry) => entry.transferId), [2]);
    expect(window.outgoing.single.direction, TransferDirection.outgoing);
    expect(window.outgoing.single.otherTeamId, 20);
    expect(window.outgoing.single.otherTeamName, 'Destination FC');
  });

  test('matches backend display-type formatting', () async {
    final window = await repository.loadForTeam(9);
    final entries = {
      for (final entry in [...window.incoming, ...window.outgoing])
        entry.transferId: entry,
    };

    expect(entries[1]?.displayType, '€8.5M');
    expect(entries[2]?.displayType, 'Loan');
    expect(entries[3]?.displayType, 'Free Transfer');
    expect(entries[4]?.displayType, 'Transfer');
  });

  test('does not classify a same-team row as both directions', () async {
    final window = await repository.loadForTeam(9);

    expect(
      window.incoming.where((entry) => entry.transferId == 4),
      hasLength(1),
    );
    expect(
      window.outgoing.where((entry) => entry.transferId == 4),
      isEmpty,
    );
  });

  test('returns and caches an empty window for an unknown team', () async {
    final window = await repository.loadForTeam(-1);

    expect(window.teamId, -1);
    expect(window.incoming, isEmpty);
    expect(window.outgoing, isEmpty);
    expect(repository.cachedForTeam(-1), same(window));
  });

  test('publishes an immutable keyed cache and immutable result lists',
      () async {
    final window = await repository.loadForTeam(9);

    expect(repository.cachedForTeam(9), same(window));
    expect(repository.cachedWindows.value[9], same(window));
    expect(
      () => repository.cachedWindows.value.clear(),
      throwsUnsupportedError,
    );
    expect(() => window.incoming.clear(), throwsUnsupportedError);
    expect(() => window.outgoing.clear(), throwsUnsupportedError);
  });

  test('reuses the cached window for repeated loads', () async {
    final first = await repository.loadForTeam(9);
    final second = await repository.loadForTeam(9);

    expect(second, same(first));
  });
}
