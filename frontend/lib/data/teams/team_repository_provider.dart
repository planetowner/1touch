import 'package:onetouch/data/catalog/football_catalog.dart';
import 'package:onetouch/data/catalog/football_catalog_provider.dart';
import 'package:onetouch/data/teams/team_competition_context.dart';
import 'package:onetouch/data/teams/team_repository.dart';

final TeamRepository teamRepository = CatalogTeamRepository(footballCatalog);
final TeamCompetitionContextResolver teamCompetitionContextResolver =
    footballCatalog;
