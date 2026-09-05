import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:dreamlore_app/services/share_card.dart';

/// The share card is composed on the raw canvas, so it can be checked without
/// a widget tree: feed it a tiny painting and make sure a well-formed 4:5 PNG
/// comes back with the painting somewhere in it.
Future<Uint8List> _tinyJpeg() async {
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  c.drawRect(const ui.Rect.fromLTWH(0, 0, 64, 64),
      ui.Paint()..color = const ui.Color(0xFF6C5CE7));
  final img = await rec.endRecording().toImage(64, 64);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() {
  testWidgets('composes a 1080x1350 PNG around the painting', (tester) async {
    final png = await tester.runAsync(() async {
      return ShareCard.compose(
        imageBytes: await _tinyJpeg(),
        dream: 'I was in a house I half knew and water rose through the floor. '
            'Then something else happened that should not be on the card.',
      );
    });
    expect(png, isNotNull);
    // PNG signature.
    expect(png!.sublist(0, 8),
        [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

    final decoded = await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(png);
      return (await codec.getNextFrame()).image;
    });
    expect(decoded!.width, 1080);
    expect(decoded.height, 1350);

    // The painting's indigo should land in the square at the top: sample the
    // centre of where it is drawn.
    final bytes = await tester.runAsync(
        () => decoded.toByteData(format: ui.ImageByteFormat.rawRgba));
    final x = 540, y = 72 + 468; // centre of the 936px square at y=72
    final i = (y * 1080 + x) * 4;
    final r = bytes!.getUint8(i), g = bytes.getUint8(i + 1), b = bytes.getUint8(i + 2);
    expect(b, greaterThan(r)); // indigo: blue dominates red
    expect(b, greaterThan(g));
  });
}
