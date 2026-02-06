import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:onetouch/data/playerdata.dart';

enum Position { GK, DF, MF, FW }

Position positionFromId(int id) {
  switch (id) {
    case 24:
      return Position.GK;
    case 25:
      return Position.DF;
    case 26:
      return Position.MF;
    case 27:
      return Position.FW;
    default:
      return Position.MF;
  }
}

String koreanPositionName(Position pos) {
  switch (pos) {
    case Position.GK:
      return '골키퍼';
    case Position.DF:
      return '수비수';
    case Position.MF:
      return '미드필더';
    case Position.FW:
      return '공격수';
  }
}

class SquadTab extends StatefulWidget {
  final Map<String, dynamic>? team;

  const SquadTab({super.key, required this.team});

  @override
  State<SquadTab> createState() => _SquadTabState();
}

class _SquadTabState extends State<SquadTab> {
  List<RealPlayer> players = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchPlayers();
  }

  Future<void> fetchPlayers() async {
    final teamId = widget.team? ['id'];
    final url = Uri.parse('https://3e6a1be77d44.ngrok-free.app/api/teams/$teamId/squad');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final squadList = data['squads'] as List;

        setState(() {
          players = squadList.map((item) => RealPlayer.fromSquadJson(item)).toList();
          isLoading = false;
        });
      } else {
        print("Failed to load players: ${response.statusCode}");
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("Error: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (players.isEmpty) return const Center(child: Text("No players found"));

    // Group players by position
    final Map<Position, List<RealPlayer>> grouped = {};
    for (final player in players) {
      final pos = positionFromId(player.positionId);
      grouped.putIfAbsent(pos, () => []).add(player);
    }

    // Sort players within each group by jersey number (nulls last)
    for (final group in grouped.values) {
      group.sort((a, b) {
        final aNum = a.jerseyNumber ?? 999;
        final bNum = b.jerseyNumber ?? 999;
        return aNum.compareTo(bNum);
      });
    }

    // Define order of positions
    final orderedPositions = [Position.GK, Position.DF, Position.MF, Position.FW];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: orderedPositions
          .where((pos) => grouped.containsKey(pos))
          .map((pos) {
        final positionName = koreanPositionName(pos);
        final playersInGroup = grouped[pos]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              positionName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            ...playersInGroup.map((player) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(player.imagePath),
                  radius: 24,
                ),
                title: Text(player.displayName, style: const TextStyle(color: Colors.white)),
                subtitle: Text(
                  player.jerseyNumber?.toString() ?? 'Unknown',
                  style: const TextStyle(color: Colors.grey),
                ),
              );
            }),
            const SizedBox(height: 24),
          ],
        );
      }).toList(),
    );
  }
}