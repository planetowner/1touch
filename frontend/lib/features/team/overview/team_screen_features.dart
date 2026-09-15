import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import "package:onetouch/features/helper.dart";
import "package:onetouch/core/style.dart";
import "package:onetouch/core/stylesheet.dart";
import 'package:onetouch/data/competitions/competition_repository_provider.dart';
import 'package:onetouch/data/fixtures/fixture_repository_provider.dart';
import 'package:onetouch/data/injuries/team_injury_repository.dart';
import 'package:onetouch/data/injuries/team_injury_repository_provider.dart';
import 'package:onetouch/data/standings/standing_repository_provider.dart';
import 'package:onetouch/data/teams/team_repository.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/data/transfers/transfer_repository.dart';
import 'package:onetouch/data/transfers/transfer_repository_provider.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/team_injury_report.dart';
import 'package:onetouch/models/team_transfer_window.dart';
import 'package:intl/intl.dart';

part 'fixtures_section.dart';
part 'injury_section.dart';
part 'standing_section.dart';
part 'team_overview_widgets.dart';
part 'transfer_section.dart';
