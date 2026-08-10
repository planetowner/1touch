import 'package:flutter/foundation.dart';
import 'package:onetouch/models/team.dart';

abstract interface class TeamRepository {
  List<Team> get allTeams;

  ValueListenable<List<Team>> get teams;

  Team? findById(int teamId);

  List<Team> search(String query);

  bool contains(int teamId);

  Future<void> initialize();
}
