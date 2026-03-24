import 'package:flutter/material.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/features/TeamScreenFeatures.dart';
// import 'Standing.dart';
// import 'Analysis.dart';

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
              // Pass the whole team map
              Container(child: Fixtures(teams: team)),

              const SizedBox(height: 32),
              const SectionHeader(title: "STANDING"),
              Container(child: Standing(teams: team)),

              const SizedBox(height: 32),
              const SectionHeader(title: "BEST XI"),
              Container(child: BestXI(teams: team)),

              const SizedBox(height: 32),
              const SectionHeader(title: "INJURY STATUS"),
              Container(child: InjuryStatus(teams: team)),

              const SizedBox(height: 20),
              const SectionHeader(title: "TRANSFERS"),
              Container(child: Transfer(teams: team)),

              Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  width: double.infinity,
                  height: 108,
                  decoration: ShapeDecoration(
                    color: const Color(0xFF3D3D3D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Center(
                    child: Text("Ad",
                        textAlign: TextAlign.center, style: Heading4.style),
                  ),
                ),
              ),
              const SizedBox(height: 50),
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