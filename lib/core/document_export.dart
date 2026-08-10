import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

/// Turning something drawn on screen into a file somebody can keep.
///
/// Built around a single idea: the picture *is* the document. A bill is drawn
/// once, in Flutter, and both the PNG and the PDF are made from that same
/// painted output. The alternative — a Flutter layout for the screen and a
/// second, hand-written `pdf` layout for the file — means two bills that agree
/// only for as long as somebody remembers to change both, and the day they
/// disagree is the day a customer is holding one and the workshop the other.
///
/// The cost is that PDF text is not selectable. For a one-page bill that is
/// worth paying; for anything long enough to want Ctrl-F it would not be.
class DocumentExport {
  const DocumentExport._();

  /// Pixels per logical point when capturing. 3 is retina-sharp and, on a bill,
  /// still a file small enough to send over a Nepali mobile connection.
  static const _pixelRatio = 3.0;

  /// Longest side of the captured bitmap, in pixels.
  ///
  /// A GPU refuses textures past its maximum size and returns nothing rather
  /// than a smaller image, so a bill with forty lines has to be captured at a
  /// lower ratio instead of failing. 4096 is the floor across the Android
  /// devices this app targets.
  static const _maxPixels = 4096.0;

  /// Paints the widget behind [key] and returns it as a PNG.
  ///
  /// [key] must be on a [RepaintBoundary]. The whole of it is captured, not
  /// only the part on screen — the boundary owns its own layer, and the scroll
  /// view above it is what does the clipping.
  ///
  /// Returns null when the widget is not currently mounted, which is what
  /// happens if the screen is popped while a save is in flight.
  static Future<CapturedPage?> capture(GlobalKey key) async {
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;

    if (boundary == null) return null;

    final size = boundary.size;
    final longest = math.max(size.width, size.height) * _pixelRatio;
    final ratio = longest > _maxPixels
        ? _pixelRatio * (_maxPixels / longest)
        : _pixelRatio;

    final image = await boundary.toImage(pixelRatio: ratio);

    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);

      if (data == null) return null;

      return CapturedPage(
        bytes: data.buffer.asUint8List(),
        // Taken from the layout rather than from the bitmap, so nothing has to
        // decode the PNG again just to find out how tall it is.
        aspect: size.height / size.width,
      );
    } finally {
      // Not garbage collected: this is a GPU handle, and leaking one per save
      // is how repeatedly tapping the button runs a phone out of memory.
      image.dispose();
    }
  }

  /// Wraps a captured page in a one-page PDF.
  ///
  /// The page is A4 wide and as tall as the bill needs, rather than A4 tall
  /// with the bill shrunk to fit. A long bill squeezed onto one A4 page is
  /// unreadable, and readers and printers both cope with an unusual page height
  /// far better than a person copes with 5pt type.
  static Future<Uint8List> toPdf(CapturedPage page) async {
    const margin = 28.0;
    final contentWidth = PdfPageFormat.a4.width - margin * 2;

    final format = PdfPageFormat(
      PdfPageFormat.a4.width,
      math.max(
        PdfPageFormat.a4.height,
        contentWidth * page.aspect + margin * 2,
      ),
      marginAll: margin,
    );

    final document = pw.Document();

    document.addPage(
      pw.Page(
        pageFormat: format,
        build: (_) => pw.Image(
          pw.MemoryImage(page.bytes),
          fit: pw.BoxFit.fitWidth,
          alignment: pw.Alignment.topCenter,
        ),
      ),
    );

    return document.save();
  }

  /// Writes [bytes] to a temporary file and offers it to the system share
  /// sheet, which is also how a file is saved into Files or Photos.
  ///
  /// The temporary directory rather than a permanent one: the sheet copies
  /// whatever the customer picks into that app's own storage, so keeping our
  /// copy afterwards would only fill the phone with bills nobody asked us to
  /// keep. Reusing the same name overwrites the last one for the same reason.
  static Future<void> share(
    Uint8List bytes, {
    required String filename,
    required String mimeType,
    String? subject,
    Rect? origin,
  }) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$filename');

    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mimeType)],
        fileNameOverrides: [filename],
        subject: subject,
        // iPads anchor the sheet to whatever was tapped. Without this it throws
        // on iPad rather than guessing a corner.
        sharePositionOrigin: origin,
      ),
    );
  }
}

/// A widget painted to a PNG, with the shape it was painted at.
class CapturedPage {
  const CapturedPage({required this.bytes, required this.aspect});

  final Uint8List bytes;

  /// Height over width. Carried alongside the bytes so a PDF page can be sized
  /// without decoding the image a second time.
  final double aspect;
}
