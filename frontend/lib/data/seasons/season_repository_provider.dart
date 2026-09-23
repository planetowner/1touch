import 'package:onetouch/data/catalog/football_catalog.dart';
import 'package:onetouch/data/catalog/football_catalog_provider.dart';
import 'package:onetouch/data/seasons/season_repository.dart';

final SeasonRepository seasonRepository = CatalogSeasonRepository(footballCatalog);
