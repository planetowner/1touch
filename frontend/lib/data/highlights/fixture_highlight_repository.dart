import 'package:onetouch/models/fixture_highlight.dart';

abstract interface class FixtureHighlightRepository {
  Future<FixtureHighlight?> loadForFixture(int fixtureId);
}
