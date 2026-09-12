import 'package:flutter/foundation.dart';
import 'package:onetouch/models/season.dart';

abstract interface class SeasonRepository {
  List<Season> get allSeasons;

  ValueListenable<List<Season>> get seasons;

  Season? findById(int seasonId);

  List<Season> forCompetition(int competitionId);

  Season? currentForCompetition(int competitionId);

  bool contains(int seasonId);

  Future<void> initialize();
}
