import 'package:flutter/material.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/bodywidgets/bodywidget_team.dart' as bwg;
// import 'package:intl/intl.dart';

class OverviewTab extends StatelessWidget {
  final Map<String, dynamic>? team;

  const OverviewTab({super.key, required this.team});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildListDelegate(
            [
              const SizedBox(height: 24),
              const SectionHeader(title: "FIXTURE"),
              Container(child: bwg.Fixtures(teams: team)),
              const SizedBox(height: 32),
              const SectionHeader(title: "STANDING"),
              Container(child: bwg.Standing(teams: team,)),
              const SizedBox(height: 32),
              const SectionHeader(title: "BEST XI"),
              Container(child: bwg.BestXI(teams: team,)),
              const SizedBox(height: 32),
              const SectionHeader(title: "INJURY STATUS"),
              Container(child: bwg.InjuryStatus(teams: team,)),
              const SizedBox(height: 20),
              const SectionHeader(title: "TRANSFERS"),
              Container(child: bwg.Transfer(teams: team,)),
              Padding(
                padding: EdgeInsets.all(24),
                child: Container(
                  width: 395,
                  height: 108,
                  padding: EdgeInsets.all(8),
                  decoration: ShapeDecoration(
                    color: Color(0xFF3D3D3D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Center(
                    child: Text("Ad",
                        textAlign: TextAlign.center, style: Heading4.style),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Text(title, style: Body1_b.style, textAlign: TextAlign.start),
    );
  }
}