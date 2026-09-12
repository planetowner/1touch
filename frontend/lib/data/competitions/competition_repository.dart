import 'package:flutter/foundation.dart';
import 'package:onetouch/models/competition.dart';

abstract interface class CompetitionRepository {
  List<Competition> get allCompetitions;

  ValueListenable<List<Competition>> get competitions;

  Competition? findById(int competitionId);

  List<Competition> get domesticCompetitions;

  bool contains(int competitionId);

  Future<void> initialize();
}
