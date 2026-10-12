import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/ocr_result.dart';

/// Thin wrapper around Google ML Kit Text Recognition v2.
class OcrService {
  final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  /// Run OCR on the image file at [imagePath].
  /// Returns an [OcrResult] with all detected text blocks and bounding boxes.
  Future<OcrResult> recognize(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognized = await _recognizer.processImage(inputImage);

    final blocks = <OcrTextBlock>[];
    final fullTextBuffer = StringBuffer();

    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final bb = line.boundingBox;
        blocks.add(OcrTextBlock(
          text: line.text,
          left: bb.left,
          top: bb.top,
          width: bb.width,
          height: bb.height,
          confidence: line.confidence,
        ));
        fullTextBuffer.writeln(line.text);
      }
    }

    return OcrResult(
      fullText: fullTextBuffer.toString().trim(),
      blocks: blocks,
      blockCount: blocks.length,
    );
  }

  /// Release the underlying ML Kit resource.
  Future<void> close() async {
    await _recognizer.close();
  }
}
