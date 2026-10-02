import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/features/player/player_detail_widgets.dart';

void main() {
  testWidgets('missing player image uses the silhouette immediately',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PlayerRemoteImage(null, size: 56)),
    ));

    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('player image uses the disk-backed image widget', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home:
          Scaffold(body: PlayerRemoteImage('https://example.test/player.png')),
    ));

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.imageUrl, 'https://example.test/player.png');
    expect(image.cacheManager, isNotNull);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
  });
}
