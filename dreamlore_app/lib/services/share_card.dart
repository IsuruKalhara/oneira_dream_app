import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/config.dart';
import '../core/palette.dart';

/// The picture is the shareable hook (docs/GROWTH-ASO-SEO-GEO.md, "the
/// picture is the shareable hook"), so sharing it is not a raw JPEG going out:
/// it is a card — the painting, a line of the dream under it in the app's
/// serif, and a small Dreamlore mark — sized 4:5 so it fills a feed post or a
/// story without cropping the painting.
///
/// Nothing here is uploaded anywhere. The card is written to the temp dir and
/// handed to the OS share sheet; the user chooses where it goes.
class ShareCard {
  const ShareCard._();

  static const _width = 1080.0;
  static const _height = 1350.0;
  static const _pad = 72.0;

  /// Composes the card and opens the share sheet. [dream] is the transcript;
  /// only its first sentence or so is printed, so the card teases rather
  /// than publishes the whole dream.
  static Future<void> share({
    required BuildContext context,
    required Uint8List imageBytes,
    required String dream,
  }) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : null; // iPad share popovers need an anchor; Android ignores it.

    final png = await compose(imageBytes: imageBytes, dream: dream);
    // The card has to exist on disk: share_plus hands Android the file's
    // path, so an XFile carrying only bytes and a path we never wrote
    // silently produced a share sheet with nothing in it.
    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, 'dreamlore-dream.png');
    await File(path).writeAsBytes(png, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(path, mimeType: 'image/png', name: 'dreamlore-dream.png'),
        ],
        text: 'My dream, painted by ${Config.appName}.\n$storeUrl',
        subject: 'A dream, painted',
        sharePositionOrigin: origin,
      ),
    );
  }

  /// Shares the app itself — the "tell a friend" route, and the one piece of
  /// marketing that costs nothing and carries a real recommendation. Text
  /// only: a link is what gets tapped in a chat, and an image would push the
  /// link into an attachment on several platforms.
  static Future<void> shareApp(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text:
            "I've been using ${Config.appName} to write my dreams down when I "
            'wake up. It reads them against real dream books and quotes the '
            'actual passages, and the journal is saved on your phone.\n\n'
            '$storeUrl',
        subject: '${Config.appName} — a dream journal that quotes real books',
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      ),
    );
  }

  static const storeUrl =
      'https://play.google.com/store/apps/details?id=com.bitfuzed.dreamlore';

  /// Draws the card and returns PNG bytes. Pure: no I/O, no share sheet, so
  /// it can be previewed or tested on its own.
  static Future<Uint8List> compose({
    required Uint8List imageBytes,
    required String dream,
  }) async {
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(_width, _height);

    // Ground: the app's night, with the brand bloom at the top.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(_width / 2, 0),
          _height * 0.9,
          [
            Color.alphaBlend(
              const Color(0xFF6C5CE7).withValues(alpha: 0.22),
              Palette.ink,
            ),
            Palette.ink,
            Palette.inkDeep,
          ],
          [0.0, 0.55, 1.0],
        ),
    );

    // The painting, square, with rounded corners and a soft indigo glow.
    const side = _width - _pad * 2;
    final rect = const Rect.fromLTWH(_pad, _pad, side, side);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(44));
    canvas.drawRRect(
      rrect.inflate(6),
      Paint()
        ..color = const Color(0xFF6C5CE7).withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40),
    );
    canvas.save();
    canvas.clipRRect(rrect);
    // Cover-fit the image into the square.
    final scale =
        side / (image.width < image.height ? image.width : image.height);
    final dw = image.width * scale;
    final dh = image.height * scale;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(_pad + (side - dw) / 2, _pad + (side - dh) / 2, dw, dh),
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();

    // The dream, a line or two, in the app's serif.
    final snippet = _snippet(dream);
    final textTop = _pad + side + 56;
    final quote = _paragraph(
      '“$snippet”',
      maxWidth: side,
      style: ui.TextStyle(
        color: Palette.parchment,
        fontSize: 40,
        height: 1.35,
        fontFamily: 'Georgia',
        fontFamilyFallback: const ['New York', 'Times New Roman', 'serif'],
        fontStyle: FontStyle.italic,
      ),
      maxLines: 3,
    );
    canvas.drawParagraph(quote, Offset(_pad, textTop));

    // The mark, bottom-left; the invitation, bottom-right.
    final markTop = _height - _pad - 40;
    final mark = _paragraph(
      Config.appName.toUpperCase(),
      maxWidth: side / 2,
      style: ui.TextStyle(
        color: Palette.parchment,
        fontSize: 26,
        letterSpacing: 6,
        fontWeight: FontWeight.w700,
      ),
    );
    canvas.drawParagraph(mark, Offset(_pad, markTop));
    final tag = _paragraph(
      'See your dream, painted',
      maxWidth: side / 2,
      style: ui.TextStyle(
        color: Palette.muted,
        fontSize: 24,
        letterSpacing: 0.5,
      ),
      align: TextAlign.right,
    );
    canvas.drawParagraph(tag, Offset(_pad + side / 2, markTop + 2));

    // A tiny moon beside the mark — the brand glyph, drawn not imported.
    final moonCenter = Offset(_pad + mark.longestLine + 26, markTop + 16);
    canvas.drawCircle(moonCenter, 9, Paint()..color = Palette.parchment);
    canvas.drawCircle(
      moonCenter.translate(5, -2),
      8,
      Paint()..color = Palette.ink,
    );

    final picture = recorder.endRecording();
    final out = await picture.toImage(_width.toInt(), _height.toInt());
    final bytes = await out.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    out.dispose();
    return bytes!.buffer.asUint8List();
  }

  /// First sentence, capped, so the card reads as a caption not a wall.
  static String _snippet(String dream) {
    final t = dream.trim().replaceAll(RegExp(r'\s+'), ' ');
    final end = t.indexOf(RegExp(r'[.!?](\s|$)'));
    var s = end > 20 ? t.substring(0, end + 1) : t;
    if (s.length > 140) s = '${s.substring(0, 137).trimRight()}…';
    return s;
  }

  static ui.Paragraph _paragraph(
    String text, {
    required double maxWidth,
    required ui.TextStyle style,
    int? maxLines,
    TextAlign align = TextAlign.left,
  }) {
    final b =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: align,
              maxLines: maxLines,
              ellipsis: maxLines != null ? '…' : null,
            ),
          )
          ..pushStyle(style)
          ..addText(text);
    return b.build()..layout(ui.ParagraphConstraints(width: maxWidth));
  }
}
