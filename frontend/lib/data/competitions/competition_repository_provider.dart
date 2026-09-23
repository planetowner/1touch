import 'package:onetouch/data/competitions/competition_repository.dart';
import 'package:onetouch/data/catalog/football_catalog.dart';
import 'package:onetouch/data/catalog/football_catalog_provider.dart';

final CompetitionRepository competitionRepository = CatalogCompetitionRepository(footballCatalog);
