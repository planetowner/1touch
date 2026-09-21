part of 'player_comparison_screen.dart';

class _HeaderArea extends StatelessWidget {
  const _HeaderArea(
      {required this.p1,
      required this.p2,
      required this.onBack,
      required this.onSearch,
      required this.onTap1,
      required this.onTap2});
  final PlayerDetail? p1, p2;
  final VoidCallback onBack, onSearch;
  final VoidCallback? onTap1, onTap2;
  @override
  Widget build(BuildContext context) => DecoratedBox(
      key: const ValueKey('comparison-header-gradient'),
      decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
            Theme.of(context).colorScheme.surface,
            AppColors.of(context).subtleBackground
          ])),
      child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_ios_new)),
              IconButton(onPressed: onSearch, icon: const Icon(Icons.search))
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _slot(p1, 1, onTap1)),
              const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('VS')),
              Expanded(child: _slot(p2, 2, onTap2)),
            ]),
          ])));
  Widget _slot(PlayerDetail? player, int slot, VoidCallback? onTap) =>
      Column(children: [
        OutlinedButton(
            onPressed: onTap,
            child: Row(children: [
              Expanded(
                  child: Text(player?.profile.name ?? 'PLAYER $slot',
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
              const Icon(Icons.keyboard_arrow_down, size: 18)
            ])),
        const SizedBox(height: 12),
        PlayerRemoteImage(player?.profile.image,
            key: Key('comparison-header-photo-$slot'), size: 120),
        const SizedBox(height: 8),
        Text(player?.analysis?.position ?? '—'),
        const SizedBox(height: 12),
      ]);
}
