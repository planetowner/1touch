import 'package:flutter/material.dart';
import 'package:onetouch/data/players/player_detail_repository_provider.dart';
import 'package:onetouch/data/players/player_detail_repository.dart';
import 'package:onetouch/features/player/player_detail_widgets.dart';
import 'package:onetouch/models/player_detail.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class PlayerPickerSheet extends StatefulWidget {
  const PlayerPickerSheet({super.key, this.repository, this.excludedId});
  final PlayerDetailRepository? repository;
  final int? excludedId;
  @override
  State<PlayerPickerSheet> createState() => PlayerPickerSheetState();
}

class PlayerPickerSheetState extends State<PlayerPickerSheet> {
  final _query = TextEditingController();
  late Future<List<PlayerCandidate>> _players;
  @override
  void initState() {
    super.initState();
    _search();
  }

  void _search() {
    _players = Future.sync(() => (widget.repository ?? playerDetailRepository)
        .search(_query.text.trim()));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
      child: Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .68,
              child: Column(
                  key: const ValueKey('comparison-player-picker-sheet'),
                  children: [
                    Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          Expanded(
                              child: TextField(
                                  controller: _query,
                                  onSubmitted: (_) => setState(_search),
                                  decoration: InputDecoration(
                                      hintText: tr(context, 'Search players'),
                                      suffixIcon: IconButton(
                                          onPressed: () => setState(_search),
                                          icon: const Icon(Icons.search))))),
                          IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close))
                        ])),
                    Expanded(
                        child: FutureBuilder<List<PlayerCandidate>>(
                            future: _players,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState !=
                                  ConnectionState.done) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }
                              if (snapshot.hasError) {
                                return Center(
                                    child: TextButton(
                                        onPressed: () => setState(_search),
                                        child: Text(tr(context, 'Retry'))));
                              }
                              final players = snapshot.requireData
                                  .where((p) => p.id != widget.excludedId)
                                  .toList();
                              if (players.isEmpty) {
                                return Center(
                                    child:
                                        Text(tr(context, 'No players found')));
                              }
                              return ListView.builder(
                                  itemCount: players.length,
                                  itemBuilder: (context, index) {
                                    final player = players[index];
                                    return ListTile(
                                        leading:
                                            PlayerRemoteImage(player.image),
                                        title: Text(player.name),
                                        onTap: () =>
                                            Navigator.pop(context, player));
                                  });
                            })),
                  ]))));
}
