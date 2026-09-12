import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/features/TeamScreenFeatures.dart';

class OverviewTab extends StatelessWidget {
  final Map<String, dynamic>? team;

  const OverviewTab({super.key, required this.team});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildListDelegate(
            [
              const SizedBox(height: 24),
              const SectionHeader(title: "FIXTURE"),
              // Pass the whole team map
              Fixtures(teams: team),

              const SizedBox(height: 32),
              const SectionHeader(title: "STANDING"),
              Standing(teams: team),

              const SizedBox(height: 32),
              const SectionHeader(title: "BEST XI"),
              BestXI(teams: team),

              const SizedBox(height: 32),
              const SectionHeader(title: "INJURY STATUS"),
              InjuryStatus(teams: team),

              const SizedBox(height: 20),
              const SectionHeader(title: "TRANSFERS"),
              Transfer(teams: team),

              Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  width: double.infinity,
                  height: 108,
                  decoration: ShapeDecoration(
                    color: isLight ? AppPalette.black : AppPalette.lightGrey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      "Ad",
                      textAlign: TextAlign.center,
                      style: Heading4.style.copyWith(color: AppPalette.white),
                    ),
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
