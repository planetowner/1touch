import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/search_text.dart';
import 'package:onetouch/data/catalog/football_catalog.dart';
import 'package:onetouch/data/teams/mock/mock_team_repository.dart';
import 'package:onetouch/models/team.dart';

void main() {
  test('matches accents, case and surrounding whitespace on both sides', () {
    for (final (name, query) in [
      ('Málaga', '  MALAGA  '),
      ('Ma\u0301laga', 'málaga'),
      ('Malaga', 'MA\u0301LAGA'),
      ('Jules Koundé', 'kounde'),
      ('FC Bayern München', 'munchen'),
      ('Deportivo Alavés', 'alaves'),
      ('São Paulo', 'sao'),
    ]) {
      expect(matchesSearchText(query, [name]), isTrue, reason: name);
    }
  });

  test('preserves Korean syllables and Japanese voiced characters', () {
    expect(normalizeSearchText('말라가 CF'), '말라가 cf');
    expect(matchesSearchText('말라가', ['말라가 CF']), isTrue);
    expect(matchesSearchText('말라가', ['말라가 CF']), isTrue);
    expect(matchesSearchText('マラガ', ['マラカ\u3099']), isTrue);
    expect(matchesSearchText('マラカ', ['マラガ']), isFalse);
    expect(matchesSearchText('马拉加', ['马拉加']), isTrue);
  });

  test('matches alternative names and keeps unrelated queries excluded', () {
    expect(matchesSearchText('쿤데', ['Jules Koundé', '쥘 쿤데', null]), isTrue);
    expect(matchesSearchText('unknown', ['Málaga', null]), isFalse);
    expect(matchesSearchText('  ', ['Málaga']), isTrue);
  });

  const teams = [
    Team(teamId: 126, name: 'Málaga', shortName: 'Malaga', shortCode: 'MLA'),
    Team(teamId: 1, name: 'Manchester United', shortName: 'Man Utd'),
  ];
  for (final (label, repository) in [
    ('catalog', CatalogTeamRepository(FootballCatalog()..teams.value = teams)),
    ('mock', MockTeamRepository(teams: teams)),
  ]) {
    test('$label team search shares accent and alternative-name matching', () {
      for (final query in ['malaga', 'MÁLAGA', 'ma\u0301laga', 'mla']) {
        expect(repository.search(query).map((team) => team.teamId), [126]);
      }
      expect(repository.search('man utd').single.teamId, 1);
      expect(repository.search('unknown'), isEmpty);
    });
  }
}
