import 'dart:convert';

import 'ocr_result.dart';
import 'visual_metrics.dart';

/// Analysis result for a single screenshot within a session.
/// A session can contain 1–5 of these (one per screenshot).
class ScreenshotAnalysis {
  /// Absolute path to the image file.
  final String imagePath;

  /// 1-based index label, e.g. "Layar 1".
  final int index;

  /// Optional human-supplied label for this screen, e.g. "Halaman Login".
  String label;

  /// Computed OpenCV-equivalent visual metrics.
  VisualMetrics? visualMetrics;

  /// ML Kit OCR result.
  OcrResult? ocrResult;

  ScreenshotAnalysis({
    required this.imagePath,
    required this.index,
    String? label,
    this.visualMetrics,
    this.ocrResult,
  }) : label = label ?? 'Screen $index';

  bool get isAnalyzed => visualMetrics != null && ocrResult != null;

  Map<String, dynamic> toJson() => {
        'imagePath': imagePath,
        'index': index,
        'label': label,
        if (visualMetrics != null) 'visualMetrics': visualMetrics!.toJson(),
        if (ocrResult != null) 'ocrResult': ocrResult!.toJson(),
      };

  factory ScreenshotAnalysis.fromJson(Map<String, dynamic> json) =>
      ScreenshotAnalysis(
        imagePath: json['imagePath'] as String,
        index: json['index'] as int,
        label: json['label'] as String? ?? 'Screen ${json['index']}',
        visualMetrics: json['visualMetrics'] != null
            ? VisualMetrics.fromJson(
                json['visualMetrics'] as Map<String, dynamic>)
            : null,
        ocrResult: json['ocrResult'] != null
            ? OcrResult.fromJson(json['ocrResult'] as Map<String, dynamic>)
            : null,
      );

  String toJsonString() => jsonEncode(toJson());
}
