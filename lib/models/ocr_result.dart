import 'dart:convert';

/// A single text block extracted by ML Kit OCR.
class OcrTextBlock {
  final String text;
  final double left;
  final double top;
  final double width;
  final double height;
  final double? confidence;

  const OcrTextBlock({
    required this.text,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.confidence,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'left': left,
        'top': top,
        'width': width,
        'height': height,
        if (confidence != null) 'confidence': confidence,
      };

  factory OcrTextBlock.fromJson(Map<String, dynamic> json) => OcrTextBlock(
        text: json['text'] as String,
        left: (json['left'] as num).toDouble(),
        top: (json['top'] as num).toDouble(),
        width: (json['width'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
        confidence: json['confidence'] != null
            ? (json['confidence'] as num).toDouble()
            : null,
      );
}

/// The aggregated OCR result for one screenshot.
class OcrResult {
  final String fullText;
  final List<OcrTextBlock> blocks;
  final int blockCount;

  const OcrResult({
    required this.fullText,
    required this.blocks,
    required this.blockCount,
  });

  /// Returns a plain summary for feeding to the AI service.
  String get aiSummary {
    final preview = fullText.length > 600
        ? '${fullText.substring(0, 600)}…'
        : fullText;
    return 'OCR detected $blockCount text block(s).\nText preview:\n$preview';
  }

  Map<String, dynamic> toJson() => {
        'fullText': fullText,
        'blocks': blocks.map((b) => b.toJson()).toList(),
        'blockCount': blockCount,
      };

  factory OcrResult.fromJson(Map<String, dynamic> json) => OcrResult(
        fullText: json['fullText'] as String,
        blocks: (json['blocks'] as List<dynamic>)
            .map((b) => OcrTextBlock.fromJson(b as Map<String, dynamic>))
            .toList(),
        blockCount: json['blockCount'] as int,
      );

  String toJsonString() => jsonEncode(toJson());
  factory OcrResult.fromJsonString(String s) =>
      OcrResult.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
