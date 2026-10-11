import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<Color>> screenPixels(
  WidgetTester tester,
  Finder boundaryFinder,
  List<Offset> points, {
  String? screenshotName,
}) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(boundaryFinder);
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final pixels = (await image.toByteData())!;
      final colors = points.map((point) {
        final offset = (point.dy.toInt() * image.width + point.dx.toInt()) * 4;
        return Color.fromARGB(
          pixels.getUint8(offset + 3),
          pixels.getUint8(offset),
          pixels.getUint8(offset + 1),
          pixels.getUint8(offset + 2),
        );
      }).toList();
      if (screenshotName != null) {
        final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        final file = File('build/status-surfaces/$screenshotName.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(png.buffer.asUint8List());
      }
      return colors;
    } finally {
      image.dispose();
    }
  }))!;
}
